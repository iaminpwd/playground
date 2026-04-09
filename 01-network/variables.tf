# FILE: ./01-network/variables.tf

variable "enable_nat" {
  description = "NAT Gateway 생성 여부 (비용 절감 스위치)"
  type        = bool
  default     = false # 기본값은 꺼둠(돈 안 나감)
}

variable "cluster_name" {
  description = "K3s 클러스터 이름 (태그 자동 탐색용)"
  type        = string
}