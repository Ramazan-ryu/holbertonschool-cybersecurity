# route-analytics
# Managed by Terraform. Do not edit by hand.

resource "aws_route" "analytics_from_app" {
  route_table_id         = "rtb-app"
  destination_cidr_block = "10.3.0.0/24"   # analytics subnet
  vpc_peering_connection_id = "pcx-app-analytics"
}
