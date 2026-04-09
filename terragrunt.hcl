# 루트 terragrunt.hcl

# 1. 기존에 있던 Provider 자동 생성 코드
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-northeast-2"
}
EOF
}

# 2. ★ 새로 추가하는 Remote State (S3 & DynamoDB) 설정 ★
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    # 주의: S3 버킷 이름은 전 세계에서 유일해야 합니다. 본인만의 이름으로 바꿔주세요!
    bucket         = "terraform-practice-state-732245" 
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }
}