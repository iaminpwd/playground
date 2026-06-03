#!/bin/bash
# ==============================================================================
# GitOps & AWS 인프라(ALB/NLB) 안전 철거 스크립트 (Terraform Destroy 전처리용)
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. 환경 변수 및 기본 설정
# ------------------------------------------------------------------------------
CLEANUP_MODE="${CLEANUP_MODE:-prepare}"
KUBECTL_TIMEOUT="${KUBECTL_TIMEOUT:-20s}"
MAX_ATTEMPTS="${APP_DELETE_ATTEMPTS:-120}"
SLEEP_SEC="${APP_DELETE_SLEEP_SECONDS:-5}"

# ------------------------------------------------------------------------------
# 2. 공통 유틸리티 함수
# ------------------------------------------------------------------------------
log() {
  echo -e "\n[GitOps Cleanup] $1"
}

kubectl_safe() {
  kubectl --request-timeout="${KUBECTL_TIMEOUT}" "$@"
}

wait_for_k3s() {
  local attempts=0
  log "K3s(Kubernetes) API 서버 응답 대기 중..."
  until kubectl_safe get nodes >/dev/null 2>&1; do
    ((attempts++))
    if [[ "$attempts" -ge 30 ]]; then
      log "❌ K3s API 서버가 응답하지 않습니다. (타임아웃)"
      return 1
    fi
    sleep 5
  done
  return 0
}

# ------------------------------------------------------------------------------
# 3. K8s 데드락(Deadlock) 방지 함수 (죽은 노드 및 파드 정리)
# ------------------------------------------------------------------------------
cleanup_dead_nodes_and_pods() {
  local notready_nodes
  notready_nodes=$(kubectl_safe get nodes --no-headers 2>/dev/null | awk '$2 ~ /NotReady/ {print $1}' || true)
  
  [[ -z "$notready_nodes" ]] && return 0

  log "응답 없는(NotReady) 노드 및 강제 종료(Terminating) 파드 정리 중..."
  while IFS=$'\t' read -r ns pod node; do
    if grep -Fxq "$node" <<< "$notready_nodes"; then
      kubectl_safe delete pod "$pod" -n "$ns" --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true
    fi
  done < <(kubectl_safe get pods -A -o jsonpath='{range .items[?(@.metadata.deletionTimestamp!="")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}' 2>/dev/null || true)

  for node in $notready_nodes; do
    kubectl_safe delete node "$node" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  done
}

# ------------------------------------------------------------------------------
# 4. ArgoCD 제어 함수 (Auto-sync 차단 및 파이널라이저 주입)
# ------------------------------------------------------------------------------
get_argocd_apps() {
  kubectl_safe get application -n argocd -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null || true
}

disable_argocd_autosync() {
  log "ArgoCD 자동 동기화(Auto-sync) 비활성화 (좀비 리소스 생성 방지)..."
  for app in $(get_argocd_apps); do
    kubectl_safe patch application "$app" -n argocd --type json -p='[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null 2>&1 || true
    # 삭제 시 하위 리소스도 깔끔하게 지워지도록 파이널라이저 강제 주입
    kubectl_safe patch application "$app" -n argocd --type merge -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}' >/dev/null 2>&1 || true
  done
}

force_remove_argocd_finalizers() {
  log "⚠️ 삭제 불가능한 ArgoCD 앱의 파이널라이저 강제 제거 중..."
  for app in $(get_argocd_apps); do
    kubectl_safe patch application "$app" -n argocd --type merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done
}

# ------------------------------------------------------------------------------
# 5. AWS 외부 노출 리소스(ALB/NLB) 철거 함수
# ------------------------------------------------------------------------------
delete_aws_facing_resources() {
  log "AWS Load Balancer 삭제를 유도하기 위해 Ingress 및 LB Service 삭제 중..."
  
  # 1. 인프라보다 먼저 Ingress App 지우기
  kubectl_safe delete application ingress -n argocd --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  
  # 2. 모든 Ingress 리소스 일괄 삭제 (ALB 철거 유도)
  kubectl_safe delete ingress --all -A --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  
  # 3. LoadBalancer 타입 Service 일괄 삭제 (NLB/ELB 철거 유도)
  for svc in $(kubectl_safe get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
    kubectl_safe delete service "${svc##*/}" -n "${svc%%/*}" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
  done
}

wait_for_aws_lb_cleanup() {
  log "AWS Load Balancer Controller가 AWS 리소스를 완전히 삭제할 때까지 대기합니다..."
  
  for (( i=1; i<=MAX_ATTEMPTS; i++ )); do
    local ingresses services targetgroups=""
    ingresses=$(kubectl_safe get ingress -A --no-headers 2>/dev/null || true)
    services=$(kubectl_safe get svc -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    
    # TargetGroupBinding CRD가 존재하는지 확인 후 조회
    if kubectl_safe api-resources --api-group=elbv2.k8s.aws -o name 2>/dev/null | grep -Fxq "targetgroupbindings"; then
      targetgroups=$(kubectl_safe get targetgroupbinding -A --no-headers 2>/dev/null || true)
    fi

    if [[ -z "$ingresses" && -z "$services" && -z "$targetgroups" ]]; then
      log "✅ 모든 K8s Load Balancer 연관 리소스 철거 완료!"
      return 0
    fi

    cleanup_dead_nodes_and_pods
    sleep "$SLEEP_SEC"
  done

  log "❌ AWS Load Balancer 철거 대기 타임아웃 발생"
  return 1
}

# ------------------------------------------------------------------------------
# 6. 최종 삭제 흐름 제어 (Main Logic)
# ------------------------------------------------------------------------------

# [Prepare 모드] Terraform 인프라 파괴 '전'에 외부 자원(AWS ALB 등)을 미리 철거
do_prepare() {
  if ! wait_for_k3s || ! kubectl_safe get namespace argocd >/dev/null 2>&1; then
    log "클러스터나 ArgoCD가 존재하지 않습니다. Prepare 단계를 건너뜁니다."
    return 0
  fi

  disable_argocd_autosync
  delete_aws_facing_resources
  wait_for_aws_lb_cleanup
}

# [Finalize 모드] Terraform 인프라 파괴 전/후, 남은 ArgoCD 껍데기 리소스 최종 삭제
do_finalize() {
  if ! wait_for_k3s || ! kubectl_safe get namespace argocd >/dev/null 2>&1; then
    return 0
  fi

  log "남은 모든 ArgoCD Application을 삭제합니다..."
  kubectl_safe delete application --all -n argocd --ignore-not-found=true --wait=false >/dev/null 2>&1 || true

  for (( i=1; i<=MAX_ATTEMPTS; i++ )); do
    local remaining
    remaining=$(get_argocd_apps)
    
    if [[ -z "$remaining" ]]; then
      log "✅ 모든 ArgoCD Application 삭제 완료!"
      return 0
    fi

    cleanup_dead_nodes_and_pods
    kubectl_safe delete application --all -n argocd --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
    sleep "$SLEEP_SEC"
  done

  log "⚠️ 정상 삭제 실패. 파이널라이저를 강제로 제거하고 날려버립니다."
  force_remove_argocd_finalizers
  kubectl_safe delete application --all -n argocd --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# 실행 분기
# ------------------------------------------------------------------------------
case "$CLEANUP_MODE" in
  prepare)
    log "=== [CLEANUP: PREPARE] AWS 종속 리소스 철거 시작 ==="
    do_prepare
    ;;
  finalize)
    log "=== [CLEANUP: FINALIZE] K8s 내부 찌꺼기 최종 철거 시작 ==="
    do_finalize
    ;;
  *)
    log "❌ 지원하지 않는 CLEANUP_MODE 입니다: $CLEANUP_MODE"
    exit 1
    ;;
esac