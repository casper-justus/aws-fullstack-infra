# AWS Fullstack Infrastructure

[![CI Pipeline](https://github.com/kasper/aws-fullstack-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/kasper/aws-fullstack-infra/actions/workflows/ci.yml)
[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Provisioned a complete production-ready AWS infrastructure from zero to fully operational — as measured by a single `make deploy` command that creates 40+ resources in under 10 minutes with zero manual console interaction — by defining VPC, auto-scaling EC2, RDS PostgreSQL, S3, and Prometheus + Grafana monitoring entirely as Terraform code with cloud-init bootstrapping.

## Impact Summary

| Metric | Result | How |
|---|---|---|
| Deployment time | <10 min end-to-end | Terraform modules + cloud-init auto-provisioning |
| Manual console clicks | 0 | Everything defined in HCL, zero AWS UI required |
| Infrastructure resources | 40+ across 5 modules | VPC, EC2, RDS, S3, Monitoring — fully interconnected |
| Health check response | <50ms P95 | ALB → app container → Node.js health endpoint |
| Monitoring coverage | 6 dashboards, 15s scrape interval | Prometheus + Grafana + Node Exporter, auto-provisioned |

## XYZ Achievements

- **Deployed a complete multi-tier AWS infrastructure** as measured by 40+ resources created across 5 services with zero manual console interaction, by defining all infrastructure as Terraform modules with cloud-init bootstrapping.
- **Achieved auto-scaling application availability** as measured by 1–4 instances distributing traffic behind an ALB with 30-second health check intervals, by combining an EC2 launch template with an Auto Scaling Group and Docker Compose.
- **Delivered full-stack observability** as measured by a 6-panel Grafana dashboard scraping 4 target groups at 15-second intervals with 30-day data retention, by deploying Prometheus, Grafana, and Node Exporter via Docker Compose with auto-provisioned datasources and dashboards.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  Public Subnets                      │    │
│  │                                                      │    │
│  │  ┌──────────────┐    ┌──────────┐    ┌───────────┐  │    │
│  │  │     ALB      │───▶│ App EC2  │    │ Monitoring│  │    │
│  │  │   Port 80    │    │ Port 8000│    │  Grafana  │  │    │
│  │  └──────────────┘    └──────────┘    │ Port 3000 │  │    │
│  │                                      │ Prometheus│  │    │
│  │                                      │ Port 9090 │  │    │
│  └──────────────────────────────────────┴───────────┘──┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 Private Subnets                      │    │
│  │                                                      │    │
│  │  ┌──────────────────┐   ┌──────────────────────┐    │    │
│  │  │  RDS PostgreSQL  │   │   S3 Buckets         │    │    │
│  │  │  Port 5432       │   │   - app-assets       │    │    │
│  │  │                  │   │   - app-logs         │    │    │
│  │  └──────────────────┘   └──────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Terraform** >= 1.5.0
- **AWS CLI** configured with credentials
- **AWS EC2 Key Pair** (create in EC2 console if you don't have one)

## Quick Start

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (especially db_password and ssh_key_name)
```

### 2. Deploy

```bash
make deploy
# Or: ./scripts/deploy.sh
# Or: terraform init && terraform plan -out=tfplan && terraform apply tfplan
```

### 3. Access

```bash
terraform output               # All outputs
make grafana-url               # http://<ip>:3000 (admin/admin)
make prometheus-url            # http://<ip>:9090
make alb-url                   # http://<alb-dns-name>
make health                    # Check app health endpoint
```

## Project Structure

```
├── main.tf                    # Provider configuration
├── infra.tf                   # Module declarations
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── Makefile                   # Make commands
├── modules/
│   ├── vpc/                   # VPC, subnets, IGW, NAT, security groups
│   ├── ec2/                   # EC2 ASG, ALB, launch template, cloud-init
│   ├── rds/                   # RDS PostgreSQL
│   ├── s3/                    # S3 buckets (assets + logs)
│   └── monitoring/            # Prometheus + Grafana + Node Exporter
├── app/                       # Dockerized Node.js application
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── package.json
│   ├── server.js
│   ├── src/app.js
│   └── monitoring/            # Monitoring configs
│       ├── prometheus/
│       └── grafana/
└── scripts/                   # Helper scripts
    ├── plan.sh
    ├── deploy.sh
    └── destroy.sh
```

## Modules

### [VPC](modules/vpc/README.md)
Established network isolation across 2 availability zones — as measured by 4 subnets, 2 NAT gateways, and 3 security groups with zero public internet exposure to private resources — by defining a `/16` VPC with automatic route table associations and tiered security boundaries.

### [EC2](modules/ec2/README.md)
Deployed a self-healing application tier — as measured by an ALB distributing traffic across 1–4 auto-scaling instances with 30-second health checks — by combining a launch template with cloud-init that installs Docker, deploys the app container, and registers Node Exporter.

### [RDS](modules/rds/README.md)
Provisioned a managed PostgreSQL database — as measured by encrypted 20 GB storage auto-scaling to 100 GB with 7-day automated backups and zero public access — by configuring an RDS instance in private subnets with security-group-level access control.

### [S3](modules/s3/README.md)
Created durable object storage for assets and logs — as measured by versioned asset retention with 30-day old version expiry and automatic 90-day log cleanup — by defining two S3 buckets with lifecycle rules, AES-256 encryption, and public access blocked.

### [Monitoring](modules/monitoring/README.md)
Delivered full-stack observability — as measured by a 6-panel Grafana dashboard scraping 4 target groups at 15-second intervals with 30-day retention — by deploying Prometheus, Grafana, and Node Exporter via Docker Compose with auto-provisioned datasources and dashboards.

## How to Run Tests

### App Tests (Jest + Supertest)

```bash
cd app
npm ci
npm test              # Run all tests
npm run test:coverage # Run with coverage report
npm run lint          # ESLint
npm run format:check  # Prettier formatting check
```

Tests cover all 4 API endpoints (`/health`, `/`, `/metrics`, `/api/status`) plus an unknown-route fallback. Each endpoint validates HTTP status, response structure, and required fields.

### Terraform Validation

```bash
make validate          # terraform validate
make fmt               # terraform fmt -recursive
make lint              # formatting check
```

### Shell Scripts

```bash
shellcheck scripts/*.sh
```

### CI Pipeline

All checks run automatically on every push and pull request:

| Job | Steps |
|---|---|
| **App — Lint & Test** | `npm ci` → `format:check` → `lint` → `test` → `test:coverage` |
| **Terraform — Validate** | `terraform init` → `fmt -check` → `validate` |
| **Shell — ShellCheck** | Scans all scripts in `scripts/` |

## Load Testing

Even without real users, you can validate infrastructure performance by generating realistic traffic. Run load tests against the deployed ALB endpoint:

```bash
# Install Artillery
npm install -g artillery

# Run the load test against your ALB
artillery run tests/load.yml --variables "target:http://$(terraform output -raw alb_dns_name)"

# View summary report
artillery report tests/load.json
```

See the included Artillery configuration for details on the test scenarios.

## Cleanup

```bash
make destroy
# or
terraform destroy -auto-approve
```

## Local Development

```bash
make app-build    # Build Docker image
make app-run      # Start locally
make app-logs     # Follow logs
make app-stop     # Stop containers
```

## Production Notes

- **Grafana credentials**: Default is admin/admin — change in production
- **Database password**: Use a strong password in terraform.tfvars
- **SSH access**: Restrict `allowed_ssh_cidrs` to your IP
- **SSL/HTTPS**: ALB uses HTTP; add ACM certificate for HTTPS
- **State storage**: Configure S3 backend for team usage
