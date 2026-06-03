# Argo CD 인프라 애플리케이션

이 디렉터리는 NEO-FINOPS 클러스터의 핵심 인프라 구성 요소를 배포하는 Argo CD Application 매니페스트를 관리합니다.

## 디렉터리 역할

이 경로에는 다음과 같은 플랫폼 애플리케이션이 포함됩니다.

- 스토리지 드라이버
- Sealed Secrets
- AWS Load Balancer Controller
- Cluster Autoscaler
- AWS Node Termination Handler
- ExternalDNS
- Cloudflare Tunnel
- Prometheus / Grafana / Kubecost
- IngressClass 및 공용 Ingress 관련 리소스

## Sync Wave 순서

`argocd.argoproj.io/sync-wave`를 사용해 의존성이 있는 애플리케이션을 순차 배포합니다.

| Wave | 애플리케이션 | 이유 |
|------|--------------|------|
| -1 | `aws-ebs-csi-driver` | PVC 생성 전에 StorageClass가 필요함 |
| 0 | `sealed-secrets` | SealedSecret 복호화 컨트롤러가 먼저 필요함 |
| 1 | `cloudflare-tunnel` | Tunnel 토큰 Secret 선행 필요 |
| 1 | `external-dns-secret` | Cloudflare API 토큰 Secret 생성 |
| 2 | `external-dns` | 런타임 Secret 필요 |
| 2 | `kubecost` | monitoring 네임스페이스와 PVC 필요 |
| - | 그 외 애플리케이션 | 별도 순서 의존성 없음 |

## 멀티 소스 패턴

여러 Helm 기반 애플리케이션은 다음과 같은 multi-source 패턴을 사용합니다.

```yaml
sources:
  - repoURL: https://some-helm-chart-repo
    chart: chart-name
    targetRevision: "x.x.x"
    helm:
      valueFiles:
        - $values/infrastructure/some-component/values.yaml
  - repoURL: https://github.com/iaminpwd/argocd-test-repo.git
    targetRevision: main
    ref: values
```

이 방식은 업스트림 Helm 차트와 우리 팀의 커스텀 설정을 분리해 유지보수를 쉽게 만듭니다.

## 참고

- Argo CD 재시작 이후 `platform-root`의 `targetRevision`이 의도와 다르게 바뀌는지 확인해야 할 때가 있습니다.
- 외부 Secret이나 클라우드 자격 증명에 의존하는 애플리케이션은 Git 상태뿐 아니라 런타임 Secret 존재 여부도 함께 확인해야 합니다.
