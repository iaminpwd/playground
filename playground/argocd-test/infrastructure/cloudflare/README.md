# Cloudflare Tunnel

이 디렉터리는 Argo CD를 통해 Cloudflare Tunnel 런타임 Deployment를 배포합니다.

## 포함된 구성

- `cloudflare-tunnel.yaml`
  - `monitoring` 네임스페이스에 `cloudflared-final` Deployment를 배포합니다.
  - 런타임 Secret `cloudflare-token`을 읽어 Tunnel을 실행합니다.

## Secret 주입 방식

이 디렉터리 자체는 토큰 Secret을 만들지 않습니다.
런타임 Secret은 GitHub Actions 같은 외부 자동화가 생성하거나 갱신하는 것을 전제로 합니다.

## 참고

- Secret 이름은 반드시 `monitoring/cloudflare-token`을 유지해야 합니다.
- `cloudflared-final` Deployment는 `TUNNEL_TOKEN` 키를 사용합니다.
- 관련 자동화는 `finops-infra-provisioning/.github/workflows/cloudflare-secrets.yaml`에서 관리합니다.
