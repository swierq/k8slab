terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.25.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }

  }
  required_version = "~> 1.5.7"
}