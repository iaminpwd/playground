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
  cluster_name         = var.cluster_name
  master_instance_type = var.master_instance_type
  sg_id                = var.k3s_sg_id
  subnet_id            = var.private_subnet_id
  key_name             = var.key_name
}

# 3. ★ 신규 추가: K3s 워커 노드 ASG 모듈 호출 ★
module "k3s_worker_asg" {
  source = "../modules/k3s-asg-worker"

  cluster_name          = var.cluster_name
  instance_type         = var.worker_instance_type
  sg_id                 = var.k3s_sg_id
  subnet_id             = var.private_subnet_id
  key_name              = var.key_name
  git_repo_url         = var.git_repo_url
  
  # 마스터 노드에서 생성된 데이터 넘겨주기
  instance_profile_name = module.k3s_cluster.instance_profile_name
  master_private_ip     = module.k3s_cluster.master_private_ip
  k3s_token             = module.k3s_cluster.k3s_token
}

# 4. ★ 신규 추가: Spot 중단 감지 인프라 호출 ★
module "k3s_spot_handler" {
  source       = "../modules/k3s-spot-handler"
  cluster_name = var.cluster_name
}

