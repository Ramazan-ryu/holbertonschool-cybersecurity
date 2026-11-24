# bucket-02
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "b2" {
  bucket = "gp-data-02"
  tags = { data-classification = "non-sensitive" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "b2" {
  bucket = aws_s3_bucket.b2.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
