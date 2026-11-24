# sg-app-05
# Managed by Terraform. Do not edit by hand.

resource "aws_security_group" "app_5" {
  name = "gp-app-5"
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["10.0.0.0/8"] }
}
