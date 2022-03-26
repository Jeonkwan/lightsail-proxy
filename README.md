# lightsail-proxy
An AWS Lightsail VM with proxy setup automatically


## How-to
Modify the `defaults.tfvars` or create your own. Just point to the `tfvars` file when you run `terraform apply`.

```bash
terraform init
terraform plan
terraform apply -var-file="defaults.tfvars"
```
