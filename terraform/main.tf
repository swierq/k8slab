locals {
  name_all = "k8slab"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"

  name = "k8slab"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Owner       = "przem"
    Environment = "dev"
    App         = local.name_all
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.4"

  cluster_name    = local.name_all
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  tags = {
    Name        = local.name_all
    Owner       = "przem"
    Environment = "dev"
    App         = "k8slab"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}

module "alb-ingress-controller" {
  source       = "campaand/alb-ingress-controller/aws"
  version      = "2.0.0"
  cluster_name = module.eks.cluster_name
  depends_on = [
    module.eks
  ]
}


resource "kubernetes_namespace" "k8s" {
  metadata {
    name = local.name_all
  }
}

# will use it in in gh actions
resource "kubernetes_service_account" "k8slab" {
  metadata {
    name      = local.name_all
    namespace = local.name_all
  }
}

resource "kubernetes_role" "k8slab" {
  metadata {
    name      = local.name_all
    namespace = local.name_all
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "k8slab" {
  metadata {
    name      = local.name_all
    namespace = local.name_all
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.k8slab.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.k8slab.metadata[0].name
    namespace = local.name_all
  }
}