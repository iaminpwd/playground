# FILE: ./03-services/worker.tf

# 워커 노드로 만들 이름들을 리스트로 정의합니다.
locals {
  worker_nodes = ["Platform", "Monitoring", "General"]
}

resource "aws_instance" "workers" {
  # local.worker_nodes 리스트를 순회하며 인스턴스를 찍어냅니다.
  for_each               = toset(local.worker_nodes)
  
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = var.worker_instance_type
  vpc_security_group_ids = [var.k3s_sg_id]
  subnet_id              = var.private_subnet_id
  key_name               = var.key_name
  depends_on             = [aws_instance.master]

  iam_instance_profile   = aws_iam_instance_profile.k3s_node_profile.name

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.master.private_ip}:6443" K3S_TOKEN="${random_password.k3s_token.result}" sh -
  EOF

  # each.key에는 "Platform", "Monitoring" 등의 값이 차례대로 들어갑니다.
  tags = { Name = "k3s-Worker-${each.key}" }
}