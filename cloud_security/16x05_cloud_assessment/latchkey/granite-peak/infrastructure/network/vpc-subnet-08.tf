# vpc-subnet-08
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_08" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.8.0.0/24"
  tags = { tier = "application" }
}
