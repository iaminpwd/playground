# FILE: ./terragrunt.hcl
# 루트 terragrunt.hcl

# 1. Provider 자동 생성 설정
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-northeast-2"
}
EOF
}

# 필요한 프로바이더(aws, random) 버전 정의
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
EOF
}

# 2. Remote State (S3 & DynamoDB) 설정
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

# 3. 글로벌 변수 주입 (DRY 원칙)
# 모든 하위 모듈(01-network, 02-security, 03-services)에 공통으로 들어갈 변수
inputs = {
  cluster_name = "my-k3s"
  key_name     = "keypair"
  git_repo_url = "https://github.com/iaminpwd/argocd-test-repo.git"
}