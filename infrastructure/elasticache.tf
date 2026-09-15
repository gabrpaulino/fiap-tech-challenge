resource "aws_security_group" "toggle_master_cache_sg" {
  name = "toggle-master-cache-sg"
  description = "Security group for ElastiCache cluster"
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 6379
        to_port     = 6379
        protocol    = "tcp"
    }
    egress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 0
        to_port     = 0
        protocol    = "-1"  
    }
}

resource "aws_elasticache_cluster" "elasticache_clusters" {
    cluster_id = "toggle-master-cache"
    node_type = "cache.t4g.micro"
    num_cache_nodes = 1
    engine = "redis"
    engine_version = "6.2"
    security_group_ids = [aws_security_group.toggle_master_cache_sg.id]
    
}