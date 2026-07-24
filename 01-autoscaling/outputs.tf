output "alb_dns_name" {
  description = "ALB DNS name — open in browser to see the welcome page"
  value       = aws_lb.main.dns_name
}

# Resource names carry a per-deployment suffix, so scripts cannot look them up
# by a hardcoded name. These outputs are how validate.sh and any manual AWS CLI
# work find the right resources for THIS deployment.

output "deployment_name" {
  description = "Base name shared by every resource in this deployment"
  value       = local.name
}

output "target_group_arn" {
  description = "Target group ARN — used by validate.sh to poll target health"
  value       = aws_lb_target_group.main.arn
}

output "asg_name" {
  description = "Auto Scaling Group name — used for instance refresh commands"
  value       = aws_autoscaling_group.main.name
}
