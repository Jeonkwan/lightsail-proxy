provider "aws" {
  region  = var.regions[var.selected_country]
  profile = var.aws_profile
  shared_config_files = [var.aws_conf_file_path]
  shared_credentials_files = [var.aws_cred_file_path]
}
