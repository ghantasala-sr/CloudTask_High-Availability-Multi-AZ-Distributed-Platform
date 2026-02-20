# =============================================================================
# LOAD BALANCERS & TARGET GROUPS
# =============================================================================
# Two ALBs:
#   1. External (internet-facing) — routes traffic to web tier
#   2. Internal (private) — routes traffic from web tier to app tier
#
# Each ALB has a Target Group and a Listener.
# =============================================================================

# =============================================================================
# EXTERNAL ALB (Internet-facing → Web Tier)
# =============================================================================

resource "aws_lb" "external" {
  name               = "${var.project_name}-ext-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ext_alb.id]
  subnets            = aws_subnet.public[*].id # Public subnets

  tags = { Name = "${var.project_name}-ext-alb" }
}

resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-web-tg" }
}

# Listener connects the ALB to the Target Group
resource "aws_lb_listener" "external" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# =============================================================================
# INTERNAL ALB (Web Tier → App Tier)
# =============================================================================

resource "aws_lb" "internal" {
  name               = "${var.project_name}-int-alb"
  internal           = true # Private — not internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.int_alb.id]
  subnets            = aws_subnet.app[*].id # App tier subnets

  tags = { Name = "${var.project_name}-int-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 5000 # Flask port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-app-tg" }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
