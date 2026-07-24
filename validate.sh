#!/bin/bash
# ===============================================================================
# File: validate.sh
# ===============================================================================

set -euo pipefail

REGION="us-east-2"

# ------------------------------------------------------------------------------
# Step 1: Resolve ALB DNS from Terraform output
# ------------------------------------------------------------------------------

ALB_DNS=$(terraform -chdir=01-autoscaling output -raw alb_dns_name 2>/dev/null || true)

if [ -z "${ALB_DNS}" ]; then
  echo "ERROR: Could not read Terraform outputs. Run ./apply.sh first."
  exit 1
fi

echo "NOTE: ALB endpoint: http://${ALB_DNS}"

# ------------------------------------------------------------------------------
# Step 2: Wait for healthy targets
# Polls every 10s — instances need time for apache2 to start and pass checks.
# The ARN comes from Terraform rather than a name lookup: resource names carry
# a per-deployment suffix, so a hardcoded name would find the wrong deployment
# (or none) once this project is deployed more than once.
# ------------------------------------------------------------------------------

TG_ARN=$(terraform -chdir=01-autoscaling output -raw target_group_arn)

echo "NOTE: Waiting for healthy targets in ${TG_ARN##*/}..."

TIMEOUT=300
ELAPSED=0

while true; do
  HEALTHY=$(aws elbv2 describe-target-health \
    --region "${REGION}" \
    --target-group-arn "${TG_ARN}" \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
    --output text)

  if [ "${HEALTHY}" -ge 1 ]; then
    echo "NOTE: ${HEALTHY} healthy target(s) registered."
    break
  fi

  if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
    echo "ERROR: Timed out waiting for healthy targets after ${TIMEOUT}s."
    exit 1
  fi

  echo "NOTE: No healthy targets yet — retrying in 10s (${ELAPSED}s elapsed)..."
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

# ------------------------------------------------------------------------------
# Step 3: Sample ALB responses
# Hit the endpoint 6 times — different IPs confirm load balancing is working
# ------------------------------------------------------------------------------

echo "NOTE: Sampling ALB responses..."
echo ""

for i in $(seq 1 6); do
  RESPONSE=$(curl -sf "http://${ALB_DNS}/plain")
  echo "  [${i}] ${RESPONSE}"
done

echo ""
echo "================================================================================="
echo "  Auto Scaling Group — Deployment validated!"
echo "================================================================================="
echo "  Deployment : $(terraform -chdir=01-autoscaling output -raw deployment_name)"
echo "  ALB        : http://${ALB_DNS}"
echo "================================================================================="
