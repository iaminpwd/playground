variable "key_name" { type = string }
variable "public_subnet_id" { type = string }
variable "private_subnet_id" { type = string }
variable "jump_sg_id" { type = string }
variable "k3s_sg_id" { type = string }


variable "jump_instance_type" {
  description = "점프 서버의 인스턴스 타입"
  type        = string
}

variable "master_instance_type" {
  description = "K3s 마스터 노드의 인스턴스 타입"
  type        = string
}

variable "worker_instance_type" {
  description = "K3s 워커 노드의 인스턴스 타입"
  type        = string
}

variable "cluster_name" { 
  type    = string
}

variable "git_repo_url" {
  description = "https://github.com/iaminpwd/argocd-test-repo.git"
  type        = string
}