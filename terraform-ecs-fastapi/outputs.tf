output "ecr_repository_url" {
  description = "URL dari ECR Repository"
  value       = aws_ecr_repository.fastapi_repo.repository_url
}

output "ecs_cluster_name" {
  description = "Nama ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nama ECS Service"
  value       = aws_ecs_service.fastapi_service.name
}