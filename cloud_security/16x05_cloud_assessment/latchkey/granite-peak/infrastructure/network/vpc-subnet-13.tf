# vpc-subnet-13
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_13" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.13.0.0/24"
  tags = { tier = "application" }
}
