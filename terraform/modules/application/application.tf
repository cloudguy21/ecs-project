resource "aws_security_group" "alb" {
  name   = "ecs-project-alb-sg"
  vpc_id = var.vpc_id

  tags = {
    Name = "ecs-project-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  name   = "ecs-project-ecs-sg"
  vpc_id = var.vpc_id

  tags = {
    Name = "ecs-project-ecs-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs.id

  from_port   = 8000
  to_port     = 8000
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id

  from_port   = 8000
  to_port     = 8000
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_internet" {

  security_group_id = aws_security_group.ecs.id

  description = "Allow ECS to reach AWS services"

  cidr_ipv4   = "0.0.0.0/0"

  from_port   = 443

  to_port     = 443

  ip_protocol = "tcp"
}

resource "aws_ecs_cluster" "main" {
  name = "ecs-project-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "ecs-project"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = data.aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "ecs-project"
      image     = "${data.aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

data "aws_ecr_repository" "app" {
  name = "ecs-project"
}

data "aws_iam_role" "ecs_task_execution" {
  name = "ecs-project-task-execution-role"
}

resource "aws_lb_target_group" "app" {
  name        = "ecs-project-tg-new"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "app" {
  name               = "ecs-project-alb-new"
  load_balancer_type = "application"
  internal           = false

  subnets = var.public_subnet_ids

  security_groups = [aws_security_group.alb.id]

  tags = {
    Name = "ecs-project-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy = "ELBSecurityPolicy-2016-08"

  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_service" "app" {
  name            = "ecs-project-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets = var.private_subnet_ids

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "ecs-project"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60
}