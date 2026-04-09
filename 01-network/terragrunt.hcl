include "root" {
  path = find_in_parent_folders()
}

inputs = {
  # 👇 스위치 조작부 (필요할 때만 true로 바꾸고 배포!)
  enable_nat = false
}