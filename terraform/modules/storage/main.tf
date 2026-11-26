data "aws_caller_identity" "current" {}

# Private bucket for the React build, served only through CloudFront (OAC).
resource "aws_s3_bucket" "frontend" {
  # Bucket names are global; the account ID keeps this one unique.
  bucket        = "starttech-frontend-bucket-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "backend" {
  name         = "starttech-backend-api"
  force_delete = true
}
