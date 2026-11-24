# vpc-subnet-12
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_12" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.12.0.0/24"
  tags = { tier = "application" }
}
