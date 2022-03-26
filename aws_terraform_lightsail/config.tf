provider "aws" {
  region  = var.regions[var.selected_country]
  profile = var.aws_profile
}
