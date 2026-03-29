output "jump_server_public_ip" {
  description = "점프 서버 퍼블릭 IP (외부 접속용)"
  value       = aws_instance.jump_server.public_ip
}

output "k3s_master_private_ip" {
  description = "k3s 마스터 노드 프라이빗 IP (점프 서버 내부 접속용)"
  value       = aws_instance.master.private_ip
}