# ================================================================================
# Security Groups
# ALB accepts public traffic; instances only accept traffic from the ALB
# ================================================================================

# Public entry point — ALB must be reachable from the internet on port 80
resource "aws_security_group" "alb" {
  name        = "asg-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "asg-alb-sg" }
}

# Instances only accept HTTP from the ALB — not directly from the internet
resource "aws_security_group" "instance" {
  name        = "asg-instance-sg"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "asg-instance-sg" }
}
