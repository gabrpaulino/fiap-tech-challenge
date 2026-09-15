locals {
    ecr_repository_name = [
        "analytics-service",
        "auth-service",
        "flag-service",
        "targeting-service",
        "evaluation-service"
    ]
}

resource "aws_ecr_repository" "ecr_repositories" {
    for_each = toset(local.ecr_repository_name)
    name     = each.value
}