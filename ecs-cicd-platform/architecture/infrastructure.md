# Infrastructure Architecture

Generic AWS infrastructure diagram for the ECS CI/CD Platform pattern. Replace `YOUR_SERVICE_1/2/3` with your actual service names — add or remove service blocks to match your count.

---
## Architecture Diagram

![ECS Platform Architecture](../architecture/diagram.png)
## AWS Architecture

```mermaid
graph TD
    Users([Internet / Users])

    Users -->|HTTPS 443| ALB["Application Load Balancer
    HTTP 80 → HTTPS 301 redirect
    TLS 1.3 · ELBSecurityPolicy-TLS13-1-2-2021-06
    Default action: 503 fixed-response"]

    ALB -->|/service1/*| TG1["Target Group · YOUR_SERVICE_1
    Port 8080 · health: /service1/health"]

    ALB -->|/service2/*| TG2["Target Group · YOUR_SERVICE_2
    Port 8080 · health: /service2/health"]

    ALB -->|/service3/*| TG3["Target Group · YOUR_SERVICE_3
    Port 8080 · health: /service3/health"]

    TG1 --> Svc1["ECS Service · YOUR_SERVICE_1
    Bridge mode · autoscaling: mem 65%"]
    TG2 --> Svc2["ECS Service · YOUR_SERVICE_2
    Bridge mode · autoscaling: mem 65%"]
    TG3 --> Svc3["ECS Service · YOUR_SERVICE_3
    Bridge mode · autoscaling: mem 65%"]

    Svc1 --> EC2
    Svc2 --> EC2
    Svc3 --> EC2

    EC2["EC2 Instances
    ECS-optimized AMI
    IMDSv2 enforced
    CloudWatch Agent installed
    SSH disabled · SSM access only"]

    EC2 --> ASG["Auto Scaling Group
    dev:  min 1 / max 1
    prod: min 1 / max 3
    ECS Managed Scaling · target 85%
    lifecycle: ignore desired_capacity"]

    ASG --> Cluster["ECS Cluster
    EC2 launch type
    Container Insights: enabled"]

    Cluster --- CP["ECS Capacity Provider
    Managed scaling
    instance_warmup_period: 90s"]

    ECR["ECR · one repo per service
    YOUR_SERVICE_1 / _2 / _3
    Image scanning enabled
    Tag: env.MAJOR.MINOR.PATCH"]

    ECR -->|pull on task start| Svc1
    ECR -->|pull on task start| Svc2
    ECR -->|pull on task start| Svc3

    SM["AWS Secrets Manager
    DB credentials · API keys · tokens"]
    SM -->|inject at container start| EC2

    DB[(Optional Database
    PostgreSQL / MySQL / Aurora
    credentials via Secrets Manager)]
    DB -.->|application connects| Svc1
    DB -.->|application connects| Svc2
    DB -.->|application connects| Svc3

    EC2 -->|stdout/stderr| CWLogs["CloudWatch Logs
    /ecs/YOUR_CLUSTER_NAME-log-group
    Retention: 7d dev / 30d prod"]

    EC2 -->|mem_used_percent
    disk_used_percent| CWAgent["CloudWatch Agent
    Namespace: CWAgent
    Interval: 300s"]

    CWAgent --> Alarms["CloudWatch Alarms
    EC2: CPU · memory · disk
    ECS cluster: CPU · memory reservation
    Per service: CPU · memory · RunningTaskCount
    ALB: UnhealthyHosts · 5xx errors
    Log metric filter: OOM kills"]

    Alarms -->|notify| SNS["SNS Topic → PagerDuty / Slack / Email"]

    CWLogs --> Grafana["Grafana
    Application dashboards"]
    Prometheus["Prometheus"] -->|scrape /metrics| EC2

    subgraph "Terraform Remote State (per env)"
        S3tf["S3 · encrypted + versioned
        your-terraform-state-bucket"]
        DDB["DynamoDB · state lock
        your-terraform-lock-table"]
    end

    subgraph "Terraform Manages"
        Cluster
        ALB
        CP
        ASG
        EC2
        ECR
        IAM["IAM Roles
        ecs-instance-role:
          AmazonEC2ContainerServiceforEC2Role
          AmazonSSMManagedInstanceCore
          CloudWatchAgentServerPolicy
        ecs-task-execution-role:
          AmazonECSTaskExecutionRolePolicy"]
        SG["Security Groups
        Instances: all traffic from ALB SG only
        No 0.0.0.0/0 inbound · Port 22 closed"]
        CWLogs
    end

    subgraph "Jenkins CI/CD"
        Jenkins["Jenkins
        10-stage pipeline per service per env
        Trivy scan · approval gate · smoke test"]
        Jenkins -->|docker push| ECR
        Jenkins -->|terraform apply| Cluster
        Jenkins -->|ecs update-service| Svc1
        Jenkins -->|ecs update-service| Svc2
        Jenkins -->|ecs update-service| Svc3
    end
```

---

## IAM Role Summary

| Role | Policies | Used By |
|---|---|---|
| `ecs-instance-role` | `AmazonEC2ContainerServiceforEC2Role` — register with ECS cluster | EC2 instance profile |
| `ecs-instance-role` | `AmazonSSMManagedInstanceCore` — SSM Session Manager access | EC2 instance profile |
| `ecs-instance-role` | `CloudWatchAgentServerPolicy` — publish mem/disk metrics | EC2 instance profile |
| `ecs-task-execution-role` | `AmazonECSTaskExecutionRolePolicy` — pull from ECR, write to CloudWatch Logs | ECS task definition |

> ⚠️ **Common mistake:** `AmazonEC2ContainerServiceforEC2Role` is for the **EC2 instance profile only**. The task execution role must use `AmazonECSTaskExecutionRolePolicy` (grants ECR pull + CloudWatch Logs write). Attaching the EC2 policy to a task execution role grants unnecessarily broad permissions.

---

## Security Decisions

| Decision | Implementation |
|---|---|
| No open SSH | Port 22 ingress rule removed; access via SSM Session Manager |
| ALB-only inbound | Instance SG accepts all traffic from ALB SG only (`security_groups = [lb_sec_gr_id]`) |
| IMDSv2 enforced | `metadata_options { http_tokens = "required" }` on launch template — blocks SSRF credential theft |
| Secrets Manager, not env vars | Credentials injected via ECS task definition `secrets` block — never in Dockerfile or state |
| Trivy scan pre-push | CRITICAL CVEs fail the pipeline before image reaches ECR |
