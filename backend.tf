# ---------------------------------------------------------------------------
# Remote state backend
#
# Prerequisites (create once, before running terraform init):
#   aws s3api create-bucket --bucket <state_bucket> --region <region>
#   aws s3api put-bucket-versioning --bucket <state_bucket> \
#     --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name <lock_table> \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region <region>
#
# Replace the placeholder values below with your actual state bucket name,
# DynamoDB table name, and region before running `terraform init`.
# ---------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "my-tfstate-bucket-REPLACE_ME"
    key            = "app-uploads/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-REPLACE_ME"
  }
}
