# 이 퍼블릭 IP가 출력되어야 이후 Ansible이 이 주소를 보고 서버에 접속할 수 있습니다.
output "node_public_ip" {
  description = "블록체인 노드 퍼블릭 IP"
  value       = oci_core_instance.node.public_ip
}