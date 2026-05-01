output "app_public_ips" {
  description = "ALB DNS name (primary access point)"
  value       = aws_lb.app.dns_name
}

output "app_instance_private_ips" {
  description = "ASG name for instance discovery"
  value       = [aws_autoscaling_group.app.name]
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.app.dns_name
}
