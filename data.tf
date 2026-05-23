# Current AWS account and caller identity — used to construct KMS key policies
# and tie the bucket name to the account.
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# KMS key policy document
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms_key_policy" {
  count = var.kms_key_arn == "" ? 1 : 0

  # Root account retains full key administration rights
  statement {
    sid    = "AllowRootAccountKeyAdmin"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow S3 service to use the key for encrypt/decrypt operations
  statement {
    sid    = "AllowS3ServiceUse"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
    ]

    resources = ["*"]
  }

  # Allow explicitly listed principals to use the key via S3
  statement {
    sid    = "AllowAllowedPrincipalsKeyUse"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_principal_arns
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]

    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------
# S3 bucket policy document
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bucket_policy" {
  # Explicitly deny any public or anonymous access
  statement {
    sid    = "DenyPublicAccess"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}/*",
    ]

    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values   = var.allowed_principal_arns
    }
  }

  # Deny any request that is not over TLS
  statement {
    sid    = "DenyNonTLSRequests"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Allow explicitly listed principals full bucket access
  statement {
    sid    = "AllowExplicitPrincipals"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_principal_arns
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}/*",
    ]
  }
}
