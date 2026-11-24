# bucket-12
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b12" {
  bucket = "gp-data-12"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b12" {
  bucket = aws_s3_bucket.b12.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
