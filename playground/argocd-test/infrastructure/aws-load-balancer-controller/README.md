# AWS Load Balancer Controller

이 프로젝트는 정적인 Terraform 관리형 ALB + `ingress-nginx` NodePort 조합 대신 AWS Load Balancer Controller를 사용합니다.

컨트롤러는 전용 노드에 배치되며, 노드 IAM Role을 통해 AWS API를 호출합니다.

## Helm 설치 예시

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  -f infrastructure/aws-load-balancer-controller/values.yaml
```

## 확인 방법

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller
kubectl get ingressclass
```

예상 상태:

- 컨트롤러 파드가 `Running`
- 전용 노드에 정상 스케줄링
- `IngressClass alb` 존재

## 참고

- 이 K3s on EC2 환경에서는 ALB target type을 `instance`로 유지해야 합니다.
- ALB 뒤에 놓이는 백엔드 서비스는 일반적으로 `type: NodePort`를 사용해야 합니다.
- 컨트롤러가 서브넷을 자동 탐지할 수 있도록 Terraform에서 퍼블릭/프라이빗 서브넷 태그를 설정합니다.
- 비용 절감을 위해 `alb.ingress.kubernetes.io/group.name`을 사용해 공유 ALB를 재사용하는 것을 권장합니다.
  - 퍼블릭 서비스: `shared-public`
  - 내부 운영 도구: `shared-internal`
