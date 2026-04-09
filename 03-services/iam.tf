# FILE: ./03-services/iam.tf

# 1. EC2 서비스가 이 역할을 가져다 쓸 수 있도록 허락(Trust)하는 문서
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. K3s 노드용 IAM 역할(Role) 생성
resource "aws_iam_role" "k3s_node_role" {
  name               = "k3s-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# 3. 역할에 권한(Policy) 부여
# (현업 필수 꿀팁: SSM 권한을 주면 SSH 키 없이 브라우저에서 안전하게 터미널 접속 가능!)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 나중에 AWS Cloud Controller Manager 연동을 위한 EC2/EBS 권한을 여기에 추가할 수 있습니다.

# 4. EC2 목에 걸어주기 위한 '인스턴스 프로파일(목걸이 줄)' 생성
resource "aws_iam_instance_profile" "k3s_node_profile" {
  name = "k3s-node-profile"
  role = aws_iam_role.k3s_node_role.name
}