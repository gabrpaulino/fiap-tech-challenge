resource "aws_sqs_queue" "toggle_master_queue" {
  name                      = "toggle_master_queue"
  receive_wait_time_seconds = 10
}

resource "aws_sqs_queue_policy" "toggle_master_queue_policy" {
  queue_url = aws_sqs_queue.toggle_master_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "sqs:*"
        Resource = aws_sqs_queue.toggle_master_queue.arn
      }
    ]
  })
}