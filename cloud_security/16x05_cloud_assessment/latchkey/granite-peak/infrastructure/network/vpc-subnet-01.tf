# vpc-subnet-01
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_01" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.1.0.0/24"
  tags = { tier = "application" }
}
