# 03-services/terragrunt.hcl

terraform {
  # "..//03-services"의 의미:
  # 1. ".." : 상위 폴더(루트)로 가서 전체를 다 복사해라.
  # 2. "//03-services" : 그중에서 실행은 03-services 폴더 안에서 해라.
  source = "..//03-services"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "network" { 
  config_path = "../01-network" 
  mock_outputs = {
    public_subnet_id  = "subnet-mock-public"
    private_subnet_id = "subnet-mock-private"
  }
}
dependency "security" { 
  config_path = "../02-security" 
  mock_outputs = {
    jump_sg_id = "sg-mock-jump"
    k3s_sg_id  = "sg-mock-k3s"
  }
}

inputs = {
  public_subnet_id  = dependency.network.outputs.public_subnet_id
  private_subnet_id = dependency.network.outputs.private_subnet_id
  jump_sg_id        = dependency.security.outputs.jump_sg_id
  k3s_sg_id         = dependency.security.outputs.k3s_sg_id
  key_name          = "keypair"

  cluster_name      = "my-k3s"

  jump_instance_type   = "t3.micro"
  master_instance_type = "t4g.small" # 마스터만 사양을 올려볼까요?
  worker_instance_type = "t4g.micro"
}