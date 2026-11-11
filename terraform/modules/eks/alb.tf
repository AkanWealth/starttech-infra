# Application Load Balancer for the backend API (CloudFront origin "ALB-Backend").
#
# Terraform owns the ALB so CloudFront can reference its DNS name in the
# same apply. The ALB forwards to the worker nodes on a fixed NodePort that
# the backend-api Kubernetes Service exposes (k8s/service.yaml):
#
#   CloudFront /api/* -> ALB :80 -> node :30080 -> pod :8080
#
# Only CloudFront can reach the ALB: the security group allows the
# CloudFront origin-facing prefix list, and the listener only forwards
# requests that carry the secret X-Origin-Verify header set by CloudFront.

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  # Managed node groups without a launch template use the cluster security group.
  node_security_group_id = aws_eks_cluster.starttech.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group" "alb" {
  name        = "starttech-alb-sg"
  description = "Backend ALB: HTTP from CloudFront only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "starttech-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront origin-facing servers"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Backend NodePort on EKS worker nodes"
  referenced_security_group_id = local.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_node_port
  to_port                      = var.backend_node_port
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  security_group_id            = local.node_security_group_id
  description                  = "Backend NodePort from the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_node_port
  to_port                      = var.backend_node_port
}

resource "aws_lb" "backend" {
  name               = "starttech-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  idle_timeout               = 60

  tags = {
    Name = "starttech-backend-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name                 = "starttech-backend-tg"
  port                 = var.backend_node_port
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "starttech-backend-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  # Anything that did not come through CloudFront is rejected.
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"forbidden\"}"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [var.origin_verify_secret]
    }
  }
}

# Register every node of the managed node group with the target group.
resource "aws_autoscaling_attachment" "backend_nodes" {
  autoscaling_group_name = aws_eks_node_group.starttech_node_group.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.backend.arn
}
