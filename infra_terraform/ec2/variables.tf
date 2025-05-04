##############################
# General AWS Settings
##############################
variable "aws_region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "eu-central-1"
}

##############################
# Project & Naming Settings
##############################
variable "app_name" {
  description = "Base name for the application and resources."
  type        = string
  default     = "fmsystem-ec2"
}

variable "environment" {
  description = "Deployment environment (e.g., production, staging, development)."
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
  description = "Number of public subnets to create across Availability Zones."
  type        = number
  default     = 2
}

# New variable for private subnets (for DB)
variable "private_subnet_count" {
  description = "Number of private subnets for internal resources like the DB."
  type        = number
  default     = 2
}

variable "ssh_access_cidr" {
  description = "CIDR block allowed for SSH access to the DB instance (e.g. YOUR_IP/32)."
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

variable "db_asg_min_size" {
  description = "Minimum number of DB instances in the ASG (use 1 for single-instance setups)."
  type        = number
  default     = 1
}

variable "db_asg_max_size" {
  description = "Maximum number of DB instances in the ASG."
  type        = number
  default     = 1
}

variable "db_asg_desired_capacity" {
  description = "Desired number of DB instances in the ASG."
  type        = number
  default     = 1
}

variable "db_cpu_target_high" {
  description = "Target CPU utilization (%) to trigger DB scale-up."
  type        = number
  default     = 70.0
}

variable "db_cpu_target_low" {
  description = "Target CPU utilization (%) to trigger DB scale-down."
  type        = number
  default     = 50.0
}

variable "db_disable_scale_in" {
  description = "Prevent DB ASG from scaling in (recommended for stateful single instance)."
  type        = bool
  default     = true
}

##############################
# Docker Hub Settings
##############################
variable "dockerhub_username" {
  description = "Docker Hub username."
  type        = string
}

variable "dockerhub_password" {
  description = "Docker Hub password or access token."
  type        = string
  sensitive   = true
}

variable "dockerhub_email" {
  description = "Docker Hub email address."
  type        = string
  sensitive   = true
}

variable "app_image_name" {
  description = "Name of the application Docker image (without tag or username)."
  type        = string
  default     = "fmsystem_phx"
}

variable "app_image_tag" {
  description = "Tag of the application Docker image to deploy."
  type        = string
  default     = "latest"
}

variable "app_image_uri" {
  description = "Full image URI for the application container (e.g., johnsmith/fmsystem:latest)"
  type        = string
  default     = "moootid/fmsystem_phx:latest"
}

variable "db_image_name" {
  description = "Docker image name for TimescaleDB."
  type        = string
  default     = "timescale/timescaledb:latest-pg16"
}

variable "watchtower_poll_interval" {
  description = "Poll interval in seconds for Watchtower to check for container updates."
  type        = number
  default     = 300  # Example value: 300 seconds (5 minutes)
}

##############################
# EC2 Application Settings
##############################
variable "app_ec2_key_pair_name" {
  description = "Name of the EC2 key pair for SSH access to the app instance."
  type        = string
}
variable "app_container_port" {
  description = "Port on which the application container listens."
  type        = number
  default     = 4000
}
variable "app_instance_type" {
  description = "EC2 instance type for hosting the Elixir application."
  type        = string
  default     = "c7a.large" # Change to "t3.medium" if you need more capacity
}

variable "app_instance_volume_size_gb" {
  description = "EBS volume size (in GB) for the EC2 instance hosting the Elixir application."
  type        = number
  default     = 20
}

variable "sleep_interval" {
  description = "Sleep interval (in seconds) for the application to wait before starting."
  type        = number
  default     = 30
}

variable "max_retries" {
  description = "Maximum number of retries for the application to start."
  type        = number
  default     = 100
}

##############################
# ECS Auto Scaling Settings (Application)
##############################
variable "app_asg_min_size" {
  description = "Minimum number of application EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "app_asg_max_size" {
  description = "Maximum number of application EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 10
}

variable "app_asg_desired_count" {
  description = "Initial desired number of application tasks."
  type        = number
  default     = 1
}

variable "app_cpu_target_value" {
  description = "Target average CPU utilization for ECS auto scaling (%)."
  type        = number
  default     = 50.0
}

variable "app_scale_in_cooldown" {
  description = "Cooldown period (in seconds) after scale-in."
  type        = number
  default     = 300
}

variable "app_scale_out_cooldown" {
  description = "Cooldown period (in seconds) after scale-out."
  type        = number
  default     = 60
}



##############################
# Application Secrets
##############################
variable "jwt_secret_value" {
  description = "Secret used to sign JWT tokens."
  type        = string
  sensitive   = true
}

variable "secret_key_base_value" {
  description = "Phoenix secret_key_base for signing and encryption."
  type        = string
  sensitive   = true
}

variable "cors_allowed_origins" {
  description = "Allowed CORS origins (e.g., comma‑separated list or '*')."
  type        = string
  default     = "*"
}

variable "session_encryption_salt_value" {
  description = "Salt used for Phoenix session encryption."
  type        = string
  sensitive   = true
}

variable "session_signing_salt_value" {
  description = "Salt used for Phoenix session signing."
  type        = string
  sensitive   = true
}
