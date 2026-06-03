# FILE: ./modules/k3s-cluster/main.tf

data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = var.master_instance_type
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.k3s_node_profile.name
  
  user_data = <<-EOF
#!/bin/bash

# 1. K3s 설치
curl -sfL https://get.k3s.io | K3S_TOKEN="${random_password.k3s_token.result}" sh -s - server --cluster-init --write-kubeconfig-mode 644
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc

# 매니페스트 폴더 생성 및 대기
mkdir -p /var/lib/rancher/k3s/server/manifests/
sleep 10

# 2. ArgoCD 설치
cat << 'MANIFEST' > /var/lib/rancher/k3s/server/manifests/argocd.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: argocd
  namespace: kube-system
spec:
  repo: https://argoproj.github.io/argo-helm
  chart: argo-cd
  targetNamespace: argocd
  createNamespace: true
  version: 5.46.7
  set:
    server.extraArgs[0]: --insecure
MANIFEST

# 3. ★ 신규 추가: GitHub 연결용 Secret 매니페스트 (변수 치환을 위해 따옴표 제거) ★
cat << SECRET_MANIFEST > /var/lib/rancher/k3s/server/manifests/github-repo-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: ${var.git_repo_url}
  password: ${var.github_token}
  username: iaminpwd
SECRET_MANIFEST

# 4. ★ 수정됨: 루트 앱 네임스페이스를 argocd로 변경! ★
cat << APP_MANIFEST > /var/lib/rancher/k3s/server/manifests/platform-root.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-root
  namespace: argocd 
spec:
  project: default
  source:
    repoURL: ${var.git_repo_url}
    targetRevision: main
    path: argocd-apps
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
APP_MANIFEST
EOF

  tags = { Name = "k3s-Master" }
}