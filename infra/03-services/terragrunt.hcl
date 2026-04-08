include "root" { path = find_in_parent_folders("root.hcl") }

dependency "network" {
  config_path = "../01-network"
  mock_outputs = {
    public_subnet_id = "mock-subnet-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "security" {
  config_path = "../02-security"
  mock_outputs = {
    node_nsg_id = "mock-nsg-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  subnet_id = dependency.network.outputs.public_subnet_id
  nsg_ids   = [dependency.security.outputs.node_nsg_id]
}