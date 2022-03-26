output "rendered_init_script" {
    value = data.template_file.vm_init_script.rendered
}

output "public_ip_address" {
    value = aws_lightsail_static_ip.instance_ip.ip_address
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
    value = "mosh --ssh=\"ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")}\" ${var.machine_config["nonroot_username"]}@${aws_lightsail_static_ip.instance_ip.ip_address}"
}


