# grid-telemetry
# Managed by Terraform. Do not edit by hand.

resource "aws_s3_bucket" "grid_telemetry" {
  bucket = "gp-grid-telemetry"
  tags = { data-classification = "operational-restricted" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "grid_telemetry" {
  bucket = aws_s3_bucket.grid_telemetry.id
  rule {
    apply_server_side_encryption_by_default {
      # architecture doc claims a tightly-held CMK; this is the shared platform key,
      # usable by any platform role including gp-telemetry-reader
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/gp-platform-shared"
    }
  }
}
