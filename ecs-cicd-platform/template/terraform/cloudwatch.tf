########################################
# EC2 / ASG ALARMS
########################################

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.default_resource_name}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "EC2 instance CPU above 85% for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ecs_autoscaling_group.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ECS CLUSTER ALARMS
########################################

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_cpu_high" {
  alarm_name          = "${var.default_resource_name}-ecs-cluster-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "ECS cluster CPU reservation above 90% — cluster may be unable to place new tasks"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cluster_memory_high" {
  alarm_name          = "${var.default_resource_name}-ecs-cluster-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS cluster memory reservation above 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ECS SERVICE ALARMS — ADMIN
########################################

resource "aws_cloudwatch_metric_alarm" "admin_service_cpu_high" {
  alarm_name          = "${var.default_resource_name}-admin-svc-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "admin service CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-admin-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "admin_service_memory_high" {
  alarm_name          = "${var.default_resource_name}-admin-svc-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "admin service memory above 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-admin-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "admin_service_task_count_low" {
  alarm_name          = "${var.default_resource_name}-admin-svc-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "admin service has no running tasks — service may be down"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-admin-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ECS SERVICE ALARMS — DEVICE
########################################

resource "aws_cloudwatch_metric_alarm" "device_service_cpu_high" {
  alarm_name          = "${var.default_resource_name}-device-svc-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "device service CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-device-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "device_service_memory_high" {
  alarm_name          = "${var.default_resource_name}-device-svc-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "device service memory above 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-device-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "device_service_task_count_low" {
  alarm_name          = "${var.default_resource_name}-device-svc-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "device service has no running tasks — service may be down"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-device-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ECS SERVICE ALARMS — CLIENT
########################################

resource "aws_cloudwatch_metric_alarm" "client_service_cpu_high" {
  alarm_name          = "${var.default_resource_name}-client-svc-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "client service CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-client-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "client_service_memory_high" {
  alarm_name          = "${var.default_resource_name}-client-svc-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "client service memory above 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-client-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "client_service_task_count_low" {
  alarm_name          = "${var.default_resource_name}-client-svc-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "client service has no running tasks — service may be down"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-client-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ECS SERVICE ALARMS — STORE
########################################

resource "aws_cloudwatch_metric_alarm" "store_service_cpu_high" {
  alarm_name          = "${var.default_resource_name}-store-svc-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "store service CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-store-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "store_service_memory_high" {
  alarm_name          = "${var.default_resource_name}-store-svc-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "store service memory above 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-store-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "store_service_task_count_low" {
  alarm_name          = "${var.default_resource_name}-store-svc-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "store service has no running tasks — service may be down"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.cluster.name
    ServiceName = aws_ecs_service.aws-smartsell-store-service.name
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# ALB TARGET GROUP HEALTH ALARMS
########################################

resource "aws_cloudwatch_metric_alarm" "admin_tg_unhealthy_hosts" {
  alarm_name          = "${var.default_resource_name}-admin-tg-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "admin target group has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.smartsell-admin_target_group.arn_suffix
    LoadBalancer = data.aws_lb.existing_alb.arn_suffix
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "device_tg_unhealthy_hosts" {
  alarm_name          = "${var.default_resource_name}-device-tg-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "device target group has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.smartsell-device_target_group.arn_suffix
    LoadBalancer = data.aws_lb.existing_alb.arn_suffix
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "client_tg_unhealthy_hosts" {
  alarm_name          = "${var.default_resource_name}-client-tg-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "client target group has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.smartsell-client_target_group.arn_suffix
    LoadBalancer = data.aws_lb.existing_alb.arn_suffix
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "store_tg_unhealthy_hosts" {
  alarm_name          = "${var.default_resource_name}-store-tg-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "store target group has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.smartsell-store_target_group.arn_suffix
    LoadBalancer = data.aws_lb.existing_alb.arn_suffix
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.default_resource_name}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 20
  alarm_description   = "ALB returning elevated 5xx errors — possible backend crash or overload"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = data.aws_lb.existing_alb.arn_suffix
  }

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []
  ok_actions    = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}


########################################
# CLOUDWATCH LOG METRIC FILTER — OOM KILLS
########################################

resource "aws_cloudwatch_log_metric_filter" "oom_filter" {
  name           = "${var.default_resource_name}-oom-kills"
  log_group_name = aws_cloudwatch_log_group.log-group.name
  pattern        = "?OutOfMemoryError ?\"killed process\" ?OOMKilled"

  metric_transformation {
    name      = "OOMKillCount"
    namespace = "${var.default_resource_name}-custom"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "oom_alarm" {
  alarm_name          = "${var.default_resource_name}-oom-kill-detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "OOMKillCount"
  namespace           = "${var.default_resource_name}-custom"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "OOM kill detected in ECS container logs"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alert_topic_arn != "" ? [var.alert_topic_arn] : []

  tags = { Environment = var.environment }
}
