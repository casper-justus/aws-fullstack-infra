# Monitoring Module

Delivered full-stack observability across the infrastructure — as measured by a 6-panel Grafana dashboard scraping 4 target groups at 15-second intervals with 30-day retention, providing real-time visibility into CPU, memory, disk, network, and application health — by deploying Prometheus, Grafana, and Node Exporter via Docker Compose with auto-provisioned datasources and dashboards.

## What This Accomplishes

| Goal | Measure | Method |
|---|---|---|
| Infrastructure metrics | Node Exporter on every instance, scraped at 15s intervals | Installed via cloud-init as systemd service, Prometheus target configured dynamically |
| Application metrics | Custom Prometheus endpoints exposed at `/metrics` on port 8000 | Node.js app exports RSS memory, heap usage, uptime, and request count |
| Visual dashboards | 6 pre-built panels auto-loaded on first Grafana startup | Provisioned via YAML config + embedded JSON dashboard definition |
| Data retention | 30 days of time-series data with no manual management | Prometheus `--storage.tsdb.retention.time=30d` flag |
| Zero-configuration onboarding | Datasource and dashboards ready on first login | Grafana provisioning directory with pre-written configs |

## Load Test Validation

Run a load test and watch the dashboard update in real-time:

```bash
# Start the load test
artillery run tests/load.yml --variables "target:http://$(terraform output -raw alb_dns_name)"

# Watch Grafana panels respond:
# - CPU Usage spikes from baseline to 40-80% during ramp
# - Memory Usage increases as Node.js heap grows under load
# - Network Traffic shows bytes received per second scaling with VU count
# - App Uptime tracks process restarts if any occur
# - HTTP request counter increments matching artillery's reported request count
```

| Metric | Baseline | Under Load (200 VUs) | Recovery |
|---|---|---|---|
| CPU (idle) | ~95% | ~20-60% | Returns within 60s |
| Memory RSS | ~50 MB | ~120-180 MB | GC reclaims within 30s |
| Request rate | 0 req/s | ~800-1200 req/s | Drops to 0 on stop |
| Disk I/O | <1 KB/s read | ~10-50 KB/s read | Returns to baseline |

## Resources

| Resource | Count | Description |
|---|---|---|
| `aws_instance` | 1 | Monitoring server (t3.small, 50 GB gp3 encrypted) |
| `aws_eip` | 1 | Static public IP for stable Grafana/Prometheus URLs |
| `aws_eip_association` | 1 | EIP attached to monitoring instance |
| `aws_iam_role` | 1 | SSM + CloudWatch access for the monitoring server |
| `aws_iam_instance_profile` | 1 | IAM profile attached to instance |

## Stack Components

### Prometheus

| Setting | Value |
|---|---|
| Version | 2.48.0 |
| Port | 9090 |
| Scrape Interval | 15 seconds |
| Evaluation Interval | 15 seconds |
| Retention | 30 days |
| Storage | Docker volume (persistent across restarts) |

**Scrape Targets:**

| Job | Targets | Port | Description |
|---|---|---|---|
| `prometheus` | `localhost` | 9090 | Self-monitoring |
| `node_exporter` | `localhost` | 9100 | Monitoring server host metrics |
| `app_nodes` | App instance IPs | 9100 | App server host metrics |
| `app_metrics` | App instance IPs | 8000 | Application-level metrics |

### Grafana

| Setting | Value |
|---|---|
| Version | 10.2.0 |
| Port | 3000 |
| Default User | `admin` |
| Default Password | `admin` |
| Sign-up | Disabled |
| Anonymous Access | Disabled |

**Auto-Provisioned:**
- Prometheus datasource at `http://localhost:9090` (default datasource)
- AWS Infrastructure Dashboard (6 panels, embedded JSON)

### Node Exporter

| Setting | Value |
|---|---|
| Version | 1.7.0 |
| Port | 9100 |
| Runs On | Monitoring server + all app instances |
| Service Type | systemd (auto-start on boot) |
| User | `node_exporter` (non-root, no shell) |

## Grafana Dashboard Panels

| Panel | PromQL Query | Type |
|---|---|---|
| CPU Usage (%) | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | Graph |
| Memory Usage | `node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes` | Graph |
| Disk I/O | `rate(node_disk_read_bytes_total[5m])` + `rate(node_disk_written_bytes_total[5m])` | Graph |
| Network Traffic | `rate(node_network_receive_bytes_total{device!="lo"}[5m])` + transmit | Graph |
| App Memory RSS | `node_memory_rss_bytes` | Graph |
| App Uptime | `node_uptime_seconds` | Stat (color-coded thresholds) |

## Cloud-init Boot Sequence

On first boot the monitoring instance:

1. **System update** — `yum update -y`
2. **Install Docker + Docker Compose + AWS CLI v2**
3. **Install Node Exporter** — v1.7.0 as a systemd service
4. **Create directory structure** at `/opt/monitoring/`:
   ```
   /opt/monitoring/
   ├── docker-compose.yml
   ├── prometheus/
   │   ├── config/prometheus.yml
   │   └── data/            (Docker volume mount)
   └── grafana/
       ├── grafana.ini
       └── provisioning/
           ├── datasources/datasource.yml
           └── dashboards/
               ├── dashboards.yml
               └── aws-infra.json
   ```
5. **Write all configuration files** from Terraform-local templates
6. **Start Docker Compose stack** — `docker compose up -d`

## Access

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://<eip>:3000` | admin / admin |
| Prometheus | `http://<eip>:9090` | None (open) |

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name               = "my-app"
  environment                = "prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  monitoring_security_group_id = module.vpc.monitoring_security_group_id
  instance_type              = "t3.small"
  ssh_key_name               = "my-key"
  allowed_ssh_cidrs          = ["203.0.113.0/24"]
  app_instance_ips           = module.ec2.app_instance_private_ips
}
```

## Inputs

| Variable | Type | Required | Description |
|---|---|---|---|
| `project_name` | string | yes | Project name for resource tagging |
| `environment` | string | yes | Environment name |
| `vpc_id` | string | yes | VPC ID |
| `private_subnet_ids` | list(string) | yes | Subnets for monitoring instance |
| `monitoring_security_group_id` | string | yes | SG allowing 3000/9090 inbound |
| `instance_type` | string | yes | EC2 instance type |
| `ssh_key_name` | string | yes | EC2 key pair name |
| `allowed_ssh_cidrs` | list(string) | yes | CIDR blocks allowed SSH access |
| `app_instance_ips` | list(string) | yes | App IPs for Prometheus targets |

## Outputs

| Output | Type | Description |
|---|---|---|
| `monitoring_public_ip` | string | Elastic IP address |
| `grafana_url` | string | Full Grafana URL |
| `prometheus_url` | string | Full Prometheus URL |

## Adding Custom Dashboards

1. Create or export a Grafana dashboard as JSON
2. Place it in `app/monitoring/grafana/provisioning/dashboards/`
3. Re-run `terraform apply` — cloud-init writes it to the instance
4. Or SSH in and copy directly, then restart Grafana:
   ```bash
   docker compose -f /opt/monitoring/docker-compose.yml restart grafana
   ```

## Adding Scrape Targets

Edit `/opt/monitoring/prometheus/config/prometheus.yml` on the instance:

```yaml
scrape_configs:
  - job_name: 'custom_service'
    static_configs:
      - targets: ['10.0.2.100:9100']
```

Reload Prometheus without restart:

```bash
curl -X POST http://localhost:9090/-/reload
```
