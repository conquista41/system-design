output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.cluster.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.cluster.arn
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.log-group.name
}

output "task_execution_role_arn" {
  description = "ECS task execution IAM role ARN"
  value       = aws_iam_role.ecsTaskExecutionRole.arn
}

output "alb_listener_arn" {
  description = "HTTPS ALB listener ARN"
  value       = aws_lb_listener.listener.arn
}

output "security_group_id" {
  description = "EC2 cluster instance security group ID"
  value       = aws_security_group.service_security_group.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.ecs_autoscaling_group.name
}

output "alb_dns_name" {
  description = "ALB DNS name — used by the Jenkinsfile smoke test (terraform output -raw alb_dns_name)"
  value       = data.aws_lb.existing_alb.dns_name
}
