resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

data "aws_ami" "ubuntu_arm" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

# 1. 마스터 노드
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_TOKEN="${random_password.k3s_token.result}" sh -s - server --cluster-init
  EOF

  tags = { Name = "k3s-Master" }
}

# 2. Platform 워커 노드
resource "aws_instance" "worker_platform" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-Platform" }
}

# 3. Monitoring 워커 노드
resource "aws_instance" "worker_monitoring" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-Monitoring" }
}

# 4. 일반 Worker 노드
resource "aws_instance" "worker_general" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-General" }
}