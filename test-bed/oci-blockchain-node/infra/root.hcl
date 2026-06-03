generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "oci" {
  region           = "ap-chuncheon-1"
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
EOF
}

# 하위 모듈로 내려보낼 공통 변수들
inputs = {
  # 아래 값들은 본인의 OCI 환경에 맞게 실제 값으로 변경해야 합니다.
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaa65iky254g3bzk3cpjubjyn4yoio2i4xk4cyqdakqddbyf53sosgq"
  my_ip          = "49.1.53.163/32" # 본인의 퍼블릭 IP
  ssh_public_key = file("~/.ssh/id_rsa.pub")

  common_tags = {
    Project     = "oci-blockchain-node"
    ManagedBy   = "Terragrunt"
    Environment = "Dev"
  }
}