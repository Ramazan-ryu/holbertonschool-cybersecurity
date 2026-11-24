# bucket-13
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b13" {
  bucket = "gp-data-13"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b13" {
  bucket = aws_s3_bucket.b13.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
