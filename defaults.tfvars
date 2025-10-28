selected_country           = "singapore"
selected_zone              = "a"
instance_customizable_name = "machine"
ssh_public_key_path        = "~/.ssh/my_ssh_key.pub"
ssh_private_key_path       = "~/.ssh/my_ssh_key_private"
domain_name                = "example.com"
subdomain_name             = "subdomain-name"
namecheap_ddns_password    = "youShouldPassItOnTheFly" # Ignored when proxy_solution = "less-vision-reality"
# Proxy identifier shared across solutions:
# - Trojan-Go uses this value as the connection password.
# - less-vision consumes it directly as the UUID.
proxy_server_uuid          = "00000000-0000-4000-8000-000000000000"
proxy_solution             = "trojan-go"
proxy_contact_email        = "admin@example.com" # Required when proxy_solution = "less-vision"
less_vision_reality_short_ids = ["01234567", "89abcdef"] # Required when proxy_solution = "less-vision-reality"
less_vision_reality_private_key = "BASE64_PRIVATE_KEY" # Required when proxy_solution = "less-vision-reality"
less_vision_reality_public_key  = "BASE64_PUBLIC_KEY" # Required when proxy_solution = "less-vision-reality"
less_vision_reality_decoy_domain = "web.wechat.com" # Optional Reality SNI forwarded to the playbook
aws_cred_file_path         = "~/.aws/credentials"
aws_conf_file_path         = "~/.aws/config"
playbook_branch            = "main"
