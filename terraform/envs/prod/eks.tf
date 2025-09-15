module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"


  cluster_name    = local.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Public API
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  
  enable_cluster_creator_admin_permissions = true

  # Core addons
  cluster_addons = {
    vpc-cni    = { most_recent = true }
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
  }

  # 
  eks_managed_node_groups = {
    ng1 = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 2		

      subnet_ids = module.vpc.public_subnets
      disk_size  = 20

      #
      ami_type = "AL2023_x86_64_STANDARD"
    }
  }
}
