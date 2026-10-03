#  Healthcheck App ECR Repository
resource "aws_ecr_repository" "healthcheck_app" {
  name         = "healthcheck-app"
  force_delete = true

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}