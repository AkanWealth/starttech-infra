# External ALB for the backend (CloudFront origin "ALB-Backend").
# It forwards to the backend-api NodePort (k8s/service.yaml) on the worker nodes:
#   CloudFront /api/* -> ALB :80 -> node :30080 -> pod :8080

locals {
  # Managed node groups without a launch template use the cluster security group.
  node_security_group_id = aws_eks_cluster.starttech.vpc_config[0].cluster_security_group_id
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name   = "starttech-alb-sg"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = local.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_node_port
  to_port                      = var.backend_node_port
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  security_group_id            = local.node_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_node_port
  to_port                      = var.backend_node_port
}

resource "aws_lb" "backend" {
  name               = "starttech-backend-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "backend" {
  name        = "starttech-backend-tg"
  port        = var.backend_node_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Register the node group's instances with the target group.
resource "aws_autoscaling_attachment" "backend_nodes" {
  autoscaling_group_name = aws_eks_node_group.starttech_node_group.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.backend.arn
}
