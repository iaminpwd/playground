# FILE: ./modules/k3s-cluster/iam.tf

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s_node_role" {
  name               = "k3s-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_node_profile" {
  name = "k3s-node-profile"
  role = aws_iam_role.k3s_node_role.name
}

# =====================================================================
# 1. AWS EBS CSI Driver 권한 (AWS 관리형 정책 사용)
# - Kubecost, Prometheus 등이 gp3 영구 볼륨(PVC)을 생성/삭제할 수 있게 합니다.
# =====================================================================
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# =====================================================================
# 2. Cluster Autoscaler (CA) 권한
# - 파드가 부족할 때 ASG의 Desired Capacity를 늘리거나 줄일 수 있게 합니다.
# =====================================================================
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-ca-policy"
  description = "Policy for Cluster Autoscaler"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ca_attach" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# =====================================================================
# 3. AWS Node Termination Handler (NTH) 권한
# - Spot 중단 이벤트를 SQS에서 읽고, 필요시 노드를 강제 종료시킵니다.
# =====================================================================
resource "aws_iam_policy" "nth" {
  name        = "${var.cluster_name}-nth-policy"
  description = "Policy for AWS Node Termination Handler"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstances",
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "nth_attach" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = aws_iam_policy.nth.arn
}

# =====================================================================
# 4. AWS Load Balancer Controller 권한 (ALB 생성/관리)
# - 권한이 수백 줄에 달하므로 AWS 공식 JSON 파일을 다운받아 연결하는 것이 표준입니다.
# =====================================================================
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"
  # 로컬 파일 대신 http 데이터를 바로 사용
  policy      = data.http.alb_controller_policy.response_body 
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.k3s_node_role.name
  policy_arn = aws_iam_policy.alb_controller.arn
}