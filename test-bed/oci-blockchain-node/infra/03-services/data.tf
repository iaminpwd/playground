# 1. 가용 도메인(AD) 자동 검색
data "oci_identity_availability_domains" "ad" {
  compartment_id = var.compartment_id
}

# 2. 최신 Ubuntu 22.04 ARM 이미지 자동 검색
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}