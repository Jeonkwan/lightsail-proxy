variable "aws_profile" {
    default = "default"
}

variable "regions" {
    type = map
    default = {
        singapore = "ap-southeast-1"
        japan = "ap-northeast-1"
        korea = "ap-northeast-2"
    }
}

variable "selected_country" {
  type = string
}

variable "zones" {
    type = map
    default = {
        a = "a"
        b = "b"
        c = "c"
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
    type = map
    default = {
        os = "ubuntu_20_04"
        nonroot_username = "ubuntu"
        instance_type = "nano_2_0"
    }
}

variable "ssh_public_key_path" {
    type = string
    description = "your ssh public key for importing to lightsail"
}