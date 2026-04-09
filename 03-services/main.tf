# 1. 점프 서버 부품 호출
module "jump_server" {
  source = "../modules/jump-server" # 부품 공장 주소

  # 부품(module)이 요구하는 변수에 03-services가 받은 변수를 넘겨줍니다.
  instance_type = var.jump_instance_type
  sg_id         = var.jump_sg_id
  subnet_id     = var.public_subnet_id
  key_name      = var.key_name
}

# 2. K3s 클러스터 부품 호출
module "k3s_cluster" {
  source = "../modules/k3s-cluster"

  master_instance_type = var.master_instance_type
  worker_instance_type = var.worker_instance_type
  sg_id                = var.k3s_sg_id
  subnet_id            = var.private_subnet_id
  key_name             = var.key_name
}