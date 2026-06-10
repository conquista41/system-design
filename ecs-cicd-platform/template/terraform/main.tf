terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend values cannot use variables — fill in before running terraform init
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "your-project/production/terraform.tfstate"
    region         = "YOUR_REGION"
    encrypt        = true
    dynamodb_table = "your-terraform-lock-table"
  }
}

provider "aws" {
  region = var.region
}



#create security group for cluster instances
resource "aws_security_group" "service_security_group" {
  vpc_id = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.lb_sec_gr_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.default_resource_name}-sg"
    Environment = var.environment
  }
}




#required role to register instances to ecs cluster
resource "aws_iam_role" "ecs_agent" {
  name               = "${var.default_resource_name}-ecs-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_agent_ssm" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "${var.default_resource_name}-ecs-agent"
  role = aws_iam_role.ecs_agent.name
}

#build launch configuration to create same instances in ASG
resource "aws_launch_template" "ecs-launch-template" {
  image_id = var.ecs_instance_ami
  name     = "${var.default_resource_name}-launch-template"
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_agent.name
  }
  vpc_security_group_ids = [aws_security_group.service_security_group.id]
  instance_type          = var.instance_type
  user_data              = base64encode(templatefile("userdata.txt", { cluster_name = var.default_resource_name }))
  # No key_name — SSH access disabled. Use SSM Session Manager instead.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.default_resource_name}-ec2"
    }
  }
  tags = {
    Name = "${var.default_resource_name}-launch-template"
  }
  lifecycle {
    create_before_destroy = true
  }
}

#ASG to scale your instances
resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  name = "${var.default_resource_name}-asg"
  launch_template {
    id      = aws_launch_template.ecs-launch-template.id
    version = "$Latest"
  }
  vpc_zone_identifier       = data.aws_subnets.existing_subnets.ids
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 240
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}



resource "aws_ecs_cluster" "cluster" {
  name = var.default_resource_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name        = "${var.default_resource_name}"
    Environment = var.environment
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "${var.default_resource_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_autoscaling_group.arn
    #  managed_termination_protection = "ENABLED"
    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 85
      instance_warmup_period    = 60
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = var.alb_id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ssl_cert_arn
  default_action { #default target
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = 503
    }
  }
}
resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = var.alb_id
  port              = "80"
  protocol          = "HTTP"

  default_action { #default target
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

########################################
#PREPARATION BEFORE SERVICES
########################################


# required role to pull image from ECR
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.default_resource_name}-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    Name        = "${var.default_resource_name}-iam-role"
    Environment = var.environment
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "log-group" {
  name              = "${var.default_resource_name}-log-group"
  retention_in_days = 30

  tags = {
    Environment = var.environment
    Application = var.default_resource_name
  }
  lifecycle {
    prevent_destroy = true
  }
}
