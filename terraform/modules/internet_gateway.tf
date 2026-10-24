# Creates the Internet Gateway and attaches it to the VPC.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "learning-eks-igw"
  }
}
