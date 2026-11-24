# sg-app-03
# Managed by Terraform. Do not edit by hand.

resource "aws_security_group" "app_3" {
  name = "gp-app-3"
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["10.0.0.0/8"] }
}
