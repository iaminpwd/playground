# 03-services/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "network" { config_path = "../01-network" }
dependency "security" { config_path = "../02-security" }

inputs = {
  public_subnet_id  = dependency.network.outputs.public_subnet_id
  private_subnet_id = dependency.network.outputs.private_subnet_id
  jump_sg_id        = dependency.security.outputs.jump_sg_id
  k3s_sg_id         = dependency.security.outputs.k3s_sg_id
  key_name          = "keypair"
}