# public-grid-data
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "public_grid_data" {
  bucket = "granite-peak-public-grid-data"
}

resource "aws_s3_bucket_policy" "public_grid_data" {
  bucket = aws_s3_bucket.public_grid_data.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Deny", Principal = "*", Action = "s3:*", Resource = "*",
    Condition = { StringNotEquals = { "aws:SourceVpce" = "vpce-gp-prod" } } }] })
}
