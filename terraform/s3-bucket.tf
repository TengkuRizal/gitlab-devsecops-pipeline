resource "aws_s3_bucket" "data_bucket" {
  bucket = "demo-data-bucket"
}

resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = false  # ISSUE: should be true
  block_public_policy     = false  # ISSUE: should be true
  ignore_public_acls      = false  # ISSUE: should be true
  restrict_public_buckets = false  # ISSUE: should be true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}