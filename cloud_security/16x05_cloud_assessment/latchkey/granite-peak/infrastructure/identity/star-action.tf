# star-action
# Managed by Terraform. Do not edit by hand.

resource "aws_iam_policy" "break_glass" {
  name = "gp-break-glass"
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "*", Resource = "*",
    Condition = { StringEquals = { "aws:PrincipalTag/break-glass" = "approved" } } }] })
}
