# ================================================================================
# Launch Template
# Defines the blueprint for every EC2 instance the ASG creates. When the ASG
# scales out it launches new instances from the latest version of this template,
# so changes here (new AMI, updated user_data) take effect on the next scale-out
# without needing to replace existing instances.
# ================================================================================

locals {
  # The user_data script runs once on first boot via cloud-init. It installs
  # Apache, fetches the instance's private IP from the metadata service, writes
  # a simple HTML welcome page, and starts httpd.
  #
  # IMDSv2 requires a token-based request flow to prevent SSRF attacks against
  # the metadata service. AL2023 disables IMDSv1 by default, so the token PUT
  # must succeed before any metadata value can be read.
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
  # name_prefix lets AWS append a unique suffix on every recreate — without it,
  # Terraform cannot create the replacement before deleting the original because
  # the name would collide
  name_prefix   = "asg-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t4g.micro"

  network_interfaces {
    # Instances live in private subnets and must not receive public IPs —
    # all inbound traffic arrives through the ALB, never directly
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instance.id]
  }

  # user_data must be base64-encoded per the EC2 API contract;
  # Terraform's base64encode() handles this so the script can be kept readable
  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "asg-instance" }
  }
}
