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
    curl -sfL https://get.k3s.io | K3S_TOKEN="${random_password.k3s_token.result}" sh -s - server --cluster-init
  EOF

  tags = { Name = "k3s-Master" }
}
