#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# push-images.sh
# Authenticate to Amazon ECR and push all service images.
#
# Expects images to already be built locally by
# build-docker-images.sh. Authenticates once (token covers all
# repos in the same account + region), then tags and pushes each
# service image in turn.
#
# Usage:
#   ./push-images.sh <env> [versions_file]
#
# Arguments:
#   env            Deployment environment: dev | prod
#   versions_file  Path to versions.properties (default: versions.properties)
#
# Placeholders to replace:
#   YOUR_REGION         AWS region (e.g. eu-west-1)
#   YOUR_ACCOUNT_ID     12-digit AWS account ID
#   YOUR_PROJECT_NAME   Prefix matching local image names and ECR repo paths
#   YOUR_SERVICE_*      Service names matching keys in versions.properties
#
# IAM permissions required on the executing role/user:
#   ecr:GetAuthorizationToken
#   ecr:BatchCheckLayerAvailability
#   ecr:InitiateLayerUpload / UploadLayerPart / CompleteLayerUpload
#   ecr:PutImage
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────
DEPLOY_ENV="${1:-}"
VERSIONS_FILE="${2:-versions.properties}"

if [[ -z "$DEPLOY_ENV" ]]; then
    echo "Usage: $0 <env> [versions_file]"
    echo "       env: dev | prod"
    exit 1
fi

if [[ ! -f "$VERSIONS_FILE" ]]; then
    echo "Error: versions file not found: ${VERSIONS_FILE}"
    exit 1
fi

# ── Configuration ───────────────────────────────────────────────────
AWS_REGION="YOUR_REGION"
AWS_ACCOUNT_ID="YOUR_ACCOUNT_ID"
PROJECT_NAME="YOUR_PROJECT_NAME"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

SERVICES=(
    "YOUR_SERVICE_1"
    "YOUR_SERVICE_2"
    "YOUR_SERVICE_3"
    # Add or remove services here
)

# ── Helper: read version from properties file ───────────────────────
get_version() {
    local service="$1"
    local version
    version=$(grep -E "^${service}=" "$VERSIONS_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
    if [[ -z "$version" ]]; then
        echo "Error: version for '${service}' not found in ${VERSIONS_FILE}" >&2
        exit 1
    fi
    echo "$version"
}

echo "══════════════════════════════════════════════════════"
echo "  Pushing images to ECR"
echo "  Registry    : ${ECR_REGISTRY}"
echo "  Environment : ${DEPLOY_ENV}"
echo "  Services    : ${SERVICES[*]}"
echo "══════════════════════════════════════════════════════"

# ── Step 1: ECR Login ────────────────────────────────────────────────
# The ECR auth token is valid for 12 hours.
# One login covers all repositories in the same account + region.
echo ""
echo "── ECR Login ──────────────────────────────────────────"
aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "  ✓ Authenticated to ${ECR_REGISTRY}"

# ── Step 2: Tag + Push per service ──────────────────────────────────
FAILED_SERVICES=()

for SERVICE in "${SERVICES[@]}"; do
    VERSION=$(get_version "$SERVICE")
    IMAGE_TAG="${DEPLOY_ENV}.${VERSION}"
    LOCAL_IMAGE="${PROJECT_NAME}/${SERVICE}:${IMAGE_TAG}"
    ECR_IMAGE="${ECR_REGISTRY}/${PROJECT_NAME}/${SERVICE}:${IMAGE_TAG}"

    echo ""
    echo "──────────────────────────────────────────────────"
    echo "  Service  : ${SERVICE}"
    echo "  Local    : ${LOCAL_IMAGE}"
    echo "  ECR      : ${ECR_IMAGE}"
    echo "──────────────────────────────────────────────────"

    # Verify the local image exists before attempting to push.
    # Fail with a clear message rather than a confusing Docker error.
    if ! docker image inspect "${LOCAL_IMAGE}" > /dev/null 2>&1; then
        echo "  ✗ Local image not found: ${LOCAL_IMAGE}"
        echo "    Run build-docker-images.sh first."
        FAILED_SERVICES+=("${SERVICE}")
        continue
    fi

    # Tag the local image with the full ECR URI
    docker tag "${LOCAL_IMAGE}" "${ECR_IMAGE}"

    # Push to ECR
    if docker push "${ECR_IMAGE}"; then
        echo "  ✓ Pushed: ${ECR_IMAGE}"
    else
        echo "  ✗ Push failed: ${ECR_IMAGE}"
        FAILED_SERVICES+=("${SERVICE}")
    fi
done

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
TOTAL=${#SERVICES[@]}
FAILED=${#FAILED_SERVICES[@]}
SUCCESS=$(( TOTAL - FAILED ))
echo "  Results: ${SUCCESS}/${TOTAL} services pushed"

if [[ $FAILED -gt 0 ]]; then
    echo "  FAILED:"
    for S in "${FAILED_SERVICES[@]}"; do echo "    ✗ ${S}"; done
    echo "══════════════════════════════════════════════════════"
    exit 1
fi

echo "  All images pushed successfully."
echo "  Next: run refresh-microservices.sh or trigger the Jenkins pipeline."
echo "══════════════════════════════════════════════════════"

# ── Optional: remove ECR-tagged local copies ─────────────────────
# Uncomment to clean up ECR-tagged copies after push (saves disk on CI agents).
# for SERVICE in "${SERVICES[@]}"; do
#     VERSION=$(get_version "$SERVICE")
#     ECR_IMAGE="${ECR_REGISTRY}/${PROJECT_NAME}/${SERVICE}:${DEPLOY_ENV}.${VERSION}"
#     docker image rm -f "${ECR_IMAGE}" || true
# done
