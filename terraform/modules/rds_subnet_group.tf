# Groups private subnets for database placement across availability zones.
# Reuse this group by referencing its name from database instances.
resource "aws_db_subnet_group" "main" {

  name = "postgres-subnets"

  subnet_ids = [

    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}