# lightsail-proxy
An AWS Lightsail VM with proxy setup automatically

## Requirement
1. A domain from Namecheap.
1. Enable Dynamic DNS in Namecheap's Advance DNS dashboard.
1. You will need Dynamic DNS Password.
1. You must first create DNS A record with the subdomain you are going to use. The script can only update an existing DNS record but not creating a new one. You can create a few records upfront and point them to 127.0.0.1 if you are going to test multiple lightsail instance in different locations at the same time.

## How-to
Modify the `defaults.tfvars` or create your own e.g. `users.tfvars`. Just point to the `tfvars` file when you run `terraform plan` and `terraform apply`.

```bash
tfvar_file="users.tfvars"  # if you are creating your own .tfvars
terraform init
terraform plan -var-file=$tfvar_file
terraform apply -var-file=$tfvar_file
```
