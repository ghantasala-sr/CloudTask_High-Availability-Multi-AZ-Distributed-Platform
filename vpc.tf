# =============================================================================
# VPC & NETWORKING
# =============================================================================
# This file creates ALL the networking infrastructure:
#   - VPC (the virtual network)
#   - 8 subnets (2 public + 2 web + 2 app + 2 db)
#   - Internet Gateway (for public subnet internet access)
#   - NAT Gateway (for private subnet outbound internet)
#   - Route Tables (traffic routing rules)
#
# In the console, this took ~15 minutes of clicking.
# In Terraform, it's defined once and deployed in ~2 minutes.
# =============================================================================

# --- Local variables for subnet CIDRs ---
# locals are like constants — define once, use everywhere
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2) # First 2 AZs

  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  web_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  app_subnets    = ["10.0.21.0/24", "10.0.22.0/24"]
  db_subnets     = ["10.0.31.0/24", "10.0.32.0/24"]
}

# =============================================================================
# VPC
# =============================================================================
# This is equivalent to: VPC Console → Create VPC
# enable_dns_hostnames = true lets instances get DNS names

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# =============================================================================
# INTERNET GATEWAY
# =============================================================================
# Attached to the VPC — allows public subnets to reach the internet

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-igw" }
}

# =============================================================================
# SUBNETS
# =============================================================================
# count = 2 creates TWO subnets — one per AZ
# count.index gives 0 and 1, used to pick the AZ and CIDR
#
# This is like clicking "Create subnet" 8 times, but in 4 blocks of code

# --- Public Subnets (for ALB, NAT Gateway) ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${local.azs[count.index]}" }
}

# --- Web Tier Private Subnets (for Nginx) ---
resource "aws_subnet" "web" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.web_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.project_name}-web-${local.azs[count.index]}" }
}

# --- App Tier Private Subnets (for Flask) ---
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.app_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.project_name}-app-${local.azs[count.index]}" }
}

# --- Database Private Subnets (for RDS) ---
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.db_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.project_name}-db-${local.azs[count.index]}" }
}

# =============================================================================
# NAT GATEWAY
# =============================================================================
# NAT Gateway needs an Elastic IP and lives in a PUBLIC subnet.
# It allows private subnet instances to reach the internet (for yum, pip, etc.)

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place in first public subnet

  tags = { Name = "${var.project_name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# --- Public Route Table (routes to Internet Gateway) ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table (routes to NAT Gateway) ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

# Associate ALL private subnets (web, app, db) with private route table
resource "aws_route_table_association" "web" {
  count          = 2
  subnet_id      = aws_subnet.web[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}
