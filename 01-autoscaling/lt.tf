# ================================================================================
# Launch Template
# Defines the blueprint for every EC2 instance the ASG creates. When the ASG
# scales out it launches new instances from the latest version of this template,
# so changes here (new AMI, updated user_data) take effect on the next scale-out
# without needing to replace existing instances.
# ================================================================================

resource "aws_launch_template" "main" {
  # name_prefix lets AWS append a unique suffix on every recreate — without it,
  # Terraform cannot create the replacement before deleting the original because
  # the name would collide
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t4g.micro"

  # Attaches the SSM role so instances register as managed nodes on boot. This
  # is the only inbound path to these instances — see iam.tf.
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm.name
  }

  network_interfaces {
    # Instances live in private subnets and must not receive public IPs —
    # all inbound traffic arrives through the ALB, never directly
    associate_public_ip_address = false
    security_groups             = [aws_security_group.instance.id]
  }

  # filebase64 reads and encodes the script in one step — keeps the HTML/bash
  # out of the Terraform files without needing a templatefile() wrapper
  user_data = filebase64("${path.module}/scripts/userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-instance" }
  }
}
