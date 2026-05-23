# ---------------------------------------------------------------------------
# Random suffix — guarantees a globally unique bucket name
# ---------------------------------------------------------------------------

resource "random_id" "bucket_suffix" {
  byte_length = 4 # produces an 8-character hex string
}

# ---------------------------------------------------------------------------
# KMS key (optional — only created when kms_key_arn variable is not provided)
# ---------------------------------------------------------------------------

resource "aws_kms_key" "s3" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS key for S3 bucket ${local.bucket_name} encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy[0].json

  tags = {
    Name = "${local.bucket_name}-kms-key"
  }
}

resource "aws_kms_alias" "s3" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${local.bucket_name}"
  target_key_id = aws_kms_key.s3[0].key_id
}

# ---------------------------------------------------------------------------
# S3 bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "uploads" {
  bucket = local.bucket_name

  # Prevent accidental destruction via CLI or automation.
  # Set to false temporarily if you truly need to destroy this bucket.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = local.bucket_name
  }
}

# ---------------------------------------------------------------------------
# Public access block — all four flags hardened to true
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Bucket ownership controls
# Ensures ACLs are disabled; bucket owner has full control over all objects.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_ownership_controls" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }

  # Versioning must be enabled before lifecycle rules referencing
  # noncurrent versions can take effect.
  depends_on = [aws_s3_bucket.uploads]
}

# ---------------------------------------------------------------------------
# Server-side encryption — KMS with bucket keys enabled (cost-effective)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }

    # Bucket keys reduce the number of KMS API calls (and therefore cost)
    # by generating a short-lived data key per bucket rather than per object.
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------
# Lifecycle configuration
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  # Lifecycle rules with NoncurrentVersion actions require versioning first.
  depends_on = [aws_s3_bucket_versioning.uploads]

  # --- Rule 1: Tier current objects to cheaper storage over time ---
  rule {
    id     = "tiered-storage-transition"
    status = "Enabled"

    filter {
      prefix = "" # applies to all objects
    }

    transition {
      days          = var.transition_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.transition_glacier_days
      storage_class = "GLACIER_IR" # Glacier Instant Retrieval — ms access times
    }

    dynamic "expiration" {
      for_each = var.expire_objects_days > 0 ? [1] : []
      content {
        days = var.expire_objects_days
      }
    }
  }

  # --- Rule 2: Expire non-current (old) versions after 90 days ---
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    # Keep at most 3 noncurrent versions per object
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  # --- Rule 3: Clean up incomplete multipart uploads ---
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_days
    }
  }

  # --- Rule 4: Remove expired object delete markers (housekeeping) ---
  rule {
    id     = "remove-expired-delete-markers"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      expired_object_delete_marker = true
    }
  }
}

# ---------------------------------------------------------------------------
# Bucket policy — enforce TLS and restrict access to allowed principals
# ---------------------------------------------------------------------------

# The policy must be applied after the public access block; otherwise AWS
# may reject policy statements that would otherwise allow public access.
resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.uploads]
}
