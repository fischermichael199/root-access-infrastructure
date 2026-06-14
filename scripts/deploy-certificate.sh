#!/usr/bin/env bash
# deploy-certificate.sh â Deploy the ACM certificate stack to us-east-1.
#
# This script MUST be run separately from deploy.sh because CloudFront
# requires ACM certificates to exist in us-east-1, regardless of the
# application's primary AWS region.
#
# Usage:
#   DOMAIN_NAME=root-access.example.com \
#   HOSTED_ZONE_ID=ZXXXXXXXXXXXXX \
#   ./scripts/deploy-certificate.sh [environment] [aws-profile]

set -euo pipefail

ENV="${1:-prod}"
PROFILE="${2:-root-access}"
CF_DIR="$(dirname "$0")/../cloudformation"

: "${DOMAIN_NAME:?DOMAIN_NAME environment variable is required}"
: "${HOSTED_ZONE_ID:?HOSTED_ZONE_ID environment variable is required}"

echo "[INFO] Deploying certificate stack to us-east-1 ..."
aws cloudformation deploy \
  --template-file "$CF_DIR/030-certificate.yaml" \
  --stack-name "root-access-${ENV}-certificate" \
  --region us-east-1 \
  --profile "$PROFILE" \
  --parameter-overrides \
    Environment="$ENV" \
    DomainName="$DOMAIN_NAME" \
    HostedZoneId="$HOSTED_ZONE_ID" \
  --no-fail-on-empty-changeset

echo "[INFO] Certificate deployed. Retrieve the ARN:"
aws cloudformation describe-stacks \
  --stack-name "root-access-${ENV}-certificate" \
  --region us-east-1 \
  --profile "$PROFILE" \
  --query "Stacks[0].Outputs[?OutputKey=='CertificateArn'].OutputValue" \
  --output text
