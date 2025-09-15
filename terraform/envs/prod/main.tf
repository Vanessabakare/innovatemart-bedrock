locals {
  cluster_name = "innovatemart-eks"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "innovatemart-vpc"
  cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = [
    "10.0.0.0/24",
    "10.0.1.0/24"
  ]

  private_subnets = [
    "10.0.2.0/24",
    "10.0.3.0/24"
  ] 

  map_public_ip_on_launch = true

  enable_nat_gateway = false
  create_igw         = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}
