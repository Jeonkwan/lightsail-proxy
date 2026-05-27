# Lightsail Proxy CI/CD Workflow

This repository includes an automated GitHub Actions workflow to manage your AWS Lightsail infrastructure using Terraform.

## Prerequisites

1.  **S3 Bucket**: Create an S3 bucket in your AWS account to store Terraform state (e.g., `my-lightsail-proxy-terraform-state`).
2.  **AWS IAM Credentials**: Create an IAM user with `AmazonLightsailFullAccess` and `AmazonS3FullAccess` (restricted to the specific bucket).
3.  **GitHub Secrets**: Add the following secrets to your GitHub repository settings:
    *   `AWS_ACCESS_KEY_ID`: Your IAM user access key.
    *   `AWS_SECRET_ACCESS_KEY`: Your IAM user secret key.

## Terraform Backend (Native S3 Locking)

The configuration uses Terraform's native S3 state locking (introduced in v1.10.0), removing the need for a separate DynamoDB table.

*   **Location**: `lightsail-proxy/config.tf`
*   **Requirements**: Terraform v1.10.0+

```hcl
backend "s3" {
  bucket  = "my-lightsail-proxy-terraform-state"
  key     = "lightsail-proxy/terraform.tfstate"
  region  = "us-east-1"
  encrypt = true
}
```

## Workflow Usage

The workflow `terraform-deploy.yml` automates the deployment process:

- **Trigger**: Automatically on `push` to `main`, or manually via `workflow_dispatch`.
- **Inputs** (Manual Trigger):
  - `tf_action`: Choose between `plan`, `apply`, or `destroy`.

### Manual Deployment via GitHub

1.  Navigate to the **Actions** tab in your GitHub repository.
2.  Select the **terraform-deploy** workflow.
3.  Click **Run workflow**.
4.  Choose the desired `tf_action` and click **Run**.

## Troubleshooting

- **Locking Errors**: If you get a state locking error, ensure no other process is running an `apply`. If a run was interrupted, you may need to manually release the lock using `terraform force-unlock` if the native S3 locking didn't clean up correctly.
- **Version Compatibility**: Ensure the `setup-terraform` action version is set to `v1.10.0` or higher to support native S3 locking.
