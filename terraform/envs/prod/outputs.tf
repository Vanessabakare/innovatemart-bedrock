output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_ca"       { value = module.eks.cluster_certificate_authority_data }

output "vpc_id"             { value = module.vpc.vpc_id }
output "public_subnet_ids"  { value = module.vpc.public_subnets }
output "private_subnet_ids" { value = module.vpc.private_subnets }

