locals {
  oidc_host = replace(var.cluster_oidc_issuer_url, "https://", "")
}

data "aws_iam_policy_document" "assume_irsa" {
  for_each = {
    api = {
      sub = "system:serviceaccount:${var.k8s_namespace}:${var.api_service_account}"
    }
    worker = {
      sub = "system:serviceaccount:${var.k8s_namespace}:${var.worker_service_account}"
    }
    alb_controller = {
      sub = "system:serviceaccount:${var.alb_controller_namespace}:${var.alb_controller_service_account}"
    }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [each.value.sub]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "api_data" {
  source_policy_documents = [data.aws_iam_policy_document.cloudwatch_logs.json]

  statement {
    sid = "S3Submissions"
    actions = [
      "s3:ListBucket",
    ]
    resources = [var.s3_bucket_arn]
  }

  statement {
    sid = "S3Objects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${var.s3_bucket_arn}/*"]
  }

  statement {
    sid = "SqsSend"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [var.sqs_queue_arn]
  }
}

data "aws_iam_policy_document" "worker_data" {
  source_policy_documents = [data.aws_iam_policy_document.cloudwatch_logs.json]

  statement {
    sid = "S3Submissions"
    actions = [
      "s3:ListBucket",
    ]
    resources = [var.s3_bucket_arn]
  }

  statement {
    sid = "S3Objects"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${var.s3_bucket_arn}/*"]
  }

  statement {
    sid = "SqsConsume"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role" "api" {
  name               = "${var.name_prefix}-api-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_irsa["api"].json

  tags = var.tags
}

resource "aws_iam_role_policy" "api" {
  name   = "api-inline"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_data.json
}

resource "aws_iam_role" "worker" {
  name               = "${var.name_prefix}-worker-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_irsa["worker"].json

  tags = var.tags
}

resource "aws_iam_role_policy" "worker" {
  name   = "worker-inline"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_data.json
}

resource "aws_iam_policy" "alb_controller" {
  name_prefix = "${var.name_prefix}-alb-ctrl-"
  policy      = file("${path.module}/policies/alb_controller.json")

  tags = var.tags
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name_prefix}-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_irsa["alb_controller"].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
