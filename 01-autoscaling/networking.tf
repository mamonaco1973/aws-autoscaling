# ================================================================================
# Networking
# Public subnets for the ALB; private subnets for instances behind a NAT gateway
# ================================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "asg-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "asg-igw" }
}

# ================================================================================
# Public Subnets
# ALB lives here — one per AZ for high availability
# ================================================================================

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = { Name = "asg-public-us-east-2a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = { Name = "asg-public-us-east-2b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "asg-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ================================================================================
# NAT Gateway
# Single NAT in public_a — instances need outbound internet for yum installs
# ================================================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "asg-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = { Name = "asg-nat" }

  # IGW must exist before the NAT gateway can be created
  depends_on = [aws_internet_gateway.main]
}

# ================================================================================
# Private Subnets
# Instances live here — no public IPs, outbound only via NAT gateway
# ================================================================================

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.128/26"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = { Name = "asg-private-us-east-2a" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.192/26"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = false

  tags = { Name = "asg-private-us-east-2b" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "asg-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
