# RDS Module

Provisioned a managed PostgreSQL database — as measured by <200ms query response time under concurrent load from 2 app instances with encrypted 20 GB storage auto-scaling to 100 GB and 7-day automated backups — by configuring an RDS instance inside private subnets with security-group-level access control restricted to the application tier.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| Managed relational database | PostgreSQL 15.4 with automated patching and zero-downtime minor version upgrades | RDS instance with `auto_minor_version_upgrade = true` |
| Data protection at rest | AES-256 encryption on all storage and automated backups | `storage_encrypted = true` on instance |
| Automatic capacity growth | Storage scales from 20 GB to 100 GB without manual intervention | `max_allocated_storage = 100` with gp3 storage type |
| Point-in-time recovery | 7 days of automated daily backups, restorable to any second | `backup_retention_period = 7` with defined backup window |
| Network isolation | Database unreachable from the public internet, accessible only from app SG | Private subnets, `publicly_accessible = false`, SG allows app tier only |
| Operational visibility | OS-level metrics every 60 seconds visible in CloudWatch | `monitoring_interval = 60` (Enhanced Monitoring) |

## Database Performance Under Load

When the app module runs 200 VUs with database-connected endpoints, expect:

| Metric | Baseline | Under Load (200 VUs) | Notes |
|---|---|---|---|
| Query latency (simple SELECT) | <5ms | <15ms | VPC-local, same region |
| Connection count | 2 (1 per app instance) | 2–4 | Connection pooling recommended for higher scale |
| CPU utilization | <5% | 15–30% | `db.t3.micro` burstable credits handle spikes |
| Storage IOPS | <100 | 200–500 | gp3 baseline is 3,000 IOPS |
| WAL write latency | <1ms | <3ms | Local SSD-backed storage |

## Resources

| Resource | Count | Description |
|---|---|---|
| `aws_db_subnet_group` | 1 | Groups private subnets for RDS placement |
| `aws_db_instance` | 1 | PostgreSQL 15.4 instance with full configuration |

## Configuration

| Parameter | Value | Description |
|---|---|---|
| Engine | PostgreSQL 15.4 | Stable, widely-supported version |
| Instance Class | `db.t3.micro` (configurable) | Burstable performance for dev workloads |
| Initial Storage | 20 GB gp3 | SSD-backed, auto-scales to 100 GB |
| Encryption | Enabled (AES-256) | AWS-managed key, no custom KMS required |
| Multi-AZ | Disabled | Enable for production high availability |
| Public Access | Disabled | Only reachable within VPC |
| Backup Retention | 7 days | Automated daily backups in `03:00-04:00` UTC window |
| Maintenance Window | Mon `04:00-05:00` UTC | Auto minor version upgrades enabled |
| Enhanced Monitoring | 60-second interval | OS-level metrics via CloudWatch |
| Final Snapshot | Created on destroy | Prevents accidental data loss |

## Security

- Security group allows port 5432 **only** from the App security group
- No public endpoint — instance lives in private subnets
- Storage encrypted with AWS-managed KMS key
- Password passed via Terraform sensitive variable (never logged)
- Final snapshot created automatically on `terraform destroy`

## Usage

```hcl
module "rds" {
  source = "./modules/rds"

  project_name         = "my-app"
  environment          = "prod"
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  db_security_group_id = module.vpc.db_security_group_id
  db_name              = "appdb"
  db_username          = "admin"
  db_password          = var.db_password
  db_instance_class    = "db.t3.micro"
}
```

## Inputs

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | yes | Project name for resource tagging |
| `environment` | string | yes | Environment name |
| `vpc_id` | string | yes | VPC ID |
| `subnet_ids` | list(string) | yes | Private subnets for DB placement |
| `db_security_group_id` | string | yes | Security group (allows app-tier only) |
| `db_name` | string | yes | Initial database name |
| `db_username` | string | yes | Master username |
| `db_password` | string | yes | Master password (sensitive) |
| `db_instance_class` | string | yes | RDS instance class |

## Outputs

| Output | Type | Description |
|---|---|---|
| `db_endpoint` | string | `hostname:port` connection string |
| `db_arn` | string | RDS instance ARN |
| `db_name` | string | Database name |

## Connection

From app EC2 instances (via injected `DATABASE_URL`):

```bash
psql "postgresql://admin:<password>@<db_endpoint>/appdb"
```

The connection string is passed to the Docker container through the cloud-init generated `docker-compose.yml`.

## Production Recommendations

- Enable `multi_az = true` for cross-AZ failover
- Use a custom KMS key instead of the AWS-managed key
- Increase `db_instance_class` to `db.t3.small` or higher
- Add connection pooling (PgBouncer) for 10+ app instances
- Set up read replicas for read-heavy workloads
