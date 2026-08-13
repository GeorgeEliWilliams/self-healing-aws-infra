terraform {
  backend "s3" {
    bucket       = "george-williams-tfstate-851725234293"
    key          = "project1-self-healing-infra/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}