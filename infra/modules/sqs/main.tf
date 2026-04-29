resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-submissions-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = merge(var.tags, { Purpose = "dlq" })
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.name_prefix}-submissions"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  receive_wait_time_seconds  = 0

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    "maxReceiveCount"   = var.max_receive_count
  })

  tags = merge(var.tags, { Purpose = "submissions" })
}
