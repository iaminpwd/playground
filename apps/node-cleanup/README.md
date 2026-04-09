# node-cleanup

이 디렉터리는 `NotReady` 상태로 오래 남아 있는 Spot 워커 노드를 자동으로 정리하는 CronJob을 관리합니다.

## 문제

AWS가 Spot 인스턴스를 회수하면 노드가 `NotReady` 상태가 된 뒤 Kubernetes에 계속 남아 있을 수 있습니다.
이런 노드가 많이 쌓이면 Cluster Autoscaler가 다음과 같은 상태로 멈출 수 있습니다.

```text
Cluster is not ready for autoscaling
```

그 결과 새 파드가 `Pending` 상태에 오래 머무를 수 있습니다.

## 해결 방식

CronJob이 5분마다 실행되며, `worker-spot` 노드 중 `NotReady` 상태가 10분 이상 지속된 노드를 찾아 클러스터에서 제거합니다.

## 동작 개요

```text
5분마다 실행
  -> NotReady 상태의 worker-spot 노드 조회
  -> 각 노드가 NotReady 상태였던 시간 계산
  -> 10분 미만이면 유지
  -> 10분 이상이면 노드 삭제
```

## 리소스 구성

| 파일 | 종류 | 설명 |
|------|------|------|
| `namespace.yaml` | Namespace | node-cleanup 전용 네임스페이스 |
| `serviceaccount.yaml` | ServiceAccount | CronJob 실행 주체 |
| `clusterrole.yaml` | ClusterRole | 노드 조회/삭제 권한 |
| `clusterrolebinding.yaml` | ClusterRoleBinding | 권한 바인딩 |
| `cronjob.yaml` | CronJob | 주기적으로 stale 노드를 정리 |

## 참고

- `worker-spot` 노드만 대상으로 하며, On-Demand 노드와 monitoring 노드는 삭제하지 않습니다.
- 10분 유예 시간을 둬서 일시적인 `NotReady` 상태는 복구 기회를 줍니다.
- 오래된 노드가 정리되면 Cluster Autoscaler는 다시 정상 동작합니다.
