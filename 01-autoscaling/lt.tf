# ================================================================================
# Launch Template
# Defines the AMI, instance type, and bootstrap script for ASG instances
# ================================================================================

locals {
  # IMDSv2 token required — IMDSv1 is disabled on AL2023 by default
  user_data = <<-EOF
    #!/bin/bash
    yum install -y httpd
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/local-ipv4)
    echo "<h1>Welcome to $IP</h1>" > /var/www/html/index.html
    systemctl enable httpd
    systemctl start httpd
  EOF
}

resource "aws_launch_template" "main" {
  # name_prefix avoids conflicts when Terraform recreates the template
  name_prefix   = "asg-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instance.id]
  }

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "asg-instance" }
  }
}
