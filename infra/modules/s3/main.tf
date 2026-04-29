resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_id = lower("${var.bucket_name_prefix}-${random_id.suffix.hex}")
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_id
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
