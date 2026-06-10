#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# build-docker-images.sh
# Build Docker images for all microservices.
#
# Uses a single Dockerfile with --build-arg to produce one image
# per service. If your services have separate Dockerfiles, update
# each docker build command to point to the right build context.
#
# Usage:
#   ./build-docker-images.sh <env> <versions_file>
#
# Arguments:
#   env            Deployment environment: dev | prod
#   versions_file  Path to versions.properties (default: versions.properties)
#
# versions.properties format:
#   YOUR_SERVICE_1=1.4.2
#   YOUR_SERVICE_2=1.4.2
#   YOUR_SERVICE_3=0.9.1
#
# Output image tags:
#   YOUR_PROJECT_NAME/YOUR_SERVICE_1:dev.1.4.2
#   YOUR_PROJECT_NAME/YOUR_SERVICE_2:dev.1.4.2
#   YOUR_PROJECT_NAME/YOUR_SERVICE_3:dev.0.9.1
#
# Placeholders to replace:
#   YOUR_PROJECT_NAME   Prefix used in local image names
#   YOUR_SERVICE_*      Service names matching keys in versions.properties
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

if [[ "$DEPLOY_ENV" != "dev" && "$DEPLOY_ENV" != "prod" ]]; then
    echo "Error: env must be 'dev' or 'prod', got: '${DEPLOY_ENV}'"
    exit 1
fi

if [[ ! -f "$VERSIONS_FILE" ]]; then
    echo "Error: versions file not found: ${VERSIONS_FILE}"
    exit 1
fi

# ── Configuration ───────────────────────────────────────────────────
PROJECT_NAME="YOUR_PROJECT_NAME"

# List of services to build.
# Keys must match entries in versions.properties.
SERVICES=(
    "YOUR_SERVICE_1"
    "YOUR_SERVICE_2"
    "YOUR_SERVICE_3"
    # Add or remove services here
)

# ── Helper: read version for a service from properties file ─────────
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

# ── Print header ────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════"
echo "  Building Docker images"
echo "  Environment    : ${DEPLOY_ENV}"
echo "  Versions file  : ${VERSIONS_FILE}"
echo "  Services       : ${SERVICES[*]}"
echo "══════════════════════════════════════════════════════"

# ── Build loop ──────────────────────────────────────────────────────
for SERVICE in "${SERVICES[@]}"; do
    VERSION=$(get_version "$SERVICE")
    IMAGE_TAG="${DEPLOY_ENV}.${VERSION}"
    LOCAL_IMAGE="${PROJECT_NAME}/${SERVICE}:${IMAGE_TAG}"

    echo ""
    echo "──────────────────────────────────────────────────"
    echo "  Service  : ${SERVICE}"
    echo "  Version  : ${VERSION}"
    echo "  Tag      : ${LOCAL_IMAGE}"
    echo "──────────────────────────────────────────────────"

    # Build with --build-arg injection.
    # ENV  → used inside Dockerfile to select config files, optimize for prod, etc.
    # SERVICE → selects which application module to build in a monorepo Dockerfile.
    docker build \
        --build-arg ENV="${DEPLOY_ENV}" \
        --build-arg SERVICE="${SERVICE}" \
        -t "${LOCAL_IMAGE}" \
        .
        # For per-service Dockerfiles, replace the last two lines with:
        # -f "services/${SERVICE}/Dockerfile" \
        # "services/${SERVICE}/"

    echo "  ✓ Built: ${LOCAL_IMAGE}"
done

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  All images built successfully."
echo ""
echo "  Built images:"
for SERVICE in "${SERVICES[@]}"; do
    VERSION=$(get_version "$SERVICE")
    echo "    ${PROJECT_NAME}/${SERVICE}:${DEPLOY_ENV}.${VERSION}"
done
echo ""
echo "  Next: run push-images.sh to push to ECR"
echo "══════════════════════════════════════════════════════"
