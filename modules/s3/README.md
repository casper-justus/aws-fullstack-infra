# S3 Module

Created durable object storage for application assets and operational logs — as measured by versioned asset retention with 30-day old version expiry and automatic 90-day log cleanup, eliminating manual storage management — by defining two S3 buckets with lifecycle rules, AES-256 encryption, and public access blocked.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| Versioned asset storage | All object versions retained for 30 days before automatic deletion | S3 versioning + lifecycle rule `noncurrent_version_expiration` |
| Automatic log cleanup | Logs expire after 90 days, preventing unbounded storage costs | Lifecycle rule with `expiration.days = 90` |
| Abort wasted multipart uploads | Incomplete uploads cleaned up after 7 days | Lifecycle rule `abort_incomplete_multipart_upload` |
| Encryption at rest | Every object encrypted with AES-256 (SSE-S3) | Server-side encryption configuration on both buckets |
| Zero public exposure | All public access paths blocked | `aws_s3_bucket_public_access_block` with all 4 flags enabled |

## Resources

| Resource | Count | Description |
|---|---|---|
| `aws_s3_bucket` | 2 | Assets bucket + Logs bucket |
| `aws_s3_bucket_versioning` | 1 | Versioning enabled on assets bucket |
| `aws_s3_bucket_lifecycle_configuration` | 2 | Retention and cleanup rules for each bucket |
| `aws_s3_bucket_server_side_encryption_configuration` | 2 | AES-256 encryption on both buckets |
| `aws_s3_bucket_public_access_block` | 2 | Block all public access on both buckets |
| `random_id` | 1 | Unique bucket name suffix to avoid collisions |

## Buckets

### Assets Bucket (`<project>-<env>-assets-<random>`)

| Feature | Configuration |
|---|---|
| Versioning | Enabled |
| Encryption | AES-256 (SSE-S3) |
| Public Access | Fully blocked (all 4 flags) |
| Old Version Expiry | 30 days after becoming non-current |
| Multipart Upload Abort | 7 days after initiation |

### Logs Bucket (`<project>-<env>-logs-<random>`)

| Feature | Configuration |
|---|---|
| Versioning | Disabled (logs are append-only) |
| Encryption | AES-256 (SSE-S3) |
| Public Access | Fully blocked (all 4 flags) |
| Object Expiry | 90 days after creation |

## Usage

```hcl
module "s3" {
  source = "./modules/s3"

  project_name = "my-app"
  environment  = "prod"
}
```

## Inputs

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | yes | Project name used in bucket naming |
| `environment` | string | yes | Environment name used in bucket naming |

## Outputs

| Output | Type | Description |
|---|---|---|
| `bucket_name` | string | Assets bucket name |
| `logs_bucket_name` | string | Logs bucket name |
| `bucket_arn` | string | Assets bucket ARN |
| `logs_bucket_arn` | string | Logs bucket ARN |

## Example Operations

```bash
# Upload static assets
aws s3 cp ./dist/ s3://$(terraform output -raw bucket_name)/ --recursive

# Upload application logs
aws s3 cp /var/log/app.log s3://$(terraform output -raw logs_bucket_name)/app-$(date +%Y%m%d).log

# Sync a local directory
aws s3 sync ./uploads/ s3://$(terraform output -raw bucket_name)/uploads/

# List bucket contents
aws s3 ls s3://$(terraform output -raw bucket_name)/ --recursive
```

## Cost Estimate

| Bucket | Storage | Monthly Cost (us-east-1) |
|---|---|---|
| Assets (1 GB, versioned) | ~2 GB effective with versions | ~$0.046 |
| Logs (5 GB, 90-day expiry) | ~5 GB average | ~$0.115 |
| **Total** | | **~$0.16/month** |

Costs scale linearly with usage. Lifecycle rules prevent cost creep from old versions and logs.
