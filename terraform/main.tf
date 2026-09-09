terraform {
  backend "s3" {
    bucket = "ecs-project-terraform-state-478078664193"
    key    = "ecs-project/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "networking" {
  source = "./modules/networking"
}

resource "aws_route53_zone" "main" {
  name = "legendarymovesclothing.com"
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "tm"
  type    = "A"

  alias {
    name                   = module.application.alb_dns_name
    zone_id                = module.application.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "app" {
  domain_name       = "tm.legendarymovesclothing.com"
  validation_method = "DNS"

  tags = {
    Name = "tm.legendarymovesclothing.com"
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.networking.aws_internet_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.networking.aws_route_table.public
}

moved {
  from = aws_subnet.public_a
  to   = module.networking.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.networking.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.networking.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_b
  to   = module.networking.aws_subnet.private_b
}

moved {
  from = aws_route_table.private
  to   = module.networking.aws_route_table.private
}

moved {
  from = aws_eip.nat
  to   = module.networking.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.networking.aws_nat_gateway.main
}

moved {
  from = aws_route.private_to_nat
  to   = module.networking.aws_route.private_to_nat
}

moved {
  from = aws_route_table_association.public_a
  to   = module.networking.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.networking.aws_route_table_association.public_b
}

moved {
  from = aws_security_group.alb
  to   = module.application.aws_security_group.alb
}

moved {
  from = aws_security_group.ecs
  to   = module.application.aws_security_group.ecs
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_to_ecs
  to   = module.application.aws_vpc_security_group_egress_rule.alb_to_ecs
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.application.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = module.application.aws_vpc_security_group_ingress_rule.alb_https
}

moved {
  from = aws_vpc_security_group_ingress_rule.ecs_from_alb
  to   = module.application.aws_vpc_security_group_ingress_rule.ecs_from_alb
}

moved {
  from = aws_vpc_security_group_egress_rule.ecs_to_internet
  to   = module.application.aws_vpc_security_group_egress_rule.ecs_to_internet
}

moved {
  from = aws_ecs_cluster.main
  to   = module.application.aws_ecs_cluster.main
}

moved {
  from = aws_ecs_task_definition.app
  to   = module.application.aws_ecs_task_definition.app
}

moved {
  from = aws_lb_target_group.app
  to   = module.application.aws_lb_target_group.app
}

moved {
  from = aws_lb.app
  to   = module.application.aws_lb.app
}

moved {
  from = aws_lb_listener.http
  to   = module.application.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.application.aws_lb_listener.https
}

moved {
  from = aws_ecs_service.app
  to   = module.application.aws_ecs_service.app
}

moved {
  from = aws_route_table_association.private_a
  to   = module.networking.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_b
  to   = module.networking.aws_route_table_association.private_b
}

module "application" {
  source = "./modules/application"

  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  certificate_arn    = aws_acm_certificate.app.arn
  image_tag = var.image_tag
}