data "aws_ami" "ubuntu_x86" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "jump_server" {
  ami                    = data.aws_ami.ubuntu_x86.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [var.sg_id]
  subnet_id              = var.subnet_id
  key_name               = var.key_name

  tags = { Name = "JumpServer" }
}