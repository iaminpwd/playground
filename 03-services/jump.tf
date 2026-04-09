# FILE: ./03-services/jump.tf

resource "aws_instance" "jump_server" {
  ami                    = data.aws_ami.ubuntu_x86.id
  instance_type          = var.jump_instance_type
  vpc_security_group_ids = [var.jump_sg_id]
  subnet_id              = var.public_subnet_id
  key_name               = var.key_name

  tags = { Name = "JumpServer" }
}