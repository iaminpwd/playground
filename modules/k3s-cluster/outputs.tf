output "master_private_ip" { value = aws_instance.master.private_ip }

# 워커 노드(ASG) 조인용 토큰 출력 추가
output "k3s_token" { 
  value     = random_password.k3s_token.result
  sensitive = true 
}

# IAM 권한을 워커도 같이 쓸 수 있도록 프로파일 이름 출력 추가
output "instance_profile_name" {
  value = aws_iam_instance_profile.k3s_node_profile.name
}