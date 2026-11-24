# gp-deploy
# Managed by Terraform. Do not edit by hand.

resource "aws_iam_role" "gp_deploy" {
  name = "gp-deploy"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow",
    # architecture doc says the accounts are separated; this trusts the BUILD account CI principal
    Principal = { AWS = "arn:aws:iam::210000000001:role/ci-runner" },
    Action = "sts:AssumeRole" }] })
}
