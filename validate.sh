#!/bin/bash
set -euo pipefail

# ================================================================================
# Validation
# Waits for healthy ALB targets then samples responses to confirm load balancing
# ================================================================================

# ------------------------------------------------------------------------------
# Resolve ALB DNS from Terraform output
# ------------------------------------------------------------------------------

cd 01-autoscaling

ALB_DNS=$(terraform output -raw alb_dns_name)

# Pin the region so AWS CLI calls match where Terraform deployed the resources
AWS_REGION="us-east-2"

echo "NOTE: ALB endpoint: http://$ALB_DNS"

# ------------------------------------------------------------------------------
# Wait for Healthy Targets
# Polls every 10s — instances need time for httpd to start and pass health checks
# ------------------------------------------------------------------------------

TG_ARN=$(aws elbv2 describe-target-groups \
  --region "$AWS_REGION" \
  --names asg-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "NOTE: Waiting for healthy targets in asg-tg..."

TIMEOUT=300
ELAPSED=0

while true; do
  HEALTHY=$(aws elbv2 describe-target-health \
    --region "$AWS_REGION" \
    --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
    --output text)

  if [ "$HEALTHY" -ge 1 ]; then
    echo "NOTE: $HEALTHY healthy target(s) registered."
    break
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: Timed out waiting for healthy targets after ${TIMEOUT}s."
    exit 1
  fi

  echo "NOTE: No healthy targets yet — retrying in 10s (${ELAPSED}s elapsed)..."
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

# ------------------------------------------------------------------------------
# Sample Responses
# Hit the ALB 6 times — repeated IPs confirm round-robin across instances
# ------------------------------------------------------------------------------

echo ""
echo "NOTE: Sampling ALB — each request may land on a different instance."
echo ""

for i in $(seq 1 6); do
  RESPONSE=$(curl -sf "http://$ALB_DNS")
  echo "  [$i] $RESPONSE"
done

echo ""
echo "NOTE: Done. Open http://$ALB_DNS in a browser to explore."
