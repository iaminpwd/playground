# 1. ArgoCD를 설치할 네임스페이스 생성
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# 2. Helm을 이용한 ArgoCD 설치
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.46.7" # 특정 버전을 명시하는 것이 안정적입니다.
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # 필요한 경우 커스텀 설정 주입 (예: 서버를 비보안 모드로 실행 등)
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
}

# 3. 루트 앱(App of Apps) 자동 등록
# ArgoCD 설치 직후, 질문자님의 'platform-root'를 바로 꽂아버립니다.
resource "kubernetes_manifest" "platform_root" {
  depends_on = [helm_release.argocd]

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "platform-root"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = "main"
        path           = "argocd-apps"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }
}