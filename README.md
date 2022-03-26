# lightsail-proxy
An AWS Lightsail VM with proxy setup automatically


## How-to
Modify the `defaults.tfvars` or create your own. Just point to the `tfvars` file when you run `terraform plan` and `terraform apply`.

```bash
terraform init
terraform plan -var-file="defaults.tfvars"
terraform apply -var-file="defaults.tfvars"
```
