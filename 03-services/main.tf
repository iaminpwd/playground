resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# 1. 점프 서버
resource "aws_instance" "jump_server" {
  ami                    = data.aws_ami.ubuntu_x86.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [var.jump_sg_id]
  subnet_id              = var.public_subnet_id
  key_name               = var.key_name

  tags = { Name = "JumpServer" }
}

# 2. K3s 마스터
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.k3s_sg_id]
  subnet_id              = var.private_subnet_id
  key_name               = var.key_name

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_TOKEN="${random_password.k3s_token.result}" sh -s - server --cluster-init
  EOF

  tags = { Name = "k3s-Master" }
}

# 3. K3s 워커 - Platform
resource "aws_instance" "worker_platform" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.k3s_sg_id]
  subnet_id              = var.private_subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-Platform" }
}

# 4. K3s 워커 - Monitoring
resource "aws_instance" "worker_monitoring" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.k3s_sg_id]
  subnet_id              = var.private_subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-Monitoring" }
}

# 5. K3s 워커 - General
resource "aws_instance" "worker_general" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.micro"
  vpc_security_group_ids = [var.k3s_sg_id]
  subnet_id              = var.private_subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  tags = { Name = "k3s-Worker-General" }
}