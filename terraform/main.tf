provider "aws" {
  region = "eu-west-1"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", "k8slab"]
  }
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
    App         = "k8slab"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.4"

  cluster_name    = "k8slab"
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  tags = {
    Name        = "k8slab"
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

resource "kubernetes_namespace" "k8s" {
  metadata {
    name = "k8slab"
  }
}

resource "kubernetes_service_account" "admin" {
  metadata {
    name      = "admin"
    namespace = "k8slab"
  }
}

resource "kubernetes_role" "k8slab" {
  metadata {
    name      = "k8slab"
    namespace = "k8slab"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "k8slab" {
  metadata {
    name      = "k8slab"
    namespace = "k8slab"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "k8slab"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "admin"
    namespace = "k8slab"
  }
}