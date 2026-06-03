resource "oci_core_instance" "node" {
  availability_domain = data.oci_identity_availability_domains.ad.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "bc-node-01"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = var.nsg_ids
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# 블록체인 데이터용 독립 스토리지 (150GB)
resource "oci_core_volume" "chain_data" {
  availability_domain = data.oci_identity_availability_domains.ad.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "bc-data-vol"
  size_in_gbs         = 150
  
  lifecycle { prevent_destroy = true } # 데이터 보호 장치
}

resource "oci_core_volume_attachment" "chain_data_attach" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.node.id
  volume_id       = oci_core_volume.chain_data.id
}