locals {
  instance_name                  = "${var.instance_name_prefix}-${var.selected_country}-${var.zones[var.selected_zone]}-${var.instance_customizable_name}"
  proxy_solution_requires_ddns   = contains(["trojan-go", "less-vision"], var.proxy_solution)
}

resource "aws_lightsail_static_ip_attachment" "lightsail_instance_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.instance_ip.id
  instance_name  = aws_lightsail_instance.lightsail_instance.id
}

resource "aws_lightsail_static_ip" "instance_ip" {
  name = "${local.instance_name}-ip"
}

resource "null_resource" "namecheap_dns_update" {
  count      = local.proxy_solution_requires_ddns ? 1 : 0
  depends_on = [aws_lightsail_static_ip.instance_ip]

  triggers = {
    instance_ip = aws_lightsail_static_ip.instance_ip.ip_address
    domain      = var.domain_name
    subdomain   = var.subdomain_name
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/configure_namecheap_dns.sh"
    environment = {
      DOMAIN              = var.domain_name
      SUBDOMAIN           = var.subdomain_name
      INSTANCE_PUBLIC_IP  = aws_lightsail_static_ip.instance_ip.ip_address
      NAMECHEAP_DDNS_PASS = var.namecheap_ddns_password
      NAMECHEAP_DDNS_LOG  = "${path.module}/namecheap_dns_update.log"
    }
  }

  provisioner "local-exec" {
    command = "cat \"${path.module}/namecheap_dns_update.log\" && rm -f \"${path.module}/namecheap_dns_update.log\""
  }
}

resource "aws_lightsail_key_pair" "ssh" {
  name       = "key-${local.instance_name}"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_lightsail_instance" "lightsail_instance" {
  depends_on = [null_resource.namecheap_dns_update]

  # introducing timestamp to create unique instance names, this can keep IP address when apply again but rotate the whole machine, then SSL certificates will be renewed at new instance startup
  name              = "${local.instance_name}-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  availability_zone = "${var.regions[var.selected_country]}${var.zones[var.selected_zone]}"
  blueprint_id      = var.machine_config["os"]
  bundle_id         = var.machine_config["instance_type"]
  key_pair_name     = aws_lightsail_key_pair.ssh.name
  user_data = templatefile(
    "${path.module}/scripts/cloud-init/setup_ubuntu.sh.tftpl",
    {
      username                = var.machine_config["nonroot_username"],
      domain_name             = var.domain_name,
      subdomain_name          = var.subdomain_name,
      public_ip               = aws_lightsail_static_ip.instance_ip.ip_address,
      namecheap_ddns_password = var.namecheap_ddns_password,
      proxy_server_uuid       = var.proxy_server_uuid,
      playbook_branch         = var.playbook_branch,
      proxy_solution          = var.proxy_solution,
      proxy_contact_email     = var.proxy_contact_email,
      less_vision_reality_short_ids = join(",", var.less_vision_reality_short_ids),
      less_vision_reality_private_key = var.less_vision_reality_private_key,
      less_vision_reality_public_key  = var.less_vision_reality_public_key,
      less_vision_reality_decoy_domain = var.less_vision_reality_decoy_domain
    }
  )

  lifecycle {
    precondition {
      condition     = var.proxy_solution != "less-vision" || length(trimspace(var.proxy_contact_email)) > 0
      error_message = "proxy_contact_email must be provided when proxy_solution is set to less-vision."
    }
    precondition {
      condition = var.proxy_solution != "less-vision-reality" || (
        length(var.less_vision_reality_short_ids) > 0 &&
        alltrue([for id in var.less_vision_reality_short_ids : length(trimspace(id)) > 0])
      )
      error_message = "less_vision_reality_short_ids must contain at least one non-empty value when proxy_solution is set to less-vision-reality."
    }
    precondition {
      condition = var.proxy_solution != "less-vision-reality" || (
        length(trimspace(var.less_vision_reality_private_key)) > 0 &&
        length(trimspace(var.less_vision_reality_public_key)) > 0
      )
      error_message = "less-vision-reality requires both less_vision_reality_private_key and less_vision_reality_public_key."
    }
  }

  # connection {
  #   type = "ssh"
  #   user = var.machine_config["nonroot_username"]
  #   private_key = file(var.ssh_private_key_path)
  #   host = aws_lightsail_instance.lightsail_instance.public_ip_address
  #   target_platform = "unix"
  #   port = 22
  # }

  # provisioner "local-exec" {
  #   command = "ANSIBLE_SSH_RETRIES=5 ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.machine_config["nonroot_username"]} -i '${aws_lightsail_instance.lightsail_instance.public_ip_address},' --private-key ${var.ssh_private_key_path} --extra-vars 'username=${var.machine_config["nonroot_username"]} domain_name=${var.domain_name} subdomain_name=${var.subdomain_name} public_ip=${aws_lightsail_static_ip.instance_ip.ip_address} namecheap_ddns_password=${var.namecheap_ddns_password} proxy_server_uuid=${var.proxy_server_uuid}' ${path.module}/scripts/trojan-go/playbook.yml"
  # }
}

resource "aws_lightsail_instance_public_ports" "proxy" {
  instance_name = aws_lightsail_instance.lightsail_instance.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }
  port_info {
    protocol  = "tcp"
    from_port = 80
    to_port   = 80
  }
  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
  port_info {
    protocol  = "udp"
    from_port = 60000
    to_port   = 60010
  }
  port_info {
    protocol  = "tcp"
    from_port = 8990
    to_port   = 8990
  }
  port_info {
    protocol  = "udp"
    from_port = 8990
    to_port   = 8990
  }
}

