# 1. 워커 노드용 최신 Ubuntu ARM AMI 조회 (마스터와 동일)
data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

# 2. 시작 템플릿 (Launch Template) 생성
resource "aws_launch_template" "k3s_worker" {
  name_prefix   = "k3s-worker-lt-"
  image_id      = data.aws_ami.ubuntu_arm.id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    security_groups = [var.sg_id]
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  # 💡 Spot 인스턴스 사용 설정 (NTH 테스트 및 비용 절감 용도)
  instance_market_options {
    market_type = "spot"
  }

  # K3s 워커 노드 조인 스크립트 + 스케줄링 라벨/테인트 부여
  user_data = base64encode(<<-EOF
    #!/bin/bash
    
    # 1. 시스템 업데이트 및 필수 패키지 설치
    apt-get update && apt-get install -y curl

    # 2. K3s 워커(Agent) 설치 및 클러스터 조인
    # --node-label: GitOps에서 노드를 식별하기 위한 라벨 지정
    # --kubelet-arg="register-with-taints=...": 전용(Dedicated) 파드만 들어오게 막는 테인트 지정
    curl -sfL https://get.k3s.io | K3S_URL="https://${var.master_private_ip}:6443" K3S_TOKEN="${var.k3s_token}" sh -s - agent \
      --node-label="dedicated=platform" \
      --node-label="node.kubernetes.io/capacity-type=spot" \
      --kubelet-arg="register-with-taints=dedicated=platform:NoSchedule"
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Auto Scaling Group (ASG) 생성
resource "aws_autoscaling_group" "k3s_worker_asg" {
  name                = "${var.cluster_name}-worker-asg"
  vpc_zone_identifier = [var.subnet_id] # Private Subnet 배치

  # CA가 노드를 2개~10개 사이에서 조절할 수 있도록 범위 지정
  desired_capacity = 2
  min_size         = 2
  max_size         = 10

  launch_template {
    id      = aws_launch_template.k3s_worker.id
    version = "$Latest"
  }

  # ★ CA(Cluster Autoscaler)가 이 ASG를 찾기 위한 필수 태그 ★
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-Worker"
    propagate_at_launch = true
  }
}