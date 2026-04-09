# 02-security/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "network" {
  config_path = "../01-network"

  mock_outputs = {
    vpc_id = "vpc-mock-12345"
  }
}

# 01-network의 output 값을 02-security의 변수(vpc_id)로 자동 주입
inputs = {
  vpc_id = dependency.network.outputs.vpc_id
}