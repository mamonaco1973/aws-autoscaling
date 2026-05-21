#!/bin/bash
set -euo pipefail

cd 01-autoscaling
terraform init
terraform apply -auto-approve

cd ..
./validate.sh
