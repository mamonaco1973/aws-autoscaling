# ================================================================================
# Auto Scaling Group
# Maintains 2-4 instances across both AZs with ELB-based health checks
# ================================================================================

resource "aws_autoscaling_group" "main" {
  name             = "asg-main"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  target_group_arns   = [aws_lb_target_group.main.arn]

  # ELB type defers to ALB health checks rather than EC2 instance status only
  health_check_type = "ELB"

  # 60s grace period lets httpd start before the instance is health-checked
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}

# ================================================================================
# Scaling Policies
# Step adjustments of +1/-1 with 120s cooldown to prevent thrashing
# ================================================================================

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "asg-scale-up"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

# ================================================================================
# CloudWatch Alarms
# Asymmetric periods — scale up fast (2), scale down cautiously (10)
# ================================================================================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "asg-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "asg-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 10
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}
