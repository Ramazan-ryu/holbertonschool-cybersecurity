# kms
# Managed by Terraform. Do not edit by hand.

resource "aws_kms_key" "platform_shared" {
  description = "gp-platform-shared"
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Principal = { AWS = "arn:aws:iam::210000000002:root" },
    Action = ["kms:Decrypt","kms:GenerateDataKey"], Resource = "*" }] })
}
