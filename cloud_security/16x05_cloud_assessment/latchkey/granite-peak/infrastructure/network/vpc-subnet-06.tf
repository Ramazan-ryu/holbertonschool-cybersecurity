# vpc-subnet-06
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_06" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.6.0.0/24"
  tags = { tier = "application" }
}
