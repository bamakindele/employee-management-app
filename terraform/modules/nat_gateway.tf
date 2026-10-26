# Creates an Elastic IP and one NAT Gateway in the first public subnet.
# A single gateway is shared by the private route table; additional AZs may need their own for resilience.

resource "aws_eip" "nat" {

  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.igw
  ]
}