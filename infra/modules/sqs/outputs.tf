output "queue_id" {
  value = aws_sqs_queue.main.id
}

output "queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "queue_url" {
  value = aws_sqs_queue.main.url
}

output "queue_name" {
  value       = aws_sqs_queue.main.name
  description = "SQS queue name (CloudWatch dimension QueueName)."
}

output "dlq_name" {
  value       = aws_sqs_queue.dlq.name
  description = "Dead-letter queue name for CloudWatch."
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
