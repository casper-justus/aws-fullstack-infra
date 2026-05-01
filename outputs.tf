output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "app_public_ips" {
  description = "Public IPs of app instances"
  value       = module.ec2.app_public_ips
}

output "monitoring_public_ip" {
  description = "Public IP of monitoring server (Grafana:3000, Prometheus:9090)"
  value       = module.monitoring.monitoring_public_ip
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_name
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${module.monitoring.monitoring_public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${module.monitoring.monitoring_public_ip}:9090"
}
