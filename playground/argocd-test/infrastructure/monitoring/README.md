# Monitoring

이 디렉터리는 NEO-FINOPS 클러스터의 모니터링 스택을 관리합니다.
Prometheus, Grafana, Kubecost를 조합해 운영 상태와 인프라 비용을 함께 시각화합니다.

## 구성 요소

| 구성 요소 | 역할 |
|-----------|------|
| Prometheus | 클러스터 메트릭 수집 및 Recording Rule 계산 |
| Grafana | FINOPS / OPS 대시보드 시각화 |
| Kubecost | AWS 비용 분석 및 Spot 절감 효과 계산 |

## 디렉터리 구조

```text
monitoring/
  kubecost/
    values.yaml
  prometheus/
    dashboards/
      dashboard-finops.json
      dashboard-ops.json
    grafana-alerts.yaml
    kustomization.yaml
    neo-finops-dashboard-configmap.yaml
    prometheus-recording-rules.yaml
    values.yaml
```

## Recording Rule 예시

Prometheus는 대시보드 쿼리 성능 향상을 위해 다음 지표를 1분 단위로 미리 계산합니다.

| 메트릭 | 설명 |
|--------|------|
| `sla_attainment_ratio` | 전체 요청 대비 2xx 성공 비율 |
| `business_revenue_per_hour` | 시간당 추정 매출 |
| `infra_cost_per_hour` | 시간당 인프라 비용 |
| `cost_per_transaction` | 주문당 인프라 비용 |
| `spot_adoption_rate` | 전체 노드 중 Spot 비율 |
| `anomaly_score` | CPU Request 대비 실제 사용률 기반 이상치 점수 |

## 대시보드

### FINOPS 대시보드

- 실시간 매출
- 총 인프라 비용
- 트랜잭션당 비용
- Spot 도입률
- 노드 타입 분포
- 매출과 비용 상관 관계
- 마이크로서비스별 비용 비중
- Spot 절감 효과

### OPS 대시보드

- SLA 달성률
- 클러스터 이상치 점수
- 스케일 예상 시점
- 노드 CPU / 메모리 사용률
- 트래픽 추이
- OOMKilled 파드
- 네트워크 I/O
- 서비스 가용성 그리드

## Grafana 접속

Grafana는 Cloudflare Tunnel을 통해 외부에서 접근할 수 있습니다.

```text
URL: https://grafana.cyou.monster
ID:  admin
PW:  Finops!Admin@2026
```

포트 포워딩으로 접근하려면:

```bash
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
```

## 알림

Grafana Alerting을 통해 Discord로 알림을 전송합니다.

| 알림 | 조건 | 심각도 |
|------|------|--------|
| `ClusterAutoscalerScaledUp` | 노드 스케일아웃 발생 | info |
| `ClusterAutoscalerScaledDown` | 노드 스케일다운 발생 | info |
| `SpotInstanceInterruptionDetected` | Spot 중단 이벤트 감지 | warning |

## 참고

- Prometheus는 `dedicated=monitoring` On-Demand 노드에 배치합니다.
- Grafana는 `dedicated=monitoring` Spot 노드에 배치할 수 있습니다.
- 루트 앱의 `targetRevision`이 의도와 다르게 바뀌지 않았는지 점검하는 것이 좋습니다.
