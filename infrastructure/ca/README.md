# Cluster Autoscaler

이 클러스터는 EKS가 아닌 EC2 기반 K3s 환경입니다.
따라서 Cluster Autoscaler는 EKS IRSA 대신 노드의 IAM Role과 IMDS를 사용합니다.

Autoscaler는 전용 노드에 배치되며, discovery 태그가 붙은 ASG만 관리합니다.

## Helm 설치 예시

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  -f infrastructure/ca/ca_values.yaml
```

## 확인 방법

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler
```

예상 상태:

- 파드가 `Running`
- 전용 노드에 배치됨
- `k8s.io/cluster-autoscaler/enabled=true` 태그가 붙은 워커 ASG를 탐지함

## 참고

- 스케일다운은 단순 CPU 여유분이 아니라, 노드가 실제로 비워질 수 있는지 여부를 기준으로 판단합니다.
- `min_size`가 1인 노드 그룹은 Autoscaler가 0까지 줄일 수 없습니다.
- worker Spot ASG는 `min_size=0`으로 설정돼 있어 트래픽이 없을 때 0까지 축소할 수 있습니다.
