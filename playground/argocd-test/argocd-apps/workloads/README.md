# Argo CD 워크로드 애플리케이션

이 디렉터리는 비즈니스 워크로드를 배포하는 Argo CD Application 매니페스트를 관리합니다.
현재 대표 워크로드는 OpenTelemetry Demo 기반의 `otel-shop`입니다.

## 포함된 구성

- `otel-shop` 마이크로서비스 애플리케이션
- 웹 계층 HPA

## `otel-shop` 개요

`otel-shop`은 트래픽, 매출 추정, 비용 지표를 함께 시각화하기 위한 데모 이커머스 애플리케이션입니다.

```text
otel-shop (namespace)
  frontend-proxy   ALB Ingress 진입점(NodePort)
  frontend
  cart
  checkout
  payment
  shipping
  currency
  recommendation
  ad
  product-catalog
  kafka
  postgresql
  load-generator   지표 유지를 위해 항상 활성화
  otel-collector   trace -> metric 변환
```

## 주요 설정 메모

- 내장 모니터링 스택(Prometheus, Grafana, Jaeger, OpenSearch)은 비활성화하고, 클러스터의 기존 스택을 사용합니다.
- 모든 파드는 워커 노드에만 배치됩니다.
- `load-generator`는 반드시 활성화 상태를 유지해야 합니다.
- `frontend-proxy`는 ALB `instance` 모드를 위해 `NodePort`를 사용합니다.

## OTEL Collector 파이프라인

모든 서비스의 trace는 OTEL Collector로 전달되며, Collector는 다음 작업을 수행합니다.

1. `spanmetrics` 커넥터로 trace를 metric으로 변환
2. OTLP endpoint를 통해 Prometheus로 metric 전송

```text
http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090/api/v1/otlp
```

참고로 exporter가 `/v1/metrics`를 자동으로 덧붙이므로 endpoint에 직접 추가하면 안 됩니다.
