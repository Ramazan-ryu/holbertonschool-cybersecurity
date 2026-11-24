# vpc-subnet-15
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_15" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.15.0.0/24"
  tags = { tier = "application" }
}
