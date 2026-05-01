resource "aws_iam_role" "monitoring_role" {
  name = "${var.project_name}-${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "monitoring_cloudwatch" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-${var.environment}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}

resource "aws_eip" "monitoring" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring-eip"
  }
}

locals {
  app_targets = join("\n", [
    for ip in var.app_instance_ips : "  - targets: ['${ip}:9100']"
  ])

  prometheus_yml = <<-EOF
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'node_exporter'
        static_configs:
          - targets: ['localhost:9100']

      - job_name: 'app_nodes'
        static_configs:
          - targets: [${join(", ", [for ip in var.app_instance_ips : "'${ip}:9100'"])}]

      - job_name: 'app_metrics'
        metrics_path: '/metrics'
        static_configs:
          - targets: [${join(", ", [for ip in var.app_instance_ips : "'${ip}:8000'"])}]
  EOF

  grafana_ini = <<-EOF
    [server]
    http_port = 3000

    [security]
    admin_user = admin
    admin_password = admin

    [users]
    allow_sign_up = false

    [auth.anonymous]
    enabled = false
  EOF

  grafana_datasource_yml = <<-EOF
    apiVersion: 1

    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://localhost:9090
        isDefault: true
        editable: true
        version: 1
  EOF

  grafana_dashboard_yml = <<-EOF
    apiVersion: 1

    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /etc/grafana/provisioning/dashboards
  EOF

  grafana_dashboard_json = jsonencode({
    "__inputs" = []
    "__requires" = []
    "annotations" = {
      "list" = []
    }
    "description" = "AWS Infrastructure Monitoring Dashboard"
    "editable" = true
    "gnetId" = null
    "graphTooltip" = 0
    "id" = null
    "links" = []
    "panels" = [
      {
        "id" = 1
        "title" = "CPU Usage"
        "type" = "graph"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
            "legendFormat" = "{{instance}}"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 0, "y" = 0 }
      },
      {
        "id" = 2
        "title" = "Memory Usage"
        "type" = "graph"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes"
            "legendFormat" = "{{instance}}"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 12, "y" = 0 }
      },
      {
        "id" = 3
        "title" = "Disk I/O"
        "type" = "graph"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "rate(node_disk_read_bytes_total[5m])"
            "legendFormat" = "{{instance}} - read"
          },
          {
            "expr" = "rate(node_disk_written_bytes_total[5m])"
            "legendFormat" = "{{instance}} - write"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 0, "y" = 8 }
      },
      {
        "id" = 4
        "title" = "Network Traffic"
        "type" = "graph"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])"
            "legendFormat" = "{{instance}} - received"
          },
          {
            "expr" = "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])"
            "legendFormat" = "{{instance}} - transmitted"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 12, "y" = 8 }
      },
      {
        "id" = 5
        "title" = "App Memory Usage"
        "type" = "graph"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "node_memory_rss_bytes"
            "legendFormat" = "{{instance}} - RSS"
          },
          {
            "expr" = "node_memory_heap_used_bytes"
            "legendFormat" = "{{instance}} - Heap"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 0, "y" = 16 }
      },
      {
        "id" = 6
        "title" = "App Uptime"
        "type" = "stat"
        "datasource" = "Prometheus"
        "targets" = [
          {
            "expr" = "node_uptime_seconds"
            "legendFormat" = "{{instance}}"
          }
        ]
        "gridPos" = { "h" = 8, "w" = 12, "x" = 12, "y" = 16 }
      }
    ]
    "refresh" = "5s"
    "schemaVersion" = 30
    "style" = "dark"
    "tags" = ["aws", "infrastructure", "auto-generated"]
    "templating" = { "list" = [] }
    "time" = {
      "from" = "now-6h"
      "to" = "now"
    }
    "timepicker" = {}
    "timezone" = "browser"
    "title" = "AWS Infrastructure Dashboard"
    "uid" = "aws-infra"
    "version" = 1
  })

  cloud_init = <<-EOF
    #!/bin/bash
    set -e

    # System update
    yum update -y

    # Install Docker
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Install AWS CLI
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws

    # Install Node Exporter
    curl -L "https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz" -o /tmp/node_exporter.tar.gz
    tar xzf /tmp/node_exporter.tar.gz -C /tmp
    cp /tmp/node_exporter-*/node_exporter /usr/local/bin/
    chmod +x /usr/local/bin/node_exporter
    rm -rf /tmp/node_exporter*

    useradd --no-create-home --shell /bin/false node_exporter

    cat > /etc/systemd/system/node_exporter.service << 'SERVICE'
    [Unit]
    Description=Node Exporter
    After=network.target

    [Service]
    User=node_exporter
    Group=node_exporter
    Type=simple
    ExecStart=/usr/local/bin/node_exporter
    Restart=always

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    # Create Prometheus directories
    mkdir -p /opt/monitoring/prometheus/data
    mkdir -p /opt/monitoring/prometheus/config
    mkdir -p /opt/monitoring/grafana/provisioning/dashboards
    mkdir -p /opt/monitoring/grafana/provisioning/datasources
    chown -R ec2-user:ec2-user /opt/monitoring

    # Write Prometheus configuration
    cat > /opt/monitoring/prometheus/config/prometheus.yml << 'PROMYML'
    ${local.prometheus_yml}
    PROMYML

    # Write Grafana configuration
    cat > /opt/monitoring/grafana/grafana.ini << 'GRAFANAINI'
    ${local.grafana_ini}
    GRAFANAINI

    # Write Grafana datasource provisioning
    cat > /opt/monitoring/grafana/provisioning/datasources/datasource.yml << 'DSYML'
    ${local.grafana_datasource_yml}
    DSYML

    # Write Grafana dashboard provisioning
    cat > /opt/monitoring/grafana/provisioning/dashboards/dashboards.yml << 'DASHYML'
    ${local.grafana_dashboard_yml}
    DASHYML

    # Write Grafana dashboard
    cat > /opt/monitoring/grafana/provisioning/dashboards/aws-infra.json << 'DASHJSON'
    ${local.grafana_dashboard_json}
    DASHJSON

    # Write docker-compose for monitoring stack
    cat > /opt/monitoring/docker-compose.yml << 'COMPOSE'
    version: '3.8'

    services:
      prometheus:
        image: prom/prometheus:v2.48.0
        container_name: prometheus
        volumes:
          - ./prometheus/config/prometheus.yml:/etc/prometheus/prometheus.yml
          - ./prometheus/data:/prometheus
        command:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
          - '--storage.tsdb.retention.time=30d'
          - '--web.console.libraries=/etc/prometheus/console_libraries'
          - '--web.console.templates=/etc/prometheus/consoles'
          - '--web.enable-lifecycle'
        ports:
          - "9090:9090"
        restart: always
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

      grafana:
        image: grafana/grafana:10.2.0
        container_name: grafana
        volumes:
          - ./grafana/grafana.ini:/etc/grafana/grafana.ini
          - ./grafana/provisioning:/etc/grafana/provisioning
          - grafana-data:/var/lib/grafana
        ports:
          - "3000:3000"
        restart: always
        depends_on:
          - prometheus
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"

    volumes:
      grafana-data:
    COMPOSE

    # Start monitoring stack
    cd /opt/monitoring
    docker compose up -d

    echo "Monitoring stack deployed successfully"
    echo "Grafana: http://<public-ip>:3000 (admin/admin)"
    echo "Prometheus: http://<public-ip>:9090"
  EOF
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = var.private_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  vpc_security_group_ids = [var.monitoring_security_group_id]

  associate_public_ip_address = true

  user_data = base64encode(local.cloud_init)

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring"
  }
}

resource "aws_eip_association" "monitoring" {
  instance_id   = aws_instance.monitoring.id
  allocation_id = aws_eip.monitoring.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
