# vpc-subnet-17
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_17" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.17.0.0/24"
  tags = { tier = "application" }
}
