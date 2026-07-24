#!/bin/bash
# ===============================================================================
# File: validate.sh
# ===============================================================================

set -euo pipefail

REGION="us-east-2"

# ------------------------------------------------------------------------------
# Deploy Timing
# T_ANCHOR is the start of the whole deployment. apply.sh exports DEPLOY_START
# so the headline number spans terraform apply + provisioning + boot + health
# checks — the same window on every cloud, which is what makes cross-provider
# comparison valid.
#
# Running validate.sh standalone falls back to "now", which times only the
# health wait. That number is NOT comparable across providers: each one's
# apply returns at a different point in the lifecycle (Azure's VMSS apply
# waits for VM provisioning, AWS's ASG apply returns as soon as the group
# exists), so the remaining wait measures a different span on each cloud.
#
# Poll interval is fixed at 5s in all four projects — measurement resolution
# cannot be finer than the poll, and a 30s poll cannot resolve a 20s gap.
# ------------------------------------------------------------------------------

T_ANCHOR="${DEPLOY_START:-$(date +%s)}"
T_VALIDATE_START=$(date +%s)
POLL=5

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

TIMEOUT=600

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

  # Elapsed is read from the clock, not accumulated from sleeps — the AWS CLI
  # call above takes non-trivial time, so a sleep counter drifts badly
  ELAPSED=$(( $(date +%s) - T_VALIDATE_START ))
  if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
    echo "ERROR: Timed out waiting for healthy targets after ${TIMEOUT}s."
    exit 1
  fi

  echo "NOTE: No healthy targets yet — retrying in ${POLL}s (${ELAPSED}s elapsed)..."
  sleep "${POLL}"
done

# ------------------------------------------------------------------------------
# Step 2b: Wait for the first HTTP 200 through the load balancer
# This is the timed metric. "First 200 through the LB" is the one definition
# that means the same thing on all four clouds — a healthy target in a target
# group is an AWS-specific concept with no exact equivalent elsewhere.
# ------------------------------------------------------------------------------

echo "NOTE: Waiting for first HTTP 200 through the ALB..."

while true; do
  HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 \
    "http://${ALB_DNS}/plain" 2>/dev/null || echo "000")

  if [ "${HTTP_CODE}" = "200" ]; then
    T_FIRST_OK=$(date +%s)
    echo "NOTE: First HTTP 200 received."
    break
  fi

  ELAPSED=$(( $(date +%s) - T_VALIDATE_START ))
  if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
    echo "ERROR: Timed out waiting for HTTP 200 after ${TIMEOUT}s."
    exit 1
  fi

  echo "NOTE: HTTP ${HTTP_CODE} — retrying in ${POLL}s (${ELAPSED}s elapsed)..."
  sleep "${POLL}"
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
echo "  Deployment    : $(terraform -chdir=01-autoscaling output -raw deployment_name)"
echo "  ALB           : http://${ALB_DNS}"
echo "---------------------------------------------------------------------------------"
echo "  Time to first request : $((T_FIRST_OK - T_ANCHOR))s"
if [ -z "${DEPLOY_START:-}" ]; then
  echo "  WARNING: DEPLOY_START unset — timed from validate.sh only, which is"
  echo "           NOT comparable across clouds. Run ./apply.sh for the real number."
else
  echo "  Health wait only      : $((T_FIRST_OK - T_VALIDATE_START))s"
fi
echo "================================================================================="
