# vpc-subnet-05
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_05" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.5.0.0/24"
  tags = { tier = "application" }
}
