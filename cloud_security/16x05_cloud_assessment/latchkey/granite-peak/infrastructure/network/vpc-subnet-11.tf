# vpc-subnet-11
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_11" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.11.0.0/24"
  tags = { tier = "application" }
}
