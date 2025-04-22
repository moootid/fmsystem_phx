##############################
# General AWS Settings
##############################
variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

##############################
# Project & Naming Settings
##############################
variable "app_name" {
  description = "Base name for the application and resources."
  type        = string
  default     = "fmsystem"
}

variable "environment" {
  description = "Deployment environment (e.g., production, staging)."
  type        = string
  default     = "production"
}

variable "tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

##############################
# Networking Settings
##############################
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public subnets."
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets for the DB."
  type        = number
  default     = 2
}

variable "ssh_access_cidr" {
  description = "CIDR block allowed for SSH access to the DB instance (e.g., YOUR_IP/32)."
  type        = string
}

##############################
# Database (EC2) Settings
##############################
variable "db_instance_type" {
  description = "EC2 instance type for the database."
  type        = string
  default     = "t3.medium"
}

variable "db_volume_size_gb" {
  description = "Size of the EBS volume for database data in GB."
  type        = number
  default     = 20
}

variable "db_user" {
  description = "Username for the database."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Password for the database user."
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database to create."
  type        = string
  default     = "fmsystem_prod"
}

variable "db_ec2_key_pair_name" {
  description = "Name of the EC2 key pair for SSH access to the DB instance."
  type        = string
}

variable "db_image_name" {
  description = "Docker image name for TimescaleDB."
  type        = string
  default     = "timescale/timescaledb-ha:pg16" # Check for latest appropriate tag
}

##############################
# Application Secrets (Values needed at apply time)
##############################
variable "secret_key_base_value" {
  description = "Phoenix SECRET_KEY_BASE value (generate with mix phx.gen.secret 64)."
  type        = string
  sensitive   = true
}

variable "jwt_secret_value" {
  description = "Secret key for signing JWT tokens (generate a long random string)."
  type        = string
  sensitive   = true
}

variable "session_signing_salt_value" {
  description = "Phoenix session signing salt (generate with mix phx.gen.secret 32)."
  type        = string
  sensitive   = true
}

variable "session_encryption_salt_value" {
  description = "Phoenix session encryption salt (generate with mix phx.gen.secret 32)."
  type        = string
  sensitive   = true
}

##############################
# Docker Hub Settings (Optional - if image is private)
##############################
variable "dockerhub_username" {
  description = "Docker Hub username (only needed if image is private)."
  type        = string
  default     = ""
}

variable "dockerhub_password" {
  description = "Docker Hub password or access token (only needed if image is private)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "dockerhub_email" {
  description = "Docker Hub email address (required by older docker login)."
  type        = string
  sensitive   = true
  default     = "email@example.com" # Can often be dummy value
}

##############################
# Application Container Settings
##############################
variable "app_image_uri" {
  description = "Full image URI for the application container (e.g., yourdockerhubuser/fmsystem:latest)."
  type        = string
  # Replace with your actual image URI
  default     = "moootid/fmsystem:latest"
}

variable "app_container_port" {
  description = "Port on which the application container listens."
  type        = number
  default     = 4000
}

variable "cors_allowed_origins" {
  description = "Comma-separated list of allowed origins for CORS (e.g., 'https://frontend.com,https://admin.com'). Use '*' for dev only."
  type        = string
  default     = "*"
}

variable "watchtower_poll_interval" {
  description = "Poll interval in seconds for Watchtower (0 to disable)."
  type        = number
  default     = 300
}

##############################
# EC2 Application Settings (Specific to this file)
##############################
variable "app_ec2_key_pair_name" {
  description = "Name of the EC2 key pair for SSH access to the app instances."
  type        = string
}

variable "app_instance_type" {
  description = "EC2 instance type for hosting the Elixir application."
  type        = string
  default     = "t3.medium" # Adjust as needed
}

variable "app_instance_volume_size_gb" {
  description = "EBS volume size (in GB) for the EC2 app instances."
  type        = number
  default     = 20
}

variable "app_asg_min_size" {
  description = "Minimum number of application EC2 instances."
  type        = number
  default     = 1 # Start with 1 for testing
}

variable "app_asg_max_size" {
  description = "Maximum number of application EC2 instances."
  type        = number
  default     = 3
}

variable "app_asg_desired_count" {
  description = "Initial desired number of application EC2 instances."
  type        = number
  default     = 1
}

variable "app_cpu_target_value" {
  description = "Target average CPU utilization (%) for EC2 ASG scaling."
  type        = number
  default     = 60.0
}

##############################
# ACM/DNS Settings
##############################
variable "app_domain_name" {
  description = "The custom domain name for the application (e.g., fmsystem.yourdomain.com)."
  type        = string
  # Replace with your desired domain
  default     = "fmsystem.mokh32.com"
}

variable "route53_zone_id" {
  description = "The Route 53 Hosted Zone ID for the app_domain_name."
  type        = string
  # Replace with your actual Hosted Zone ID
  default     = "Z0214201DZ82Y2OWY29K"
}