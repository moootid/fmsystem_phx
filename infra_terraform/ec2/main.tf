# Provider
provider "aws" {
  region = var.aws_region
}

############################################################
# Data Sources & Locals
############################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Or use Amazon Linux 2023
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = merge(var.tags, {
    Project     = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    DeployType  = "EC2"
  })

  # Construct DB connection string securely (password comes from Secrets Manager later)
  # The application reads DATABASE_URL env var
  db_connection_string_base = "ecto://${var.db_user}@${data.aws_instance.db_instance.private_ip}:5432/${var.db_name}"

  # Determine if Docker Hub creds are needed
  create_dockerhub_secret = var.dockerhub_username != "" && var.dockerhub_password != ""
}

############################################################
# VPC & Networking (Reused from Example)
############################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-vpc-${var.environment}"
  })
}

resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-public-subnet-${var.environment}-${count.index}"
  })
}

resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + var.public_subnet_count)
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-private-subnet-${var.environment}-${count.index}"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-igw-${var.environment}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-public-rt-${var.environment}"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  count = var.private_subnet_count > 0 ? 1 : 0 # Only create NAT if private subnets exist
  domain = "vpc"
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-nat-eip-${var.environment}"
  })
  depends_on = [aws_internet_gateway.igw] # Ensure IGW exists before EIP
}

resource "aws_nat_gateway" "nat" {
  count = var.private_subnet_count > 0 ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.public[0].id
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-natgw-${var.environment}"
  })
}

resource "aws_route_table" "private" {
  count = var.private_subnet_count > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-private-rt-${var.environment}"
  })
}

resource "aws_route_table_association" "private" {
  count          = var.private_subnet_count > 0 ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

############################################################
# Security Groups
############################################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.app_name}-alb-sg-${var.environment}"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { # Allow ALB to talk to targets
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.app_name}-alb-sg-${var.environment}" })
}

resource "aws_security_group" "app_ec2_sg" {
  name        = "${var.app_name}-app-ec2-sg-${var.environment}"
  description = "App EC2 Instance Security Group"
  vpc_id      = aws_vpc.main.id

  ingress { # Allow traffic from ALB on app port
    description     = "Allow App port from ALB"
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # NO SSH ingress needed usually, use SSM Session Manager via IAM role

  egress { # Allow outbound to DB, Secrets Manager, Docker Hub, etc. via NAT
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.app_name}-app-ec2-sg-${var.environment}" })
}

resource "aws_security_group" "db_sg" {
  name        = "${var.app_name}-db-sg-${var.environment}"
  description = "DB EC2 Instance Security Group"
  vpc_id      = aws_vpc.main.id

  ingress { # Allow PostgreSQL from App instances
    description     = "Allow PostgreSQL from App EC2 SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_ec2_sg.id] # Reference app EC2 SG
  }

  ingress { # Allow SSH from specified CIDR (if key pair is provided)
    count       = var.ssh_access_cidr != "" ? 1 : 0
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }

  egress { # Allow DB to pull updates, etc. via NAT
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.app_name}-db-sg-${var.environment}" })
}

############################################################
# Database (EC2 - Reused from Example)
# Assuming DB stays on EC2 even if App goes to Fargate later
############################################################

# IAM Role for DB Instance (for SSM Session Manager access)
resource "aws_iam_role" "db_instance_role" {
  name = "${var.app_name}-db-ec2-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "db_ssm_policy" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "db_instance_profile" {
  name = "${var.app_name}-db-ec2-profile-${var.environment}"
  role = aws_iam_role.db_instance_role.name
  tags = local.common_tags
}

# User Data for DB (Installs Docker, Timescale)
data "template_file" "db_user_data" {
  template = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    # Using Amazon Linux 2 specific commands
    amazon-linux-extras install docker -y
    systemctl enable --now docker
    usermod -a -G docker ec2-user

    # Setup EBS Volume for data persistence
    EBS_DEVICE="/dev/xvdf" # Adjust if needed
    MOUNT_POINT="/data/postgres"
    # Wait for device, format if needed, mount, add to fstab
    while [ ! -e $EBS_DEVICE ]; do echo "Waiting for EBS volume ($EBS_DEVICE)"; sleep 5; done
    if ! file -s $EBS_DEVICE | grep -q filesystem; then
      echo "Formatting $EBS_DEVICE"; mkfs -t xfs $EBS_DEVICE
    fi
    mkdir -p $MOUNT_POINT; mount $EBS_DEVICE $MOUNT_POINT
    UUID=$(blkid -s UUID -o value $EBS_DEVICE); echo "UUID=$UUID  $MOUNT_POINT  xfs  defaults,nofail  0  2" >> /etc/fstab
    chown -R 999:999 $MOUNT_POINT # Set ownership for postgres user inside container

    # Run TimescaleDB container
    docker run -d \
      --name timescaledb \
      --network host \
      -v $MOUNT_POINT:/var/lib/postgresql/data \
      -e POSTGRES_USER=${db_user} \
      -e POSTGRES_PASSWORD=${db_password} \
      -e POSTGRES_DB=${db_name} \
      --restart always \
      ${db_image_name} \
      postgres -c max_connections=500 -c shared_buffers=256MB # Adjust tuning as needed
    echo "TimescaleDB container started."
  EOF

  vars = {
    db_user       = var.db_user
    db_password   = var.db_password # Note: Passing password here is less secure, consider secrets
    db_name       = var.db_name
    db_image_name = var.db_image_name
  }
}

# Launch Template for DB
resource "aws_launch_template" "db_lt" {
  name_prefix            = "${var.app_name}-db-lt-${var.environment}-"
  image_id               = data.aws_ami.amazon_linux_2.id
  instance_type          = var.db_instance_type
  key_name               = var.db_ec2_key_pair_name != "" ? var.db_ec2_key_pair_name : null
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  iam_instance_profile { name = aws_iam_instance_profile.db_instance_profile.name }
  user_data              = base64encode(data.template_file.db_user_data.rendered)

  block_device_mappings {
    device_name = "/dev/xvdf" # Match device in user_data script
    ebs {
      volume_size           = var.db_volume_size_gb
      delete_on_termination = false # Keep DB data
      encrypted             = true
      # volume_type = "gp3" # Consider gp3
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-db-instance-${var.environment}" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-db-volume-${var.environment}" })
  }
  lifecycle { create_before_destroy = true }
}

# Auto Scaling Group for DB (min/max=1 for single instance)
resource "aws_autoscaling_group" "db_asg" {
  name_prefix         = "${var.app_name}-db-asg-${var.environment}-"
  vpc_zone_identifier = aws_subnet.private[*].id # Launch in private subnets
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  launch_template {
    id      = aws_launch_template.db_lt.id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
  # Protect the single DB instance from termination during scale-in events
  protect_from_scale_in = true
  # Tags for the ASG itself and propagated to instances
  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${var.app_name}-db-instance-${var.environment}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Data source to get DB instance IP (relies on ASG creating instance with the Name tag)
data "aws_instance" "db_instance" {
  # Filter based on tags applied by the ASG
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-db-instance-${var.environment}"]
  }
  # Filter for running state
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  depends_on = [aws_autoscaling_group.db_asg]
}

############################################################
# Secrets Manager (Docker Hub + App Secrets)
############################################################

resource "random_password" "secret_suffix" {
  length  = 8
  special = false
}

# --- Docker Hub Secret (Optional) ---
resource "aws_secretsmanager_secret" "dockerhub_creds" {
  count       = local.create_dockerhub_secret ? 1 : 0
  name_prefix = "${var.app_name}-${var.environment}-dockerhub-creds-"
  description = "Docker Hub credentials for ${var.app_name} ${var.environment}"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds_version" {
  count         = local.create_dockerhub_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.dockerhub_creds[0].id
  secret_string = jsonencode({
    username = var.dockerhub_username,
    password = var.dockerhub_password # Store the sensitive password here
    # email    = var.dockerhub_email # Email often not strictly needed
  })
}

# --- Application Secrets ---
resource "aws_secretsmanager_secret" "app_secrets" {
  name_prefix = "${var.app_name}-${var.environment}-app-secrets-"
  description = "Application runtime secrets for ${var.app_name} ${var.environment}"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets_version" {
  secret_id     = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    DATABASE_URL              = "${local.db_connection_string_base}?password=${var.db_password}&ssl=false" # Construct full URL here, including password
    SECRET_KEY_BASE           = var.secret_key_base_value
    JWT_SECRET                = var.jwt_secret_value
    SESSION_SIGNING_SALT      = var.session_signing_salt_value
    SESSION_ENCRYPTION_SALT   = var.session_encryption_salt_value
    CORS_ALLOWED_ORIGINS      = var.cors_allowed_origins # Store CORS origins here too
    # Add any other application secrets needed
  })
  # Ensure DB instance exists before creating secret version that depends on its IP
  depends_on = [data.aws_instance.db_instance]
}

############################################################
# Application (Elixir) on EC2
############################################################

# --- IAM Role for App EC2 Instances ---
resource "aws_iam_role" "app_ec2_role" {
  name = "${var.app_name}-app-ec2-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = local.common_tags
}

# Policy to allow reading secrets and Docker Hub creds (if used)
resource "aws_iam_policy" "app_ec2_secrets_policy" {
  name_prefix = "${var.app_name}-app-ec2-secrets-policy-"
  description = "Allow EC2 instances to read app secrets"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          # "secretsmanager:DescribeSecret" # Optional
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret.app_secrets.arn,
        ]
      },
      # Add permission for Docker Hub secret if it's created
      local.create_dockerhub_secret ? {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = [
          aws_secretsmanager_secret.dockerhub_creds[0].arn,
        ]
      } : null # Conditional statement requires Terraform 0.12+
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_ec2_secrets_attach" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = aws_iam_policy.app_ec2_secrets_policy.arn
}

# Attach SSM policy for Session Manager access (preferred over SSH keys)
resource "aws_iam_role_policy_attachment" "app_ssm_policy" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_ec2_profile" {
  name = "${var.app_name}-app-ec2-profile-${var.environment}"
  role = aws_iam_role.app_ec2_role.name
  tags = local.common_tags
}


# --- User Data Script for App EC2 Instances ---
data "template_file" "app_user_data_ec2" {
  template = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    # Install necessary tools
    amazon-linux-extras install docker -y
    systemctl enable --now docker
    usermod -a -G docker ec2-user
    yum install -y nmap-ncat jq aws-cli # jq for parsing secrets, nc for DB check

    # Fetch secrets from Secrets Manager
    echo "Fetching application secrets from Secrets Manager..."
    SECRETS_JSON=$(aws secretsmanager get-secret-value --secret-id ${app_secrets_arn} --region ${aws_region} --query SecretString --output text)
    if [ -z "$SECRETS_JSON" ]; then
        echo "ERROR: Failed to fetch secrets from Secrets Manager. Exiting."
        exit 1
    fi

    # Extract individual secrets (adjust keys based on app_secrets_version content)
    DATABASE_URL=$(echo $SECRETS_JSON | jq -r .DATABASE_URL)
    SECRET_KEY_BASE=$(echo $SECRETS_JSON | jq -r .SECRET_KEY_BASE)
    JWT_SECRET=$(echo $SECRETS_JSON | jq -r .JWT_SECRET)
    SESSION_SIGNING_SALT=$(echo $SECRETS_JSON | jq -r .SESSION_SIGNING_SALT)
    SESSION_ENCRYPTION_SALT=$(echo $SECRETS_JSON | jq -r .SESSION_ENCRYPTION_SALT)
    CORS_ALLOWED_ORIGINS=$(echo $SECRETS_JSON | jq -r .CORS_ALLOWED_ORIGINS) # App needs this? If so, export it.

    # Export secrets so the docker run command can use them
    export DATABASE_URL SECRET_KEY_BASE JWT_SECRET SESSION_SIGNING_SALT SESSION_ENCRYPTION_SALT CORS_ALLOWED_ORIGINS

    # Optional: Docker Hub Login using Secrets Manager creds
    %{ if create_dockerhub_secret ~}
    echo "Attempting Docker Hub login..."
    DOCKER_CREDS_JSON=$(aws secretsmanager get-secret-value --secret-id ${dockerhub_secret_arn} --region ${aws_region} --query SecretString --output text)
    if [ -n "$DOCKER_CREDS_JSON" ]; then
        DOCKER_USER=$(echo $DOCKER_CREDS_JSON | jq -r .username)
        DOCKER_PASS=$(echo $DOCKER_CREDS_JSON | jq -r .password)
        echo $DOCKER_PASS | docker login --username $DOCKER_USER --password-stdin docker.io
        echo "Docker Hub login successful."
    else
        echo "WARNING: Docker Hub credentials secret not found or empty."
    fi
    %{ endif ~}

    # Wait for the DB (using nc, relies on DB instance IP being available via metadata or passed var)
    # Extract host/port from DATABASE_URL if available
    DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\(.*\):.*/\1/p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')

    if [[ -z "$DB_HOST" || -z "$DB_PORT" ]]; then
        echo "ERROR: Could not parse DB host/port from DATABASE_URL. Exiting."
        exit 1
    fi

    echo "Checking DB availability at ${DB_HOST}:${DB_PORT}..."
    max_retries=60 # Increased retries
    attempt=1
    until nc -z $DB_HOST $DB_PORT || [ $attempt -ge $max_retries ]; do
      echo "Attempt $attempt: DB not ready, waiting 5 seconds..."
      sleep 5
      attempt=$((attempt+1))
    done
    if ! nc -z $DB_HOST $DB_PORT; then
        echo "ERROR: DB did not become available after $max_retries attempts. Exiting."
        exit 1
    fi
    echo "DB is ready."

    # Pull latest image
    echo "Pulling application image: ${app_image_uri}"
    docker pull ${app_image_uri}

    # Run the application container, passing secrets as environment variables
    echo "Starting application container..."
    docker run -d \
      --name fmsystem_app \
      --network host \
      -p ${app_container_port}:${app_container_port} \
      -e PORT="${app_container_port}" \
      -e MIX_ENV="prod" \
      -e DATABASE_URL="$DATABASE_URL" \
      -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
      -e JWT_SECRET="$JWT_SECRET" \
      -e SESSION_SIGNING_SALT="$SESSION_SIGNING_SALT" \
      -e SESSION_ENCRYPTION_SALT="$SESSION_ENCRYPTION_SALT" \
      -e CORS_ALLOWED_ORIGINS="$CORS_ALLOWED_ORIGINS" \
      --restart always \
      ${app_image_uri}

    echo "Elixir application container started."

    # Optional: Start Watchtower
    %{ if watchtower_poll_interval > 0 ~}
    echo "Starting Watchtower..."
    # Note: Watchtower needs Docker Hub creds passed or via config file if image is private
    docker run -d \
      --name watchtower \
      -v /var/run/docker.sock:/var/run/docker.sock \
      --restart always \
      containrrr/watchtower \
      --interval ${watchtower_poll_interval} \
      --cleanup
    echo "Watchtower started."
    %{ endif ~}

    echo "User data script finished."
  EOF

  vars = {
    app_container_port    = var.app_container_port
    app_image_uri         = var.app_image_uri
    watchtower_poll_interval = var.watchtower_poll_interval
    app_secrets_arn       = aws_secretsmanager_secret.app_secrets.arn
    aws_region            = var.aws_region
    # Conditional vars for Docker Hub secret access
    create_dockerhub_secret = local.create_dockerhub_secret
    dockerhub_secret_arn  = local.create_dockerhub_secret ? aws_secretsmanager_secret.dockerhub_creds[0].arn : ""
  }
}

# --- Launch Template for App EC2 Instances ---
resource "aws_launch_template" "app_lt_ec2" {
  name_prefix            = "${var.app_name}-app-ec2-lt-${var.environment}-"
  image_id               = data.aws_ami.amazon_linux_2.id
  instance_type          = var.app_instance_type
  key_name               = var.app_ec2_key_pair_name != "" ? var.app_ec2_key_pair_name : null
  vpc_security_group_ids = [aws_security_group.app_ec2_sg.id]
  iam_instance_profile { name = aws_iam_instance_profile.app_ec2_profile.name }
  user_data              = base64encode(data.template_file.app_user_data_ec2.rendered)

  block_device_mappings {
    device_name = "/dev/xvda" # Standard root volume device name
    ebs {
      volume_size           = var.app_instance_volume_size_gb
      delete_on_termination = true
      encrypted             = true
      # volume_type = "gp3"
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-app-instance-${var.environment}" })
  }
  # depends_on = [aws_secretsmanager_secret_version.app_secrets_version] # Ensure secrets exist before LT uses them
}

# --- Auto Scaling Group for App EC2 Instances ---
resource "aws_autoscaling_group" "app_asg_ec2" {
  name_prefix         = "${var.app_name}-app-ec2-asg-${var.environment}-"
  vpc_zone_identifier = aws_subnet.public[*].id # Launch in public subnets for ALB
  desired_capacity    = var.app_asg_desired_count
  min_size            = var.app_asg_min_size
  max_size            = var.app_asg_max_size

  target_group_arns = [aws_lb_target_group.app_tg_ec2.arn] # Attach to EC2 Target Group

  launch_template {
    id      = aws_launch_template.app_lt_ec2.id
    version = "$Latest"
  }

  health_check_type         = "ELB" # Use ALB health checks
  health_check_grace_period = 300   # Give time for container to start & become healthy

  # Tags for the ASG itself and propagated to instances
  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${var.app_name}-app-instance-${var.environment}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# --- Auto Scaling Policy for App EC2 ASG ---
resource "aws_autoscaling_policy" "app_scaling_policy_ec2" {
  name                   = "${var.app_name}-app-ec2-scaling-policy-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.app_asg_ec2.name
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.app_cpu_target_value
  }
}

############################################################
# Application Load Balancer (ALB)
############################################################

resource "aws_lb" "app_alb" {
  name               = "${var.app_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id # ALB in public subnets
  enable_deletion_protection = false # Set to true for production safety
  tags               = merge(local.common_tags, { Name = "${var.app_name}-alb-${var.environment}" })
}

# --- Target Group for EC2 Instances ---
resource "aws_lb_target_group" "app_tg_ec2" {
  name        = "${var.app_name}-tg-ec2-${var.environment}"
  port        = var.app_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # Target EC2 instances

  health_check {
    path                = "/api/health" # Use specific health check path
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200" # Expect OK
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, { Name = "${var.app_name}-tg-ec2-${var.environment}" })
}

# --- ALB Listeners (HTTP & HTTPS) ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  # Redirect HTTP to HTTPS
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Or a newer policy
  certificate_arn   = aws_acm_certificate_validation.app_cert_validation.certificate_arn

  default_action { # Forward to the EC2 Target Group
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg_ec2.arn
  }
}

############################################################
# ACM Certificate & DNS (Reused from Example)
############################################################

resource "aws_acm_certificate" "app_cert" {
  domain_name       = var.app_domain_name
  validation_method = "DNS"
  tags              = local.common_tags
  lifecycle { create_before_destroy = true }
}

# Assumes Route 53 zone already exists and is managed elsewhere or via TF
data "aws_route53_zone" "selected" {
  # Use name or zone_id based on what's more stable
  # name         = trimsuffix(var.app_domain_name, ".") # Base domain name
  zone_id      = var.route53_zone_id # Use zone ID variable
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true # Required for Terraform 0.12 compatibility with ACM validation records
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route 53 Alias record pointing the custom domain to the ALB
resource "aws_route53_record" "app_domain_alias" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.app_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

############################################################
# Outputs
############################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "application_url" {
  description = "URL of the deployed application"
  value       = "https://${var.app_domain_name}"
}

output "db_instance_private_ip" {
  description = "Private IP address of the DB EC2 instance"
  value       = data.aws_instance.db_instance.private_ip
}

output "app_secrets_arn" {
  description = "ARN of the Secrets Manager secret containing application runtime secrets"
  value       = aws_secretsmanager_secret.app_secrets.arn
}