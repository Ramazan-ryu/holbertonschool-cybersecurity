# role-06
# Managed by Terraform. Do not edit by hand.

resource "aws_iam_role" "svc_6" {
  name = "gp-svc-06"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
