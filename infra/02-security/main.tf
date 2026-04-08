resource "oci_core_network_security_group" "node_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "blockchain-node-nsg"
}

# 1. SSH 허용 (내 IP만)
resource "oci_core_network_security_group_security_rule" "allow_ssh" {
  network_security_group_id = oci_core_network_security_group.node_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.my_ip
  source_type               = "CIDR_BLOCK"
  
  tcp_options {
    destination_port_range {
      max = 22
      min = 22
    }
  }
}

# 2. 블록체인 P2P 포트 허용 (예: 30303)
resource "oci_core_network_security_group_security_rule" "allow_p2p" {
  network_security_group_id = oci_core_network_security_group.node_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  
  tcp_options {
    destination_port_range {
      max = 30303
      min = 30303
    }
  }
}

# 3. 아웃바운드 허용 (모든 트래픽)
resource "oci_core_network_security_group_security_rule" "allow_egress" {
  network_security_group_id = oci_core_network_security_group.node_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}