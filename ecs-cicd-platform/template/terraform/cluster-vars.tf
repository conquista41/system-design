# Service image versions — injected via TF_VAR_* environment variables in CI/CD
# Rename YOUR_SERVICE_* to match your actual service names
variable "YOUR_SERVICE_1_VERSION" {
  description = "Docker image tag for service 1 (e.g. prod.1.2.3)"
  type        = string
}
variable "YOUR_SERVICE_2_VERSION" {
  description = "Docker image tag for service 2"
  type        = string
}
variable "YOUR_SERVICE_3_VERSION" {
  description = "Docker image tag for service 3"
  type        = string
}
variable "YOUR_SERVICE_4_VERSION" {
  description = "Docker image tag for service 4"
  type        = string
}

variable "region" {
  description = "AWS region to deploy into (e.g. us-east-1)"
  type        = string
}
variable "vpc_id" {
  description = "ID of the VPC where cluster resources will be created"
  type        = string
}
variable "subnet_name" {
  description = "Tag Name of subnets where EC2 instances will be launched"
  type        = string
}
variable "ecs_instance_ami" {
  description = "ECS-optimized AMI ID for cluster EC2 instances — must match target region"
  type        = string
}
variable "instance_type" {
  description = "EC2 instance type for cluster nodes (e.g. t3a.small for dev, t3a.medium for prod)"
  type        = string
}
variable "ssl_cert_arn" {
  description = "ARN of the ACM certificate to attach to the HTTPS ALB listener"
  type        = string
}
variable "lb_sec_gr_id" {
  description = "Security group ID of the ALB — cluster instances allow all traffic from this group"
  type        = string
}
variable "alb_id" {
  description = "ARN of the existing Application Load Balancer to attach listeners to"
  type        = string
}
variable "default_resource_name" {
  description = "Prefix used for all named AWS resources (e.g. your-project-PROD). Drives naming of IAM roles, ASG, capacity provider, log group, etc."
  type        = string
}
variable "project_name" {
  description = "Project name used in ECR image paths (e.g. your-project). Must match the ECR repository prefix."
  type        = string
}
variable "environment" {
  description = "Deployment environment name used in resource tags (e.g. production, staging, development)"
  type        = string
}
variable "alert_topic_arn" {
  description = "ARN of the existing SNS topic for CloudWatch alarm notifications. Leave empty to disable alarm actions."
  type        = string
  default     = ""
}
variable "ecr_registry" {
  description = "ECR registry base URL without trailing slash (e.g. YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com)"
  type        = string
}
