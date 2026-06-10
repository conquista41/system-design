#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# refresh-microservices.sh
# Force-redeploy all ECS services without building or pushing images.
#
# Use this to:
#   - Restart containers after a Secrets Manager secret rotation
#   - Roll to a new task definition created outside the pipeline
#   - Recover from a stuck / crashed task
#   - Verify deployment config changes without a full pipeline run
#
# This script does NOT build images, push to ECR, or run Terraform.
# For a full versioned deploy, use the Jenkins pipeline.
#
# Usage:
#   ./refresh-microservices.sh [env]
#
# Arguments:
#   env   Optional. dev (default) | prod
#
# Environment variable overrides:
#   CLUSTER_NAME    Override the default cluster name.
#
# Examples:
#   ./refresh-microservices.sh dev
#   ./refresh-microservices.sh prod
#   CLUSTER_NAME=my-platform-PROD ./refresh-microservices.sh prod
#
# Placeholders to replace:
#   YOUR_REGION              AWS region
#   YOUR_CLUSTER_NAME_DEV    ECS cluster name for dev
#   YOUR_CLUSTER_NAME_PROD   ECS cluster name for prod
#   YOUR_SERVICE_*           ECS service names (must match aws_ecs_service.name in Terraform)
#
# IAM permissions required:
#   ecs:UpdateService
#   ecs:DescribeServices  (used by the optional stability wait)
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────
DEPLOY_ENV="${1:-dev}"

if [[ "$DEPLOY_ENV" != "dev" && "$DEPLOY_ENV" != "prod" ]]; then
    echo "Error: env must be 'dev' or 'prod', got: '${DEPLOY_ENV}'"
    echo "Usage: $0 [dev|prod]"
    exit 1
fi

# ── Configuration ───────────────────────────────────────────────────
AWS_REGION="YOUR_REGION"

if [[ "$DEPLOY_ENV" == "prod" ]]; then
    CLUSTER_NAME="${CLUSTER_NAME:-YOUR_CLUSTER_NAME_PROD}"
else
    CLUSTER_NAME="${CLUSTER_NAME:-YOUR_CLUSTER_NAME_DEV}"
fi

# ── Deployment percentages ──────────────────────────────────────────
# Dev:  min=0%  max=100%  → Kill old task immediately, start new.
#       Fast iteration. Brief downtime (~30s) is acceptable.
#
# Prod: min=50% max=200%  → Start new task first, wait for health check,
#       then drain and stop the old task. Zero-downtime rolling update.
#       Requires enough instance capacity for 2× desired tasks.
if [[ "$DEPLOY_ENV" == "prod" ]]; then
    MIN_HEALTHY=50
    MAX_PERCENT=200
else
    MIN_HEALTHY=0
    MAX_PERCENT=100
fi

# ── Services to redeploy ─────────────────────────────────────────────
# These must match the ECS service names exactly as they appear in AWS.
# Convention: YOUR_CLUSTER_NAME-SERVICE-service
# (matches the aws_ecs_service.name pattern in Terraform)
SERVICES=(
    "${CLUSTER_NAME}-YOUR_SERVICE_1-service"
    "${CLUSTER_NAME}-YOUR_SERVICE_2-service"
    "${CLUSTER_NAME}-YOUR_SERVICE_3-service"
    # Add or remove services here
)

# ── Pre-flight info ──────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════"
echo "  ECS Force Redeploy"
echo "  Cluster          : ${CLUSTER_NAME}"
echo "  Environment      : ${DEPLOY_ENV}"
echo "  Region           : ${AWS_REGION}"
echo "  Min healthy      : ${MIN_HEALTHY}%"
echo "  Max tasks        : ${MAX_PERCENT}%"
echo "  Services         : ${#SERVICES[@]} total"
echo "══════════════════════════════════════════════════════"

# ── Force-redeploy each service ─────────────────────────────────────
FAILED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "── ${SERVICE} ───────────────────────────────────────"

    if aws ecs update-service \
        --region "${AWS_REGION}" \
        --cluster "${CLUSTER_NAME}" \
        --service "${SERVICE}" \
        --deployment-configuration \
            "minimumHealthyPercent=${MIN_HEALTHY},maximumPercent=${MAX_PERCENT}" \
        --force-new-deployment \
        --no-cli-pager \
        > /dev/null; then
        echo "  ✓ Redeploy triggered: ${SERVICE}"
    else
        echo "  ✗ Failed to trigger redeploy: ${SERVICE}"
        FAILED_SERVICES+=("${SERVICE}")
    fi
done

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
TOTAL=${#SERVICES[@]}
FAILED=${#FAILED_SERVICES[@]}
SUCCESS=$(( TOTAL - FAILED ))
echo "  Results: ${SUCCESS}/${TOTAL} services triggered"

if [[ $FAILED -gt 0 ]]; then
    echo "  FAILED:"
    for S in "${FAILED_SERVICES[@]}"; do echo "    ✗ ${S}"; done
    echo "══════════════════════════════════════════════════════"
    exit 1
fi

echo "  ECS is rolling out new tasks."
echo "  Old tasks drain as new ones become healthy."
echo "══════════════════════════════════════════════════════"

# ── Optional: wait for service stability ─────────────────────────────
# Uncomment to block the script until ECS reports all services as stable.
# Times out after ~10 minutes (AWS CLI default for services-stable).
# Useful in CI/CD pipelines that must confirm deploy success before proceeding.
#
# echo ""
# echo "Waiting for all services to reach steady state..."
# aws ecs wait services-stable \
#     --region "${AWS_REGION}" \
#     --cluster "${CLUSTER_NAME}" \
#     --services "${SERVICES[@]}"
# echo "All services stable."
