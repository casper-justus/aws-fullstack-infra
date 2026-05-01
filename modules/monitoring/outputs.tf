output "monitoring_public_ip" {
  description = "Elastic IP of the monitoring server"
  value       = aws_eip.monitoring.public_ip
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_eip.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_eip.monitoring.public_ip}:9090"
}
