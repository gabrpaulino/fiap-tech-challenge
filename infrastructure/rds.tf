locals {
    rds_instance_identifier = [
        "flags_db",
        "auth_db",
        "targeting_db"
    ]
}

resource "aws_db_subnet_group" "rds_subnet_group" {
    name       = "toggle-master-subnet-group"
    subnet_ids = [
        "subnet-0c3594913da58cd67",
        "subnet-093bd91c0478499e7",
        "subnet-0154bab04d15b3b44"
        ]
}

resource "aws_security_group" "rds_security_group" {
  name        = "toggle-master-security-group"
  description = "Security group for RDS instances"
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds_instances" {
    for_each = toset(local.rds_instance_identifier)
    identifier = replace(each.value, "_db", "")
    allocated_storage = 20
    engine = "postgres"
    engine_version = "16.10"
    instance_class = "db.t4g.micro"
    username = "postgres"
    password = "postgres"
    db_name = each.value
    skip_final_snapshot = true
    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_security_group.id]
}