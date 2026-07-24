#!/bin/bash
set -euo pipefail

# Anchor for the deploy-timing metric reported by validate.sh. Set before
# terraform runs so the measured window covers apply + provisioning + boot +
# health checks — the same span on every cloud. init is excluded because
# provider download time depends on local cache state, not the cloud.
terraform -chdir=01-autoscaling init

export DEPLOY_START=$(date +%s)

terraform -chdir=01-autoscaling apply -auto-approve

./validate.sh
