# AWS Auto Scaling

A minimal AWS Auto Scaling example. Two Apache web servers sit behind an
Application Load Balancer. Each server displays its private IP address.
CPU-based CloudWatch alarms scale the group between 2 and 4 instances.

## Architecture

- VPC with two public subnets across us-east-2a and us-east-2b
- Application Load Balancer distributing traffic across subnets
- Auto Scaling Group (min 2, max 4, desired 2)
- Launch Template: Amazon Linux 2023, Apache serving "Welcome to {IP}"
- CloudWatch alarms: scale up at CPU > 60%, scale down at CPU < 60%

## Prerequisites

- AWS account with credentials configured (`aws configure`)
- Terraform >= 1.0

## Deploy

```bash
chmod +x apply.sh destroy.sh
./apply.sh
```

Terraform outputs the ALB DNS name on completion. Open it in a browser —
each refresh may land on a different instance, showing a different IP.

## Scaling Policies

| Alarm    | Condition | Periods  | Action      |
|----------|-----------|----------|-------------|
| cpu-high | CPU > 60% | 2 x 1m   | +1 instance |
| cpu-low  | CPU < 60% | 10 x 1m  | -1 instance |

Both policies have a 120-second cooldown. The asymmetric period counts
(fast scale-up, slow scale-down) prevent thrashing.

## Destroy

```bash
./destroy.sh
```
