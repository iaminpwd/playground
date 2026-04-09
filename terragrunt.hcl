# 루트 terragrunt.hcl

# 1. Provider 자동 생성 코드 고도화
# AWS뿐만 아니라 ALB 정책 다운로드를 위한 http, ArgoCD 설치를 위한 kubernetes/helm 추가
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "ap-northeast-2"
}

provider "http" {}

# K3s 접속 설정
# 실제 배포 시에는 03-services에서 생성된 마스터 IP를 기반으로 인증 정보를 설정해야 합니다.
# 여기서는 하위 모듈이 프로바이더 선언을 인식할 수 있도록 뼈대만 생성합니다.
provider "kubernetes" {
  # 로컬 환경이나 CI 환경의 kubeconfig를 사용하도록 설정하거나, 
  # 03-services 모듈에서 호스트 정보를 동적으로 주입받도록 구성할 수 있습니다.
  config_path = "~/.kube/config" 
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
EOF
}

# 필요한 모든 프로바이더의 버전 정의
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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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