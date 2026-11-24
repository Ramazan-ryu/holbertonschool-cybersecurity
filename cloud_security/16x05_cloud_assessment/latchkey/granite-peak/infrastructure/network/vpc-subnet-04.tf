# vpc-subnet-04
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_04" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.4.0.0/24"
  tags = { tier = "application" }
}
