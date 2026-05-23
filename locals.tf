locals {
  # Final bucket name: prefix + 8-char random hex suffix for global uniqueness
  bucket_name = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"

  # Use provided KMS key ARN if given, otherwise use the key created here
  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.s3[0].arn

  # Common tags merged with provider default_tags; kept here for explicit use
  # in resources that don't inherit default_tags (e.g. aws_kms_key policy docs)
  common_tags = {
    Environment = var.environment
    Team        = var.team
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
