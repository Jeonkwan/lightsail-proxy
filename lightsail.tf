locals {
  instance_name = "${var.instance_name_prefix}-${var.selected_country}-${var.zones[var.selected_zone]}-${var.instance_customizable_name}"
}

resource "aws_lightsail_static_ip_attachment" "lightsail_instance_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.instance_ip.id
  instance_name  =  aws_lightsail_instance.lightsail_instance.id
}

resource "aws_lightsail_static_ip" "instance_ip" {
  name = "${local.instance_name}-ip"
}

resource "aws_lightsail_key_pair" "ssh" {
  name       = "key-${local.instance_name}"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_lightsail_instance" "lightsail_instance" {
# introducing random_id to create unique instance names, this can keep IP address when apply again but rotate the whole machine, then SSL certificates will be renewed at new instance startup
  name              = "${local.instance_name}-${random_id.instance_suffix.hex}"
  availability_zone = "${var.regions[var.selected_country]}${var.zones[var.selected_zone]}"
  blueprint_id      = var.machine_config["os"]
  bundle_id         = var.machine_config["instance_type"]
  key_pair_name     = aws_lightsail_key_pair.ssh.name
  user_data         = templatefile(
    "${path.root}/setup_ubuntu.sh.tftpl",
    {
      username = var.machine_config["nonroot_username"],
      domain_name = var.domain_name,
      subdomain_name = var.subdomain_name,
      public_ip = aws_lightsail_static_ip.instance_ip.ip_address,
      namecheap_ddns_password = var.namecheap_ddns_password,
      trojan_go_password = var.trojan_go_password
      playbook_branch = var.playbook_branch
    }
  )

  # connection {
  #   type = "ssh"
  #   user = var.machine_config["nonroot_username"]
  #   private_key = file(var.ssh_private_key_path)
  #   host = aws_lightsail_instance.lightsail_instance.public_ip_address
  #   target_platform = "unix"
  #   port = 22
  # }

  # provisioner "local-exec" {
  #   command = "ANSIBLE_SSH_RETRIES=5 ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.machine_config["nonroot_username"]} -i '${aws_lightsail_instance.lightsail_instance.public_ip_address},' --private-key ${var.ssh_private_key_path} --extra-vars 'username=${var.machine_config["nonroot_username"]} domain_name=${var.domain_name} subdomain_name=${var.subdomain_name} public_ip=${aws_lightsail_static_ip.instance_ip.ip_address} namecheap_ddns_password=${var.namecheap_ddns_password} trojan_go_password=${var.trojan_go_password}' setup_env.yaml"
  # }
}

resource "aws_lightsail_instance_public_ports" "proxy" {
  instance_name = aws_lightsail_instance.lightsail_instance.name

  port_info {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
  }
  port_info {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
  }
  port_info {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
  }
  port_info {
    protocol    = "udp"
    from_port   = 60000
    to_port     = 60010
  }
  port_info {
    protocol    = "tcp"
    from_port   = 8990
    to_port     = 8990
  }
  port_info {
    protocol    = "udp"
    from_port   = 8990
    to_port     = 8990
  }
}

resource "random_id" "instance_suffix" {
  byte_length = 4
}

