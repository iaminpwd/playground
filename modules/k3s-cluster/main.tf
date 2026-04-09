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

    # 2. 매니페스트 폴더 생성 및 대기 (가장 안전한 방식)
    mkdir -p /var/lib/rancher/k3s/server/manifests/
    sleep 10

    # 3. ArgoCD 헬름 차트 매니페스트 (변수가 없으므로 작은따옴표 유지)
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

    # 4. 루트 앱 매니페스트 (★ 테라폼 변수가 있으므로 작은따옴표 제거!)
    cat << APP_MANIFEST > /var/lib/rancher/k3s/server/manifests/platform-root.yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: platform-root
      namespace: kube-system 
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