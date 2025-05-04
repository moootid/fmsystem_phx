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
  default     = "fmsystem-ecs"
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
  validation {
    condition     = var.public_subnet_count >= 2
    error_message = "At least 2 public subnets are recommended for ALB high availability."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets for internal resources (DB, ECS Tasks)."
  type        = number
  default     = 2
  validation {
    condition     = var.private_subnet_count >= 2
    error_message = "At least 2 private subnets are recommended for high availability."
  }
}

variable "ssh_access_cidr" {
  description = "CIDR block allowed for SSH access to the DB instance (e.g. YOUR_IP/32)."
  type        = string
}

##############################
# Database (EC2) Settings (Unchanged)
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
  description = "Target CPU utilization (%) to trigger DB scale-up (only relevant if max_size > 1)."
  type        = number
  default     = 70.0
}

variable "db_disable_scale_in" {
  description = "Prevent DB ASG from scaling in or terminating unhealthy instances (recommended for stateful single instance)."
  type        = bool
  default     = true
}

variable "db_image_name" {
  description = "Docker image name for TimescaleDB."
  type        = string
  default     = "timescale/timescaledb-ha:pg16"
}

##############################
# Docker Hub Settings (Unchanged)
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
  description = "Docker Hub email address (often optional for login)."
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

##############################
# ECS Application Settings (Replaces EC2 App Settings)
##############################
variable "app_container_port" {
  description = "Port on which the application container listens."
  type        = number
  default     = 4000
}

variable "app_log_retention_days" {
  description = "Number of days to retain application logs in CloudWatch."
  type        = number
  default     = 7
}

variable "app_task_cpu" {
  description = "CPU units allocated to the ECS task (1024 = 1 vCPU)."
  # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  type        = number
  default     = 1024 # Example: 1 vCPU
}

variable "app_task_memory" {
  description = "Memory (in MiB) allocated to the ECS task."
  # Must be a valid value for the chosen CPU units.
  type        = number
  default     = 2048 # Example: 2 GiB
}

##############################
# ECS Auto Scaling Settings (Application)
##############################
variable "app_desired_count" {
  description = "Initial desired number of application tasks."
  type        = number
  default     = 2
}

variable "app_asg_min_capacity" {
  description = "Minimum number of application tasks for Auto Scaling."
  type        = number
  default     = 2
}

variable "app_asg_max_capacity" {
  description = "Maximum number of application tasks for Auto Scaling."
  type        = number
  default     = 10 # Adjust based on expected load
}

variable "app_cpu_target_value" {
  description = "Target average CPU utilization (%) for ECS task auto scaling."
  type        = number
  default     = 60.0
}

variable "app_memory_target_value" {
  description = "Target average memory utilization (%) for ECS task auto scaling."
  type        = number
  default     = 75.0
}

variable "app_scale_in_cooldown" {
  description = "Cooldown period (in seconds) after a scale-in activity."
  type        = number
  default     = 30 # 0.5 minute
}

variable "app_scale_out_cooldown" {
  description = "Cooldown period (in seconds) after a scale-out activity."
  type        = number
  default     = 120 # 2 minutes
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


# Removed EC2 specific variables:
# - app_ec2_key_pair_name
# - app_instance_type
# - app_instance_volume_size_gb
# - sleep_interval
# - max_retries
# - watchtower_poll_interval
# - app_asg_min_size (renamed)
# - app_asg_max_size (renamed)
# - app_asg_desired_count (renamed)
