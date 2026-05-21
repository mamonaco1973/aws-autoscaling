# ================================================================================
# Application Load Balancer
# Public ALB distributes traffic across both AZs and health-checks instances
# ================================================================================

resource "aws_lb" "main" {
  name               = "asg-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "asg-alb" }
}

resource "aws_lb_target_group" "main" {
  name     = "asg-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"

    # 10s interval with 3/2 thresholds balances responsiveness and flap
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }

  tags = { Name = "asg-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
