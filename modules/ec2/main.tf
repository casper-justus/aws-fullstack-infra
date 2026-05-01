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

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

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
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "ssh" {
  name        = "${var.project_name}-${var.environment}-ssh-sg"
  description = "Allow SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ssh-sg"
  }
}

locals {
  cloud_init = <<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

    # Install AWS CLI v2
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws

    # Create app directory
    mkdir -p /opt/app
    chown ec2-user:ec2-user /opt/app

    # Write docker-compose.yml
    cat > /opt/app/docker-compose.yml << 'COMPOSE'
    version: '3.8'

    services:
      app:
        build:
          context: .
          dockerfile: Dockerfile
        ports:
          - "8000:8000"
        environment:
          - DATABASE_URL=postgresql://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}
          - AWS_S3_BUCKET=${var.s3_bucket_name}
          - NODE_ENV=production
        restart: always
        logging:
          driver: "json-file"
          options:
            max-size: "10m"
            max-file: "3"
        healthcheck:
          test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
          interval: 30s
          timeout: 10s
          retries: 3
          start_period: 40s
        deploy:
          resources:
            limits:
              cpus: '1'
              memory: 512M

    networks:
      default:
        driver: bridge
    COMPOSE

    # Write Dockerfile
    cat > /opt/app/Dockerfile << 'DOCKERFILE'
    FROM node:18-alpine

    WORKDIR /app

    RUN apk add --no-cache curl

    COPY package*.json ./
    RUN npm ci --only=production

    COPY src/ ./src/
    COPY server.js ./

    EXPOSE 8000

    USER node

    CMD ["node", "server.js"]
    DOCKERFILE

    # Write application source
    mkdir -p /opt/app/src
    cat > /opt/app/src/app.js << 'APPJS'
    const http = require('http');
    const os = require('os');

    const PORT = process.env.PORT || 8000;

    const server = http.createServer((req, res) => {
      if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          status: 'healthy',
          timestamp: new Date().toISOString(),
          hostname: os.hostname(),
          uptime: process.uptime(),
          memory: process.memoryUsage()
        }));
        return;
      }

      if (req.url === '/metrics') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        const memUsage = process.memoryUsage();
        const metrics = [
          '# HELP node_memory_rss_bytes Process RSS memory in bytes',
          '# TYPE node_memory_rss_bytes gauge',
          `node_memory_rss_bytes ${memUsage.rss}`,
          '# HELP node_memory_heap_total_bytes Process heap total in bytes',
          '# TYPE node_memory_heap_total_bytes gauge',
          `node_memory_heap_total_bytes ${memUsage.heapTotal}`,
          '# HELP node_memory_heap_used_bytes Process heap used in bytes',
          '# TYPE node_memory_heap_used_bytes gauge',
          `node_memory_heap_used_bytes ${memUsage.heapUsed}`,
          '# HELP node_uptime_seconds Process uptime in seconds',
          '# TYPE node_uptime_seconds gauge',
          `node_uptime_seconds ${process.uptime()}`,
          '# HELP http_requests_total Total HTTP requests',
          '# TYPE http_requests_total counter',
          `http_requests_total{method="${req.method}",path="${req.url}"} 1`
        ].join('\n') + '\n';
        res.end(metrics);
        return;
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        message: 'Welcome to the Fullstack App',
        environment: process.env.NODE_ENV || 'development',
        hostname: os.hostname(),
        timestamp: new Date().toISOString()
      }));
    });

    server.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
    APPJS

    # Write package.json
    cat > /opt/app/package.json << 'PACKAGE'
    {
      "name": "fullstack-app",
      "version": "1.0.0",
      "description": "Dockerized application for AWS deployment",
      "main": "server.js",
      "scripts": {
        "start": "node server.js"
      },
      "dependencies": {},
      "engines": {
        "node": ">=18.0.0"
      }
    }
    PACKAGE

    # Write server.js entrypoint
    cat > /opt/app/server.js << 'SERVERJS'
    require('./src/app.js');
    SERVERJS

    # Install Node Exporter for Prometheus
    curl -L "https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz" -o /tmp/node_exporter.tar.gz
    tar xzf /tmp/node_exporter.tar.gz -C /tmp
    cp /tmp/node_exporter-*/node_exporter /usr/local/bin/
    chmod +x /usr/local/bin/node_exporter
    rm -rf /tmp/node_exporter*

    # Create node_exporter systemd service
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

    useradd --no-create-home --shell /bin/false node_exporter
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    # Deploy the application
    cd /opt/app
    docker compose up -d --build

    echo "Application deployed successfully"
  EOF
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [
    var.app_security_group_id,
    aws_security_group.ssh.id
  ]

  user_data = base64encode(local.cloud_init)

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-app"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-${var.environment}-app"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-lt"
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-app-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-app"
    propagate_at_launch = true
  }
}

resource "aws_lb" "app" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.app_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "8000"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
