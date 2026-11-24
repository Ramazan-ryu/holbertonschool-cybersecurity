# bucket-01
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b1" {
  bucket = "gp-data-01"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b1" {
  bucket = aws_s3_bucket.b1.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
