# AWS Node Termination Handler

이 클러스터는 EKS가 아닌 EC2 기반 K3s 환경입니다.
따라서 Node Termination Handler는 EKS IRSA 대신 노드 IAM Role과 IMDS를 사용합니다.

`nth_values.yaml`의 queue-processor 모드는 Terraform이 다음 리소스를 만든다는 전제를 가집니다.

- 중단 이벤트 수신용 SQS 큐
- Spot interruption / rebalance 이벤트용 EventBridge 규칙
- 워커 종료 감지를 위한 Auto Scaling lifecycle hook

Terraform은 큐 URL을 SSM Parameter Store의 `/${project_name}/spot-interruption-queue-url`에 저장합니다.

## 권장 운영 방식

NTH Argo CD Application은 Git에 유지하고, Terraform 적용 후 현재 큐 URL만 런타임 values 파일에 반영하는 방식을 권장합니다.

이 저장소에는 정적 Application 매니페스트가 포함되어 있습니다.
Terraform apply 이후 bootstrap 워크플로우가 SSM에서 큐 URL을 읽어 `infrastructure/nth/nth_runtime_values.yaml`에 기록하면, Argo CD가 Git 기준 상태로 NTH를 계속 동기화합니다.

`nth_values.yaml`에는 `useProviderId: true`가 설정되어 있습니다.
이 클러스터의 K3s 워커는 `my-k3s-worker-spot-31` 같은 커스텀 노드 이름으로 등록되지만, AWS lifecycle 이벤트는 EC2 private DNS 이름을 사용하기 때문입니다.
`spec.providerID`를 기준으로 노드를 찾으면 drain 시 이름 불일치를 피할 수 있습니다.

## 자동 설치

```bash
chmod +x infrastructure/nth/install.sh
./infrastructure/nth/install.sh
```

기본값:

- `PROJECT_NAME=my-k3s`
- `AWS_REGION=ap-northeast-2`
- `QUEUE_PARAM_NAME=/${PROJECT_NAME}/spot-interruption-queue-url`

## Helm 설치 예시

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

QUEUE_URL="$(aws ssm get-parameter \
  --name "/my-k3s/spot-interruption-queue-url" \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text)"

helm upgrade --install aws-node-termination-handler eks/aws-node-termination-handler \
  --namespace kube-system \
  -f infrastructure/nth/nth_values.yaml \
  --set-string queueURL="$QUEUE_URL"
```

## 확인 방법

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-node-termination-handler
kubectl logs -n kube-system deploy/aws-node-termination-handler
```

예상 상태:

- 파드가 `Running`
- 전용 노드에 배치됨
- IRSA 없이도 설정된 SQS 큐에 정상 연결됨
