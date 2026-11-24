# bucket-00
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b0" {
  bucket = "gp-data-00"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b0" {
  bucket = aws_s3_bucket.b0.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
