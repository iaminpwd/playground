# ALB 기반 Ingress

AWS Load Balancer Controller를 통한 HTTP 라우팅에는 `ingressClassName: alb`를 사용합니다.

이 프로젝트는 서비스마다 ALB를 하나씩 만드는 대신, IngressGroup을 이용해 소수의 ALB를 공유하도록 설계합니다.

## 권장 공유 그룹

- 외부 사용자 대상 서비스: `shared-public`
- 내부 대시보드 및 운영 도구: `shared-internal`

## IngressClass 적용

```bash
kubectl apply -f infrastructure/ingress-controllers/alb_ingressclass.yaml
```

## 공유 퍼블릭 ALB 예시

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-app
  annotations:
    alb.ingress.kubernetes.io/group.name: shared-public
    alb.ingress.kubernetes.io/group.order: "10"
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sample-app
                port:
                  number: 80
```

## 공유 내부 ALB 예시

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-tool
  annotations:
    alb.ingress.kubernetes.io/group.name: shared-internal
    alb.ingress.kubernetes.io/group.order: "10"
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: instance
spec:
  ingressClassName: alb
  rules:
    - host: grafana.internal.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 80
```

## 중요 사항

- 이 K3s on EC2 환경에서는 ALB `instance` 모드가 노드 포트를 대상으로 삼습니다.
- 따라서 ALB 뒤에 위치한 애플리케이션 서비스는 일반적으로 `type: NodePort`여야 합니다.
- 여러 Ingress가 하나의 ALB를 공유하려면 다음 값이 호환되어야 합니다.
  - 같은 `alb.ingress.kubernetes.io/group.name`
  - 같은 ALB 스킴 의도(`internet-facing` 또는 `internal`)
  - 충돌하지 않는 리스너 / TLS 설정
