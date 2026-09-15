module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "toggle-master"
  kubernetes_version = "1.36"

  endpoint_public_access                   = true
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = aws_vpc.this.id
  subnet_ids = [for subnet in aws_subnet.private : subnet.id if subnet.availability_zone != "us-east-1e"]

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Grupo base para componentes do cluster e aplicações essenciais.
  eks_managed_node_groups = {
    system = {
      name           = "toggle-system"
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "SPOT"
      instance_types = ["t3.medium", "t3a.medium"]

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload = "system"
      }
    }

    workloads = {
      name           = "toggle-workloads"
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "SPOT"
      instance_types = ["t3.medium", "t3a.medium"]

      # Escala sob demanda quando houver Pods Pending por falta de capacidade.
      min_size     = 0
      max_size     = 6
      desired_size = 0

      labels = {
        workload = "application"
      }
    }
  }

  tags = {
    Name        = "toggle-master"
    Environment = "development"
    Terraform   = "true"
  }
}
