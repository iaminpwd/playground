output "sqs_queue_url" {
  value = aws_sqs_queue.spot_interruption_queue.url
}