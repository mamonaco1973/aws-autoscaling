#!/bin/bash
set -euo pipefail

cd 01-autoscaling
terraform destroy -auto-approve
