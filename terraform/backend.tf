terraform {
  backend "s3" {
    bucket         = "tfstate-prz"
    key            = "states/k8slab.tfstate"
    dynamodb_table = "tfstate-prz"
    region         = "eu-west-1"
    encrypt        = true
  }
}