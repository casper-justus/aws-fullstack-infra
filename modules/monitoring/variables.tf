variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "monitoring_security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

variable "app_instance_ips" {
  type = list(string)
}
