# vpc-subnet-03
# Managed by Terraform. Do not edit by hand.

resource "aws_subnet" "vpc_subnet_03" {
  vpc_id     = "vpc-gp-prod"
  cidr_block = "10.3.0.0/24"
  tags = { tier = "analytics" }
}
