# MVP stack: VPC, EKS (managed nodes), RDS, S3, SQS+DLQ, IRSA for api/worker/AWS LB Controller.
#
# ALB: after apply, install the AWS Load Balancer Controller and use IngressClass "alb".
#   helm repo add eks https://aws.github.io/eks-charts
#   helm repo update
#   helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
#     --set clusterName=$(terraform output -raw cluster_name) \
#     --set serviceAccount.create=true \
#     --set serviceAccount.name=aws-load-balancer-controller \
#     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw alb_controller_role_arn) \
#     --set region=$(terraform output -raw aws_region) \
#     --set vpcId=$(terraform output -raw vpc_id)
#
# Then create an Ingress with ingressClassName: alb (and appropriate annotations).

locals {
  name           = "${var.project}-${var.environment}"
  cluster_name   = "${local.name}-eks"
  rds_identifier = "${replace(local.name, "_", "-")}-postgres"
}

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cidr         = var.vpc_cidr
  cluster_name = local.cluster_name
  tags = {
    Name = "${local.name}-vpc"
  }
}

module "s3_submissions" {
  source = "../../modules/s3"

  bucket_name_prefix = "${local.name}-submissions"
  tags = {
    Name = "${local.name}-submissions"
  }
}

module "sqs_submissions" {
  source = "../../modules/sqs"

  name_prefix = local.name
  tags = {
    Name = "${local.name}-sqs"
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_types = var.eks_node_instance_types
  node_min_size       = var.eks_node_min_size
  node_max_size       = var.eks_node_max_size
  node_desired_size   = var.eks_node_desired_size

  cluster_enabled_log_types            = var.eks_control_plane_log_types
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  tags = {
    Name = local.cluster_name
  }
}

module "rds" {
  source = "../../modules/rds"

  identifier                 = local.rds_identifier
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
  instance_class             = var.rds_instance_class

  tags = {
    Name = local.rds_identifier
  }
}

module "iam_irsa" {
  source = "../../modules/iam"

  name_prefix             = local.name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.eks.oidc_provider_arn
  s3_bucket_arn           = module.s3_submissions.bucket_arn
  sqs_queue_arn           = module.sqs_submissions.queue_arn

  tags = {
    Name = "${local.name}-irsa"
  }
}

module "public_https" {
  count  = var.public_dns_domain != "" ? 1 : 0
  source = "../../modules/public_https_dns"

  public_dns_domain            = var.public_dns_domain
  api_alb_name                 = var.public_https_api_alb_name
  frontend_alb_name            = var.public_https_frontend_alb_name
  grafana_alb_name             = var.public_https_grafana_alb_name
  create_route53_alb_aliases   = var.create_route53_alb_aliases

  tags = {
    Name = "${local.name}-public-https"
  }
}
