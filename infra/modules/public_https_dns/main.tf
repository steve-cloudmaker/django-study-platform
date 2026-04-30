locals {
  api_fqdn     = "${var.api_subdomain}.${var.public_dns_domain}"
  app_fqdn     = "${var.app_subdomain}.${var.public_dns_domain}"
  grafana_fqdn = "${var.grafana_subdomain}.${var.public_dns_domain}"
}

data "aws_route53_zone" "public" {
  count        = var.public_hosted_zone_id == "" ? 1 : 0
  name         = "${var.public_dns_domain}."
  private_zone = false
}

locals {
  route53_zone_id = var.public_hosted_zone_id != "" ? var.public_hosted_zone_id : data.aws_route53_zone.public[0].zone_id
}

resource "aws_acm_certificate" "ingress" {
  domain_name               = "*.${var.public_dns_domain}"
  subject_alternative_names = [var.public_dns_domain]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "wildcard-${var.public_dns_domain}"
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ingress.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

resource "aws_acm_certificate_validation" "ingress" {
  certificate_arn           = aws_acm_certificate.ingress.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

data "aws_lb" "api" {
  count = var.create_route53_alb_aliases ? 1 : 0
  name  = var.api_alb_name
}

data "aws_lb" "frontend" {
  count = var.create_route53_alb_aliases ? 1 : 0
  name  = var.frontend_alb_name
}

data "aws_lb" "grafana" {
  count = var.create_route53_alb_aliases ? 1 : 0
  name  = var.grafana_alb_name
}

resource "aws_route53_record" "api_a" {
  count   = var.create_route53_alb_aliases ? 1 : 0
  zone_id = local.route53_zone_id
  name    = local.api_fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.api[0].dns_name
    zone_id                = data.aws_lb.api[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_a" {
  count   = var.create_route53_alb_aliases ? 1 : 0
  zone_id = local.route53_zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.frontend[0].dns_name
    zone_id                = data.aws_lb.frontend[0].zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana_a" {
  count   = var.create_route53_alb_aliases ? 1 : 0
  zone_id = local.route53_zone_id
  name    = local.grafana_fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.grafana[0].dns_name
    zone_id                = data.aws_lb.grafana[0].zone_id
    evaluate_target_health = true
  }
}
