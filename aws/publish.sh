#!/usr/bin/env bash
set -euo pipefail

BUCKET="digiusher-cf-templates"
PREFIX="templates"
TEMPLATE="DigiUsher.yaml"
REGION="us-east-1"

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: $TEMPLATE not found in current directory"
  exit 1
fi

SHA=$(git rev-parse --short HEAD)

echo "Publishing $TEMPLATE (commit $SHA) to s3://$BUCKET/$PREFIX/"

# Upload versioned copy
aws s3 cp "$TEMPLATE" "s3://$BUCKET/$PREFIX/${TEMPLATE%.yaml}-${SHA}.yaml" \
  --region "$REGION"

# Upload as latest
aws s3 cp "$TEMPLATE" "s3://$BUCKET/$PREFIX/$TEMPLATE" \
  --region "$REGION"

TEMPLATE_URL="https://$BUCKET.s3.amazonaws.com/$PREFIX/$TEMPLATE"

echo "Published:"
echo "  Versioned: https://$BUCKET.s3.amazonaws.com/$PREFIX/${TEMPLATE%.yaml}-${SHA}.yaml"
echo "  Latest:    $TEMPLATE_URL"
echo ""
echo "Launch Stack URL:"
echo "  https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks/new?stackName=DigiUsher&templateURL=$TEMPLATE_URL"
