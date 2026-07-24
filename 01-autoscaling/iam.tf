# ================================================================================
# SSM Instance Role
# Grants instances the permissions the SSM agent needs to register itself as a
# managed node and open Session Manager shells. This is the only way onto these
# boxes — they sit in private subnets with no public IP, no SSH key, and a
# security group that accepts port 80 from the ALB and nothing else.
#
# IAM names are account-global — not merely region-scoped — so a hardcoded
# "asg-ssm-role" fails with EntityAlreadyExists the moment this project is
# deployed twice anywhere in the account. Names derive from local.name instead.
# ================================================================================

resource "aws_iam_role" "ssm" {
  name = "${local.name}-ssm-role"

  # Only the EC2 service may assume this role. Without this trust policy the
  # instance profile cannot hand credentials to the instance at boot.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${local.name}-ssm-role" }
}

# AWS-managed policy carrying the ssm/ssmmessages/ec2messages permissions the
# agent needs. Preferred over a hand-rolled policy — AWS updates it as the
# Session Manager API surface changes, so the deployment does not silently rot.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 cannot consume an IAM role directly — the instance profile is the wrapper
# that lets a launch template attach one.
resource "aws_iam_instance_profile" "ssm" {
  name = "${local.name}-ssm-profile"
  role = aws_iam_role.ssm.name

  tags = { Name = "${local.name}-ssm-profile" }
}
