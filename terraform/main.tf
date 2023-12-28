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


resource "kubernetes_secret" "k8slabsa" {
  metadata {
    name      = "k8slabsa"
    namespace = local.name_all
    annotations = {
      "kubernetes.io/service-account.name" = local.name_all
    }
  }
  type = "kubernetes.io/service-account-token"
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

resource "random_password" "dbpass" {
  length  = 8
  special = false
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name_all
  description = "PostgreSQL security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]
  tags = {
    Name        = local.name_all
    Owner       = "przem"
    Environment = "dev"
    App         = "k8slab"
  }
}


module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.3.0"

  identifier = local.name_all

  engine               = "postgres"
  engine_version       = "14"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.small"

  allocated_storage = 10
  storage_type      = "gp2"

  db_name  = local.name_all
  username = local.name_all
  password = resource.random_password.dbpass.result

  manage_master_user_password = false
  port                        = 5432

  multi_az = false
  #db_subnet_group_name   = module.vpc.database_subnet_group
  #vpc_security_group_ids = [module.security_group.security_group_id]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [module.security_group.security_group_id]


  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false


  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  tags = {
    Owner       = "przem"
    Environment = "dev"
    App         = local.name_all
  }

}

resource "kubernetes_secret" "k8sdb" {
  metadata {
    name      = local.name_all
    namespace = local.name_all
  }

  data = {
    POSTGRES_URL    = module.db.db_instance_endpoint
    POSTGRES_PASS   = resource.random_password.dbpass.result
    POSTGRES_DBNAME = local.name_all
    POSTGRES_USER   = local.name_all
  }
}

data "template_file" "kubeconfig" {
  template = file(format("%s/kubeconfig.tpl", path.module))
  vars = {
    name                   = local.name_all
    token                  = resource.kubernetes_secret.k8slabsa.data.token
    host                   = module.eks.cluster_endpoint
    cluster_arn            = module.eks.cluster_arn
    cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  }
}

resource "github_actions_secret" "k8slab" {
  repository      = "k8slab"
  secret_name     = "KUBECONFIGTF"
  plaintext_value = data.template_file.kubeconfig.rendered
}
