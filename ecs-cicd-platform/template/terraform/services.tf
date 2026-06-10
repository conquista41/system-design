
#######################################
#            SERVICE 1 - Admin
#######################################

# create task definition to build container (k8s pod file)
resource "aws_ecs_task_definition" "aws-smartsell-admin-task" {
  family = "${var.default_resource_name}-admin-task"
  container_definitions = jsonencode([
    {
      "name" : "${var.default_resource_name}-admin-container",
      "image" : "${var.ecr_registry}/${var.project_name}/admin:${var.YOUR_SERVICE_1_VERSION}",
      "cpu" : 0,
      "memoryReservation" : 400,
      "portMappings" : [
        {
          "containerPort" : 8080,
          #              "hostPort": 80,
          "protocol" : "tcp"
        }
      ],
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/admin/health-check || exit 1"]
        interval    = 30 # seconds between checks
        timeout     = 5  # seconds to wait for response
        retries     = 3  # consecutive failures before marking unhealthy
        startPeriod = 10 # grace period after startup (in seconds)
      },
      "essential" : true,
      "logConfiguration" : {
        "logDriver" : "awslogs"
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.log-group.id}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "${var.default_resource_name}"
        }
      },
    }
  ])
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  tags = {
  Name = "${var.default_resource_name}-admin-definition" }
}

# create service to deploy your tasks to a cluster (k8s deployment) MUST USE CAPACITY PROVIDER INSTEAD OF LAUNCH TYPE
resource "aws_ecs_service" "aws-smartsell-admin-service" {
  force_new_deployment = true
  name                 = "${var.default_resource_name}-admin-service"
  cluster              = aws_ecs_cluster.cluster.id
  task_definition      = aws_ecs_task_definition.aws-smartsell-admin-task.arn
  # launch_type          = "EC2"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1

  # NOTE: deployment_minimum_healthy_percent = 0 allows ECS to stop the old task before
  # starting the new one. This avoids needing spare capacity but causes brief downtime (~30s).
  # For zero-downtime rolling updates, set this to 50 or 100 (requires more EC2 capacity).
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.smartsell-admin_target_group.arn
    container_name   = "${var.default_resource_name}-admin-container"
    container_port   = 8080
  }
  depends_on = [aws_autoscaling_group.ecs_autoscaling_group]
}

#LB will direct traffic to TG for service-1
resource "aws_lb_target_group" "smartsell-admin_target_group" {
  name                          = "${var.default_resource_name}-admin-tg"
  port                          = 8080
  protocol                      = "HTTP"
  target_type                   = "instance"
  vpc_id                        = var.vpc_id
  load_balancing_algorithm_type = "least_outstanding_requests"
  deregistration_delay          = 60
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 20
    path                = "/admin/health-check"
    unhealthy_threshold = 4
  }
  tags = {
    Name = "${var.default_resource_name}-admin-tg"
  }
}
resource "aws_lb_listener_rule" "service_rule_admin" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = "100"
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.smartsell-admin_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/admin/*", "/admin"]
    }
  }
}

#service auto scaling according to target cpu or memory utilization
resource "aws_appautoscaling_target" "smartsell-admin_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.aws-smartsell-admin-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_autoscaling_group.ecs_autoscaling_group]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory_admin" {
  name               = "${var.default_resource_name}-memory-autoscaling-admin"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.smartsell-admin_target.resource_id
  scalable_dimension = aws_appautoscaling_target.smartsell-admin_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.smartsell-admin_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 65
  }
}


#######################################
#            SERVICE 2 - Device
#######################################

# create task definition to build container (k8s pod file)
resource "aws_ecs_task_definition" "aws-smartsell-device-task" {
  family = "${var.default_resource_name}-device-task"
  container_definitions = jsonencode([
    {
      "name" : "${var.default_resource_name}-device-container",
      "image" : "${var.ecr_registry}/${var.project_name}/device:${var.YOUR_SERVICE_2_VERSION}",
      "cpu" : 0,
      "memoryReservation" : 400,
      "portMappings" : [
        {
          "containerPort" : 8080,
          #              "hostPort": 80,
          "protocol" : "tcp"
        }
      ],
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/device/health-check || exit 1"]
        interval    = 30 # seconds between checks
        timeout     = 5  # seconds to wait for response
        retries     = 3  # consecutive failures before marking unhealthy
        startPeriod = 10 # grace period after startup (in seconds)
      },
      "essential" : true,
      "logConfiguration" : {
        "logDriver" : "awslogs"
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.log-group.id}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "${var.default_resource_name}"
        }
      },
    }
  ])
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  tags = {
  Name = "${var.default_resource_name}-device-definition" }
}

# create service to deploy your tasks to a cluster (k8s deployment) MUST USE CAPACITY PROVIDER INSTEAD OF LAUNCH TYPE
resource "aws_ecs_service" "aws-smartsell-device-service" {
  force_new_deployment = true
  name                 = "${var.default_resource_name}-device-service"
  cluster              = aws_ecs_cluster.cluster.id
  task_definition      = aws_ecs_task_definition.aws-smartsell-device-task.arn
  # launch_type          = "EC2"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1

  # NOTE: deployment_minimum_healthy_percent = 0 allows ECS to stop the old task before
  # starting the new one. This avoids needing spare capacity but causes brief downtime (~30s).
  # For zero-downtime rolling updates, set this to 50 or 100 (requires more EC2 capacity).
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.smartsell-device_target_group.arn
    container_name   = "${var.default_resource_name}-device-container"
    container_port   = 8080
  }
  depends_on = [aws_autoscaling_group.ecs_autoscaling_group]
}

#LB will direct traffic to TG for service-2
resource "aws_lb_target_group" "smartsell-device_target_group" {
  name                          = "${var.default_resource_name}-device-tg"
  port                          = 8080
  protocol                      = "HTTP"
  target_type                   = "instance"
  vpc_id                        = var.vpc_id
  load_balancing_algorithm_type = "least_outstanding_requests"
  deregistration_delay          = 60
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 20
    path                = "/device/health-check"
    unhealthy_threshold = 4
  }
  tags = {
    Name = "${var.default_resource_name}-device-tg"
  }
}
resource "aws_lb_listener_rule" "service_rule_device" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = "200"
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.smartsell-device_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/device/*", "/device"]
    }
  }
}

#service auto scaling according to target cpu or memory utilization
resource "aws_appautoscaling_target" "smartsell-device_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.aws-smartsell-device-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_autoscaling_group.ecs_autoscaling_group]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory_device" {
  name               = "${var.default_resource_name}-memory-autoscaling-device"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.smartsell-device_target.resource_id
  scalable_dimension = aws_appautoscaling_target.smartsell-device_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.smartsell-device_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 65
  }
}

#######################################
#            SERVICE 3 - Client
#######################################

# create task definition to build container (k8s pod file)
resource "aws_ecs_task_definition" "aws-smartsell-client-task" {
  family = "${var.default_resource_name}-client-task"
  container_definitions = jsonencode([
    {
      "name" : "${var.default_resource_name}-client-container",
      "image" : "${var.ecr_registry}/${var.project_name}/client:${var.YOUR_SERVICE_3_VERSION}",
      "cpu" : 0,
      "memoryReservation" : 400,
      "portMappings" : [
        {
          "containerPort" : 8080,
          #              "hostPort": 80,
          "protocol" : "tcp"
        }
      ],
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/client/health-check || exit 1"]
        interval    = 30 # seconds between checks
        timeout     = 5  # seconds to wait for response
        retries     = 3  # consecutive failures before marking unhealthy
        startPeriod = 10 # grace period after startup (in seconds)
      },
      "essential" : true,
      "logConfiguration" : {
        "logDriver" : "awslogs"
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.log-group.id}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "${var.default_resource_name}"
        }
      },
    }
  ])
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  tags = {
  Name = "${var.default_resource_name}-client-definition" }
}

# create service to deploy your tasks to a cluster (k8s deployment) MUST USE CAPACITY PROVIDER INSTEAD OF LAUNCH TYPE
resource "aws_ecs_service" "aws-smartsell-client-service" {
  force_new_deployment = true
  name                 = "${var.default_resource_name}-client-service"
  cluster              = aws_ecs_cluster.cluster.id
  task_definition      = aws_ecs_task_definition.aws-smartsell-client-task.arn
  # launch_type          = "EC2"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1

  # NOTE: deployment_minimum_healthy_percent = 0 allows ECS to stop the old task before
  # starting the new one. This avoids needing spare capacity but causes brief downtime (~30s).
  # For zero-downtime rolling updates, set this to 50 or 100 (requires more EC2 capacity).
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.smartsell-client_target_group.arn
    container_name   = "${var.default_resource_name}-client-container"
    container_port   = 8080
  }
  depends_on = [aws_autoscaling_group.ecs_autoscaling_group]
}

#LB will direct traffic to TG for service-3
resource "aws_lb_target_group" "smartsell-client_target_group" {
  name                          = "${var.default_resource_name}-client-tg"
  port                          = 8080
  protocol                      = "HTTP"
  target_type                   = "instance"
  vpc_id                        = var.vpc_id
  load_balancing_algorithm_type = "least_outstanding_requests"
  deregistration_delay          = 60
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 20
    path                = "/client/health-check"
    unhealthy_threshold = 4
  }
  tags = {
    Name = "${var.default_resource_name}-client-tg"
  }
}
resource "aws_lb_listener_rule" "service_rule_client" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = "300"
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.smartsell-client_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/client/*", "/client"]
    }
  }
}

#service auto scaling according to target cpu or memory utilization
resource "aws_appautoscaling_target" "smartsell-client_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.aws-smartsell-client-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_autoscaling_group.ecs_autoscaling_group]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory_client" {
  name               = "${var.default_resource_name}-memory-autoscaling-client"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.smartsell-client_target.resource_id
  scalable_dimension = aws_appautoscaling_target.smartsell-client_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.smartsell-client_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 65
  }
}

#######################################
#            SERVICE 4 - Store
#######################################

# create task definition to build container (k8s pod file)
resource "aws_ecs_task_definition" "aws-smartsell-store-task" {
  family = "${var.default_resource_name}-store-task"
  container_definitions = jsonencode([
    {
      "name" : "${var.default_resource_name}-store-container",
      "image" : "${var.ecr_registry}/${var.project_name}/store:${var.YOUR_SERVICE_4_VERSION}",
      "cpu" : 0,
      "memoryReservation" : 400,
      "portMappings" : [
        {
          "containerPort" : 8080,
          #              "hostPort": 80,
          "protocol" : "tcp"
        }
      ],
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/store/health-check || exit 1"]
        interval    = 30 # seconds between checks
        timeout     = 5  # seconds to wait for response
        retries     = 3  # consecutive failures before marking unhealthy
        startPeriod = 10 # grace period after startup (in seconds)
      },
      "essential" : true,
      "logConfiguration" : {
        "logDriver" : "awslogs"
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.log-group.id}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "${var.default_resource_name}"
        }
      },
    }
  ])
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  tags = {
  Name = "${var.default_resource_name}-store-definition" }
}

# create service to deploy your tasks to a cluster (k8s deployment) MUST USE CAPACITY PROVIDER INSTEAD OF LAUNCH TYPE
resource "aws_ecs_service" "aws-smartsell-store-service" {
  force_new_deployment = true
  name                 = "${var.default_resource_name}-store-service"
  cluster              = aws_ecs_cluster.cluster.id
  task_definition      = aws_ecs_task_definition.aws-smartsell-store-task.arn
  # launch_type          = "EC2"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1

  # NOTE: deployment_minimum_healthy_percent = 0 allows ECS to stop the old task before
  # starting the new one. This avoids needing spare capacity but causes brief downtime (~30s).
  # For zero-downtime rolling updates, set this to 50 or 100 (requires more EC2 capacity).
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 100
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.smartsell-store_target_group.arn
    container_name   = "${var.default_resource_name}-store-container"
    container_port   = 8080
  }
  depends_on = [aws_autoscaling_group.ecs_autoscaling_group]
}

#LB will direct traffic to TG for service-4
resource "aws_lb_target_group" "smartsell-store_target_group" {
  name                          = "${var.default_resource_name}-store-tg"
  port                          = 8080
  protocol                      = "HTTP"
  target_type                   = "instance"
  vpc_id                        = var.vpc_id
  load_balancing_algorithm_type = "least_outstanding_requests"
  deregistration_delay          = 60
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 20
    path                = "/store/health-check"
    unhealthy_threshold = 4
  }
  tags = {
    Name = "${var.default_resource_name}-store-tg"
  }
}
resource "aws_lb_listener_rule" "service_rule_store" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = "400"
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.smartsell-store_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/store/*", "/store"]
    }
  }
}

#service auto scaling according to target cpu or memory utilization
resource "aws_appautoscaling_target" "smartsell-store_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.aws-smartsell-store-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_autoscaling_group.ecs_autoscaling_group]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory_store" {
  name               = "${var.default_resource_name}-memory-autoscaling-store"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.smartsell-store_target.resource_id
  scalable_dimension = aws_appautoscaling_target.smartsell-store_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.smartsell-store_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 65
  }
}
