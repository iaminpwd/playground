# ExternalDNS

ExternalDNS는 Kubernetes Ingress 리소스를 기준으로 Cloudflare DNS 레코드를 자동으로 관리합니다.

## 이 구성이 하는 일

- Argo CD를 통해 ExternalDNS Helm 차트를 배포합니다.
- Ingress 리소스를 감시합니다.
- `cyou.monster` 도메인만 관리합니다.
- 어노테이션이 지정된 Ingress에 대해 Cloudflare proxied 레코드를 생성합니다.

## 필요한 Secret

- 네임스페이스: `kube-system`
- 이름: `external-dns-cloudflare`
- 키: `apiToken`

## GitOps 흐름

1. Argo CD가 `sealed-secrets` 컨트롤러를 배포합니다.
2. Argo CD가 `external-dns-secret` 애플리케이션을 동기화합니다.
3. Sealed Secrets 컨트롤러가 런타임 Secret `external-dns-cloudflare`를 생성합니다.
4. ExternalDNS가 이 Secret을 `CF_API_TOKEN`으로 사용해 Cloudflare API를 호출합니다.

## 암호화된 토큰 갱신 위치

- `infrastructure/external-dns-secret/README.md`를 참고하세요.
- `external-dns-cloudflare-sealedsecret.yaml`을 `kubeseal` 출력으로 교체하면 됩니다.

## 권장 Cloudflare 토큰 권한

- `Zone:DNS:Edit`
- `Zone:Zone:Read`

## 예상 동작

1. Argo CD가 `sealed-secrets`, `external-dns-secret`, `external-dns`를 순서대로 동기화합니다.
2. ExternalDNS가 Ingress의 host와 어노테이션을 읽습니다.
3. Cloudflare DNS 레코드가 자동 생성 또는 갱신됩니다.
