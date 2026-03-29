output "jump_sg_id" { value = aws_security_group.jump_server_sg.id }
output "k3s_sg_id" { value = aws_security_group.k3s_cluster_sg.id }