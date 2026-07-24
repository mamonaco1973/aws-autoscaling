# ================================================================================
# Deployment Identity
# Every named resource in this project derives its name from local.name so the
# whole stack can be deployed more than once in the same account and region.
# Without this, a second deploy collides on account-global names (IAM) and
# region-global names (ALB, target group, ASG, security groups, alarms).
#
# The suffix is generated once and stored in state, so it stays stable across
# repeated applies of the same deployment — it only changes on a fresh deploy.
# ================================================================================

resource "random_string" "suffix" {
  length = 6

  # Lowercase alphanumeric only — ALB and target group names reject uppercase
  # and most punctuation, so this keeps every derived name legal everywhere
  special = false
  upper   = false
}

locals {
  # Base name every resource builds on, e.g. "asg-k3n8q2"
  name = "asg-${random_string.suffix.result}"
}
