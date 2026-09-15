output "dynamodb_table_name" {
  value = aws_dynamodb_table.toggle_master_analytics.name
}

output "sqs_url" {
  value = aws_sqs_queue.toggle_master_queue.url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
