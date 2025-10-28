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
  description = "Namecheap Dynamic DNS password (ignored when proxy_solution = \"less-vision-reality\")."
  sensitive = true
}

variable "proxy_server_uuid" {
  type        = string
  sensitive   = true
  description = "UUID shared by proxy solutions (Trojan-Go treats it as the password)."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", trimspace(var.proxy_server_uuid)))
    error_message = "proxy_server_uuid must be a non-empty UUID in the form xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
  }
}

variable "proxy_solution" {
  type        = string
  description = "Proxy solution to deploy. Supported values: trojan-go, less-vision, less-vision-reality."
  default     = "trojan-go"

  validation {
    condition     = contains(["trojan-go", "less-vision", "less-vision-reality"], var.proxy_solution)
    error_message = "proxy_solution must be one of \"trojan-go\", \"less-vision\", or \"less-vision-reality\"."
  }
}

variable "proxy_contact_email" {
  type        = string
  description = "Email address used by solutions that integrate with certificate authorities (required for less-vision)."
  default     = ""
}

variable "less_vision_reality_short_ids" {
  type        = list(string)
  description = "Comma-separated Reality short IDs consumed by the less-vision-reality playbook (required when selected)."
  default     = []
}

variable "less_vision_reality_private_key" {
  type        = string
  description = "Base64-encoded Reality private key used by the less-vision-reality playbook (required when selected)."
  default     = ""
  sensitive   = true
}

variable "less_vision_reality_public_key" {
  type        = string
  description = "Base64-encoded Reality public key used by the less-vision-reality playbook (required when selected)."
  default     = ""
  sensitive   = true
}

variable "less_vision_reality_decoy_domain" {
  type        = string
  description = "Optional decoy domain (Reality SNI) forwarded to the less-vision-reality playbook."
  default     = "web.wechat.com"
}

variable "playbook_branch" {
  type    = string
  default = "main"
}
