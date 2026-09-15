resource "aws_s3_bucket" "terraform_state" {
  bucket = "toggle-terraform-state-fiap"

  object_lock_enabled = true

  tags = {
    Name        = "toggle-terraform-state-fiap"
    Environment = "development"
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}