# otel-shop

이 디렉터리는 Argo CD를 통해 배포되는 `otel-shop` 워크로드용 Kubernetes 매니페스트를 관리합니다.

## 디렉터리 구조

```text
apps/otel-shop/
  web-tier-hpa/         프런트엔드 계층 HPA 리소스
  frontend-ingress.yaml 상점 외부 공개용 ALB Ingress
  kustomization.yaml    Kustomize 빌드 설정
```

## 접속 주소

| 도메인 | 설명 |
|--------|------|
| `https://shop.cyou.monster` | Cloudflare + ALB를 통해 공개되는 상점 주소 |

## Ingress 메모

- `shared-public` ALB 그룹을 사용해 다른 퍼블릭 서비스와 ALB를 공유합니다.
- ALB `instance` 모드와 연동하기 위해 `frontend-proxy` 서비스는 `type: NodePort`를 사용해야 합니다.
- ExternalDNS가 `shop.cyou.monster` 레코드를 Cloudflare에 자동으로 생성/갱신합니다.

## HPA

`web-tier-hpa/` 디렉터리에는 `frontend`, `frontend-proxy` 대상 HPA 리소스가 있습니다.
트래픽이 증가하면 CPU 사용률을 기준으로 파드를 자동 확장합니다.

## 참고

- `load-generator`는 Argo CD Application에서 반드시 `enabled: true` 상태를 유지해야 합니다.
  비활성화하면 SLA, Revenue, Cost 패널이 `NaN` 또는 `$0`으로 보일 수 있습니다.
- 모든 `otel-shop` 파드는 워커 노드에만 배치됩니다. 즉, 노드에 `dedicated` 라벨이 없어야 합니다.
