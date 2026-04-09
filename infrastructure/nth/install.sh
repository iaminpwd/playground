#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-my-k3s}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
QUEUE_PARAM_NAME="${QUEUE_PARAM_NAME:-/${PROJECT_NAME}/spot-interruption-queue-url}"
VALUES_FILE="${VALUES_FILE:-infrastructure/nth/nth_values.yaml}"

QUEUE_URL="$(
  aws ssm get-parameter \
    --name "$QUEUE_PARAM_NAME" \
    --region "$AWS_REGION" \
    --query 'Parameter.Value' \
    --output text
)"

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update

kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install aws-node-termination-handler eks/aws-node-termination-handler \
  --namespace kube-system \
  -f "$VALUES_FILE" \
  --set-string queueURL="$QUEUE_URL"
