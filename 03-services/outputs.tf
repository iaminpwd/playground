output "jump_server_public_ip" {
  value = module.jump_server.public_ip
}

output "k3s_master_private_ip" {
  value = module.k3s_cluster.master_private_ip
}