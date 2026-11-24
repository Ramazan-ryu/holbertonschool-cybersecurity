# vpc-subnet-10
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_10" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.10.0.0/24"
  tags = { tier = "application" }
}
