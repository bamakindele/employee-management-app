# Creates and attaches the VPC's Internet Gateway for public subnet routing.
# Reuse this gateway through route-table references instead of creating one per subnet.

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}
