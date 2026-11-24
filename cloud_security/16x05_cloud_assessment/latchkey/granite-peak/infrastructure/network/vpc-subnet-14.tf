# vpc-subnet-14
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_14" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.14.0.0/24"
  tags = { tier = "application" }
}
