# sg-batch
# Managed by Terraform. Do not edit by hand.

resource "aws_security_group" "batch" {
  name = "gp-batch"
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}
