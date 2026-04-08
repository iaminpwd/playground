include "root" { path = find_in_parent_folders("root.hcl") }

dependency "network" {
  config_path = "../01-network"
  
  # init, validate, plan 단계에서만 사용할 가짜 데이터
  mock_outputs = {
    vcn_id = "mock-vcn-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  vcn_id = dependency.network.outputs.vcn_id
}