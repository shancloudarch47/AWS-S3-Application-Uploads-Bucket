output "bucket_id" {
  description = "The S3 bucket name / ID."
  value       = aws_s3_bucket.uploads.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.uploads.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket (e.g. for CloudFront origins or pre-signed URL construction)."
  value       = aws_s3_bucket.uploads.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region in which the bucket was created."
  value       = aws_s3_bucket.uploads.region
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for bucket encryption."
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the managed KMS key (null if an external key ARN was provided)."
  value       = var.kms_key_arn == "" ? aws_kms_key.s3[0].key_id : null
}
