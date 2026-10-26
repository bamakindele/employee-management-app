# Creates separate image repositories for the frontend and backend.
# Keep repository names configurable if this configuration is reused across projects.
resource "aws_ecr_repository" "frontend" {

  name = "frontend"
}

resource "aws_ecr_repository" "backend" {

  name = "backend"
}