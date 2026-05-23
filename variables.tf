# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region in which all resources will be created."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier (e.g. us-east-1)."
  }
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "team" {
  description = "Owning team — used for resource tagging."
  type        = string
}

variable "project" {
  description = "Project name — used for resource tagging and bucket name prefix."
  type        = string
}

# ---------------------------------------------------------------------------
# Bucket
# ---------------------------------------------------------------------------

variable "bucket_name_prefix" {
  description = "Prefix for the S3 bucket name. A random suffix is appended to ensure global uniqueness."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,37}$", var.bucket_name_prefix))
    error_message = "bucket_name_prefix must be 3–37 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 server-side encryption. If empty, a new KMS key is created."
  type        = string
  default     = ""
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

variable "transition_ia_days" {
  description = "Number of days before objects transition to S3 Standard-IA."
  type        = number
  default     = 30

  validation {
    condition     = var.transition_ia_days >= 30
    error_message = "S3 Standard-IA requires a minimum of 30 days."
  }
}

variable "transition_glacier_days" {
  description = "Number of days before objects transition to S3 Glacier Instant Retrieval."
  type        = number
  default     = 90

  validation {
    condition     = var.transition_glacier_days > var.transition_ia_days
    error_message = "transition_glacier_days must be greater than transition_ia_days."
  }
}

variable "expire_objects_days" {
  description = "Number of days before objects are permanently deleted. Set to 0 to disable expiration."
  type        = number
  default     = 0

  validation {
    condition     = var.expire_objects_days == 0 || var.expire_objects_days > var.transition_glacier_days
    error_message = "expire_objects_days must be 0 (disabled) or greater than transition_glacier_days."
  }
}

variable "abort_incomplete_multipart_days" {
  description = "Number of days after which incomplete multipart uploads are aborted."
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------
# Bucket policy — allowed principals
# ---------------------------------------------------------------------------

variable "allowed_principal_arns" {
  description = "List of IAM principal ARNs (roles, users) permitted to read/write the bucket. At least one required."
  type        = list(string)

  validation {
    condition     = length(var.allowed_principal_arns) > 0
    error_message = "allowed_principal_arns must contain at least one IAM principal ARN."
  }
}
