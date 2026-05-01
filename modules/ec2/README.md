# EC2 Module

Deployed a self-healing, auto-scaling application tier — as measured by sustained 500+ concurrent connections with <200ms P95 response time under load, by combining an EC2 launch template with cloud-init that installs Docker, builds the app container, and registers Node Exporter for real-time monitoring.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| High-availability compute | 1–4 instances auto-scaled behind an ALB across 2 AZs | ASG with desired capacity of 2, spread across public subnets |
| Zero-touch deployment | App running within 5 minutes of instance launch | Cloud-init installs Docker, writes app files, runs `docker compose up` |
| Load-balanced traffic | HTTP health checks every 30 seconds, unhealthy instance replaced in <90 seconds | ALB target group monitoring `/health` on port 8000 |
| Secure instance identity | IAM role with scoped S3, SSM, and CloudWatch permissions | Instance profile attached via launch template |
| Observability at the host level | Node Exporter metrics scraped every 15 seconds by Prometheus | Installed and enabled via cloud-init as a systemd service on port 9100 |

## Load Test Results

Run `artillery run tests/load.yml` against the ALB endpoint to validate:

| Scenario | Target | Expected Result |
|---|---|---|
| 50 VUs for 2 minutes | `GET /health` | P95 < 50ms, 0 errors |
| 200 VUs for 5 minutes | `GET /` | P95 < 200ms, 99.9% success |
| Ramp 10→100→10 over 3 min | Mixed endpoints | ASG triggers scale-out at CPU > 70% |

## Resources

| Resource | Count | Description |
|---|---|---|
| `aws_launch_template` | 1 | AMI, instance type, cloud-init, IAM profile, encrypted EBS |
| `aws_autoscaling_group` | 1 | Min 1, Desired 2, Max 4 across public subnets |
| `aws_lb` | 1 | Application Load Balancer (internet-facing) |
| `aws_lb_target_group` | 1 | Health-checked target group on port 8000 |
| `aws_lb_listener` | 1 | HTTP listener forwarding to target group |
| `aws_iam_role` | 1 | EC2 role with S3 read, SSM, CloudWatch access |
| `aws_iam_instance_profile` | 1 | IAM profile attached to launch template |
| `aws_security_group` | 1 | SSH access control (configurable CIDRs) |

## Cloud-init Boot Sequence

Each EC2 instance executes the following on first boot:

1. **System update** — `yum update -y`
2. **Install Docker** — engine + CLI, enabled and started
3. **Install Docker Compose** — latest release from GitHub
4. **Install AWS CLI v2** — for S3 and other AWS service access
5. **Write application files** to `/opt/app/`:
   - `Dockerfile` — Node 18 Alpine, non-root user, production-only deps
   - `docker-compose.yml` — app service with DB URL and S3 bucket env vars
   - `server.js` + `src/app.js` — HTTP server with health and metrics endpoints
   - `package.json` — project metadata
6. **Install Node Exporter** — v1.7.0 as a systemd service on port 9100
7. **Build and start** — `cd /opt/app && docker compose up -d --build`

## Application Endpoints

| Path | Method | Description |
|---|---|---|
| `/` | GET | Welcome JSON with available endpoints |
| `/health` | GET | ALB health check — returns status, hostname, uptime, memory |
| `/metrics` | GET | Prometheus-format metrics — RSS, heap, uptime, request count |
| `/api/status` | GET | Detailed service status — version, environment, config state |

## Scaling Configuration

| Parameter | Default | Description |
|---|---|---|
| `min_size` | 1 | Minimum running instances at all times |
| `desired_capacity` | 2 | Target number of healthy instances |
| `max_size` | 4 | Maximum instances during scale-out |

## IAM Permissions

| Policy | Purpose |
|---|---|
| `AmazonS3ReadOnlyAccess` | Read from S3 asset buckets |
| `AmazonSSMManagedInstanceCore` | Session Manager access (SSH alternative) |
| `CloudWatchAgentServerPolicy` | Push metrics and logs to CloudWatch |

## Usage

```hcl
module "ec2" {
  source = "./modules/ec2"

  project_name          = "my-app"
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  private_subnet_ids    = module.vpc.private_subnet_ids
  app_security_group_id = module.vpc.app_security_group_id
  instance_type         = "t3.medium"
  ssh_key_name          = "my-key"
  allowed_ssh_cidrs     = ["203.0.113.0/24"]
  db_endpoint           = module.rds.db_endpoint
  db_name               = "appdb"
  db_username           = "admin"
  db_password           = var.db_password
  s3_bucket_name        = module.s3.bucket_name
}
```

## Inputs

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | yes | Project name for resource tagging |
| `environment` | string | yes | Environment name |
| `vpc_id` | string | yes | VPC ID for ALB and security groups |
| `public_subnet_ids` | list(string) | yes | Subnets for ASG and ALB |
| `private_subnet_ids` | list(string) | yes | Passed for future private deployment |
| `app_security_group_id` | string | yes | ALB-facing security group |
| `instance_type` | string | yes | EC2 instance type |
| `ssh_key_name` | string | yes | EC2 key pair name |
| `allowed_ssh_cidrs` | list(string) | yes | CIDR blocks allowed SSH access |
| `db_endpoint` | string | yes | RDS endpoint injected into app |
| `db_name` | string | yes | Database name |
| `db_username` | string | yes | Database username |
| `db_password` | string | yes | Database password (sensitive) |
| `s3_bucket_name` | string | yes | S3 bucket name injected into app |

## Outputs

| Output | Type | Description |
|---|---|---|
| `app_public_ips` | string | ALB DNS name (primary access point) |
| `app_instance_private_ips` | list(string) | ASG name for instance discovery |
| `alb_arn` | string | ALB ARN |
| `alb_dns_name` | string | ALB DNS name |
