variable "aws_profile" {
  type    = string
  default = "default"
}

variable "aws_conf_file_path" {
  type = string
}

variable "aws_cred_file_path" {
  type = string
}

variable "regions" {
  type = map(string)
  default = {
    singapore = "ap-southeast-1"
    japan     = "ap-northeast-1"
    korea     = "ap-northeast-2"
    india     = "ap-south-1"
  }
}

variable "selected_country" {
  type = string
}

variable "zones" {
  type = map(string)
  default = {
    a = "a" # support all
    b = "b" # except japan
    c = "c" # support all
    d = "d" # support only korea, japan
  }
}

variable "selected_zone" {
  type = string
}

variable "instance_name_prefix" {
  default = "lightsail"
}

variable "instance_customizable_name" {
  type = string
}

variable "machine_config" {
  type = map(string)
  default = {
    os               = "ubuntu_24_04"
    nonroot_username = "ubuntu"
    instance_type    = "nano_2_0" # india uses nano_2_1 instead
  }
}

variable "ssh_public_key_path" {
  type        = string
  description = "your ssh public key for importing to lightsail"
}

variable "ssh_private_key_path" {
  type        = string
  description = "your ssh private key for connecting to lightsail vm after deployment"
}

variable "domain_name" {
  type = string
}

variable "subdomain_name" {
  type = string
}

variable "namecheap_ddns_password" {
  type      = string
  sensitive = true
}

variable "trojan_go_password" {
  type      = string
  sensitive = true
}

variable "playbook_branch" {
  type    = string
  default = "main"
}
