terraform {
  backend "s3" {
    bucket       = "asset-monitoring-platform-tfstate-1c230009"
    key          = "dev/asset-monitoring-platform/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}