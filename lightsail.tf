locals {
  instance_name = "${var.instance_name_prefix}-${var.selected_country}-${var.zones[var.selected_zone]}-${var.instance_customizable_name}"
}

data "template_file" "vm_init_script" {
  template = "${file("${path.module}/setup_ubuntu.sh.tpl")}"
  vars = {
    username = var.machine_config["nonroot_username"]
  }
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
  name              = local.instance_name
  availability_zone = "${var.regions[var.selected_country]}${var.zones[var.selected_zone]}"
  blueprint_id      = var.machine_config["os"]
  bundle_id         = var.machine_config["instance_type"]
  key_pair_name     = aws_lightsail_key_pair.ssh.name
  user_data         = data.template_file.vm_init_script.rendered
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

