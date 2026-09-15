resource "aws_dynamodb_table" "toggle_master_analytics" {
  name           = "ToggleMasterAnalytics"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }
}