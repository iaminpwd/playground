module "network" {
  source = "./modules/network"
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "jump_server" {
  source    = "./modules/jump_server"
  subnet_id = module.network.public_subnet_id
  sg_id     = module.security.jump_sg_id
  key_name  = var.key_name
}

module "k3s_cluster" {
  source    = "./modules/k3s_cluster"
  subnet_id = module.network.private_subnet_id
  sg_id     = module.security.k3s_sg_id
  key_name  = var.key_name
}