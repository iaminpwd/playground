# 테라그런트가 이 값을 읽어서 02-security와 03-services로 넘겨줍니다.
output "vcn_id" {
  value = oci_core_vcn.main.id
}

output "public_subnet_id" {
  value = oci_core_subnet.public.id
}