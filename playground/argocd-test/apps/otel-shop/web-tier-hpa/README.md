# web-tier-hpa

이 디렉터리는 `otel-shop` 웹 계층의 Horizontal Pod Autoscaler 리소스를 관리합니다.

## 배포 대상

| 리소스 | 대상 Deployment | 최소 | 최대 | 기준 |
|--------|------------------|------|------|------|
| `frontend-hpa` | `frontend` | 2 | 10 | CPU 60% |
| `frontend-proxy-hpa` | `frontend-proxy` | 2 | 10 | CPU 60% |

## 동작 방식

대상 Deployment의 CPU 사용률이 60%를 넘으면 HPA가 파드를 자동으로 확장합니다.
부하가 줄어들면 다시 최소 replica 수까지 축소합니다.

## 요구 사항

- HPA가 정상 계산하려면 대상 컨테이너에 `requests.cpu`가 설정되어 있어야 합니다.
- 클러스터에 Metrics Server가 실행 중이어야 합니다.

## 참고

- Spot 인스턴스 회수 상황에서도 가용성을 유지하기 위해 최소 replica 수를 2로 설정했습니다.
- HPA가 조정하는 replica 수는 Argo CD Application의 `ignoreDifferences`로 diff 대상에서 제외됩니다.
