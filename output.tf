output "public_ip_address" {
    value = aws_lightsail_static_ip.instance_ip.ip_address
}

output "hostname" {
    value = "${var.subdomain_name}.${var.domain_name}"
}

output "username" {
    value = var.machine_config["nonroot_username"]
}

output "ssh_key_pair_name" {
    value = aws_lightsail_key_pair.ssh.name
}

output "ssh-connect" {
    value = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ${var.machine_config["nonroot_username"]}@${aws_lightsail_static_ip.instance_ip.ip_address}"
}

output "mosh-connect" {
    value = "mosh --ssh='ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")}' ${var.machine_config["nonroot_username"]}@${aws_lightsail_static_ip.instance_ip.ip_address}"
}


