

# ==========================================
# FILE: terraform/aws/outputs.tf
# ==========================================
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.cdc.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.landing.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.landing.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.cdc.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.cdc.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

