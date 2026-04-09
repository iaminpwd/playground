# external-dns-secret

이 경로는 `external-dns-secret` Argo CD 애플리케이션을 위한 자리표시자 역할을 합니다.

## 현재 구조

- 런타임 Secret `external-dns-cloudflare`는 `kube-system` 네임스페이스에 생성되어야 합니다.
- 현재 권장 생성 경로는 GitHub Actions 기반 외부 자동화입니다.

## 참고

- 권장 Cloudflare 토큰 권한:
  - `Zone:DNS:Edit`
  - `Zone:Zone:Read`
- 관련 자동화 워크플로우는 `finops-infra-provisioning/.github/workflows/cloudflare-secrets.yaml`입니다.
