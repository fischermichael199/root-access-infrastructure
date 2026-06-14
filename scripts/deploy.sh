#!/usr/bin/env bash
# deploy.sh â Deploy all root-access CloudFormation stacks in order.
#
# Usage:
#   ./scripts/deploy.sh [environment] [aws-profile] [region]
#
# Examples:
#   ./scripts/deploy.sh prod root-access eu-west-1
#   ./scripts/deploy.sh staging root-access eu-west-1
#
# Notes:
#   - Stack 030 (certificate) is skipped here because it must be deployed
#     separately to us-east-1. See cloudformation/README.md for details.
#   - Stacks are deployed sequentially; each waits for the previous to complete.

set -euo pipefail

ENV="${1:-prod}"
PROFILE="${2:-root-access}"
REGION="${3:-eu-west-1}"
CF_DIR="$(dirname "$0")/../cloudformation"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }
deploy() {
  local template="$1" stack="$2"; shift 2
  log "Deploying $stack from $template ..."
  aws cloudformation deploy \
    --template-file "$CF_DIR/$template" \
    --stack-name "$stack" \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile "$PROFILE" \
    --region "$REGION" \
    --parameter-overrides Environment="$ENV" "$@" \
    --no-fail-on-empty-changeset
  log "$stack â done."
}

log "=== Root Access CloudFormation deploy ==="
log "Environment : $ENV"
log "AWS Profile : $PROFILE"
log "Region      : $REGION"
echo ""

deploy "010-iam.yaml"     "root-access-${ENV}-iam"
deploy "020-storage.yaml" "root-access-${ENV}-storage"
# 030-certificate: deploy separately to us-east-1 (see README)
deploy "040-cdn.yaml"     "root-access-${ENV}-cdn"
deploy "050-dns.yaml"     "root-access-${ENV}-dns" \
  DomainName="${DOMAIN_NAME:-}" HostedZoneId="${HOSTED_ZONE_ID:-}"

log "=== All stacks deployed successfully ==="
