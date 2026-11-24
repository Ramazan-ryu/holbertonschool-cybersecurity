# bucket-09
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b9" {
  bucket = "gp-data-09"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b9" {
  bucket = aws_s3_bucket.b9.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
