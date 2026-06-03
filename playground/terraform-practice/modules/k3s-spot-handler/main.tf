# 1. SQS 큐 생성 (NTH가 이 큐를 지켜봅니다)
# GitOps 설정 파일(nth_runtime_values.yaml)의 이름과 일치시켜야 합니다.
resource "aws_sqs_queue" "spot_interruption_queue" {
  name                      = "${var.cluster_name}-spot-interruption"
  message_retention_seconds = 300 # 5분이면 충분합니다.
}

# 2. EventBridge 규칙 생성 (Spot 중단 경고 감지)
resource "aws_cloudwatch_event_rule" "spot_interruption_rule" {
  name        = "${var.cluster_name}-spot-interruption-rule"
  description = "Catch Spot Instance Interruption Warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

# 3. EventBridge 타겟 설정 (감지된 이벤트를 SQS로 전송)
resource "aws_cloudwatch_event_target" "sqs_target" {
  rule      = aws_cloudwatch_event_rule.spot_interruption_rule.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.spot_interruption_queue.arn
}

# 4. SQS 정책 설정 (EventBridge가 메시지를 넣을 수 있게 허용)
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.spot_interruption_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.spot_interruption_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.spot_interruption_rule.arn
          }
        }
      }
    ]
  })
}