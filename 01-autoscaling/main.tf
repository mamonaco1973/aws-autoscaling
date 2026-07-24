# ================================================================================
# Provider Configuration
# Pins the AWS provider to the 5.x major version. The ~> constraint allows
# minor-version upgrades (5.1, 5.2...) but blocks 6.x, preventing breaking
# changes from entering the build silently.
# ================================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# ================================================================================
# AMI Lookup
# Queries AWS for the latest Ubuntu 24.04 LTS AMI at plan time, eliminating
# the need to hard-code an AMI ID or maintain a Packer pipeline. Ubuntu is used
# here rather than Amazon Linux so this deployment matches the Azure, GCP, and
# OCI equivalents — a common OS keeps cross-cloud comparisons honest.
# ================================================================================

data "aws_ami" "ubuntu" {
  most_recent = true

  # Canonical's official publisher account — filtering by owner prevents a
  # look-alike community AMI from ever matching the name pattern below
  owners = ["099720109477"]

  # "noble" is the 24.04 LTS codename. The hvm-ssd* wildcard is deliberate:
  # Canonical publishes newer 24.04 builds under hvm-ssd-gp3, so a hardcoded
  # hvm-ssd path silently stops matching current images.
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-arm64-server-*"]
  }

  # HVM (hardware virtual machine) is required for current-gen instance types;
  # paravirtual is a legacy mode not supported on t2/t3 and newer
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # EBS-backed instances support stop/start and snapshot; instance-store
  # instances are ephemeral and cannot be stopped — EBS is the safe default
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
