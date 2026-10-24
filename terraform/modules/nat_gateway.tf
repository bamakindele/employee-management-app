# Creates an Elastic IP and one NAT Gateway in the first public subnet.

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "learning-eks-nat-eip"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "learning-eks-nat"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}
