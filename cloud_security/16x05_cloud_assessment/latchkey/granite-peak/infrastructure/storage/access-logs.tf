# access-logs
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "access_logs" {
  bucket = "gp-access-logs"
  tags = { data-classification = "non-sensitive" }
}
