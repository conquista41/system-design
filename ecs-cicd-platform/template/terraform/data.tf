data "aws_subnets" "existing_subnets" {
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

data "aws_lb" "existing_alb" {
  arn = var.alb_id
}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
