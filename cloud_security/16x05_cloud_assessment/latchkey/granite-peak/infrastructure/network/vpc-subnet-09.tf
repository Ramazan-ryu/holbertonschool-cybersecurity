# vpc-subnet-09
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_09" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.9.0.0/24"
  tags = { tier = "application" }
}
