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
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
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
  })

  # Construct the full image name for the application container
  app_image_uri = "${var.dockerhub_username}/${var.app_image_name}:${var.app_image_tag}"

  dockerhub_secret_arn = aws_secretsmanager_secret.dockerhub_creds.arn
}

############################################################
# VPC & Networking
############################################################

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-vpc-${var.environment}"
  })
}

# Public Subnets (across different AZs)
resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-public-subnet-${var.environment}-${count.index}"
  })
}

# Private Subnets (for the DB instance)
resource "aws_subnet" "private" {
  count                   = var.private_subnet_count
  vpc_id                  = aws_vpc.main.id
  # Offset subnet indices so private subnets don’t overlap with public
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + var.public_subnet_count)
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-private-subnet-${var.environment}-${count.index}"
  })
}

# Internet Gateway for VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-igw-${var.environment}"
  })
}

# Public Route Table and its association
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

# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = merge(local.common_tags, {
    Name = "${var.app_name}-nat-eip-${var.environment}"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.common_tags, {
    Name = "${var.app_name}-natgw-${var.environment}"
  })
}

# Private Route Table and associations (all outbound traffic goes via NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.app_name}-private-rt-${var.environment}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

############################################################
# Security Groups
############################################################

# ALB Security Group - allow inbound HTTP and HTTPS traffic
resource "aws_security_group" "alb_sg" {
  name        = "${var.app_name}-alb-sg-${var.environment}"
  description = "Allow HTTP/HTTPS traffic to ALB for ${var.app_name}-${var.environment}"
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
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-alb-sg-${var.environment}"
  })
}

# Security Group for Elixir Application EC2 Instances - allow traffic from the ALB on the app port
resource "aws_security_group" "app_sg" {
  name        = "${var.app_name}-app-sg-${var.environment}"
  description = "Allow traffic to app instances on port ${var.app_container_port} from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.app_container_port
    to_port         = var.app_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-app-sg-${var.environment}"
  })
}

# Database EC2 Security Group - allow PostgreSQL from application instances and SSH access
resource "aws_security_group" "db_sg" {
  name        = "${var.app_name}-db-sg-${var.environment}"
  description = "Allow DB traffic for ${var.app_name}-${var.environment} from app instances and SSH from a specific CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${var.app_name}-db-sg-${var.environment}"
  })
}

# Extra rule: from app instances to DB (egress on app SG)
resource "aws_security_group_rule" "app_to_db" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db_sg.id
  security_group_id        = aws_security_group.app_sg.id
  description              = "Allow app instances to connect to DB"
}

############################################################
# Database (EC2 with Docker + TimescaleDB) & Auto Scaling
############################################################

# IAM Role for DB Instance (for SSM access)
resource "aws_iam_role" "db_instance_role" {
  name = "${var.app_name}-db-instance-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "db_ssm_policy" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "db_instance_profile" {
  name = "${var.app_name}-db-instance-profile-${var.environment}"
  role = aws_iam_role.db_instance_role.name
  tags = local.common_tags
}

# User Data for the DB instance: installs Docker, mounts the EBS volume, and runs the TimescaleDB container.
data "template_file" "db_user_data" {
  template = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user

    EBS_DEVICE="/dev/xvdf"
    MOUNT_POINT="/data/postgres"
    while [ ! -e $EBS_DEVICE ]; do echo "Waiting for EBS volume ($EBS_DEVICE)"; sleep 5; done
    if ! file -s $EBS_DEVICE | grep -q filesystem; then
      echo "Formatting $EBS_DEVICE"
      mkfs -t xfs $EBS_DEVICE
    fi
    mkdir -p $MOUNT_POINT
    mount $EBS_DEVICE $MOUNT_POINT
    UUID=$(blkid -s UUID -o value $EBS_DEVICE)
    echo "UUID=$UUID  $MOUNT_POINT  xfs  defaults,nofail  0  2" >> /etc/fstab
    chown -R 999:999 $MOUNT_POINT

    docker run -d \
      --name timescaledb \
      -p 5432:5432 \
      -v $MOUNT_POINT:/var/lib/postgresql/data \
      -e POSTGRES_USER=${var.db_user} \
      -e POSTGRES_PASSWORD=${var.db_password} \
      -e POSTGRES_DB=${var.db_name} \
      --restart always \
      ${var.db_image_name} \
      postgres -c max_connections=1000 \
          -c shared_buffers=512MB \
          -c work_mem=4MB \
          -c maintenance_work_mem=64MB
    echo "Database setup complete."
  EOF

  vars = {
    db_user       = var.db_user,
    db_password   = var.db_password,
    db_name       = var.db_name,
    db_image_name = var.db_image_name
  }
}

# Launch Template for the DB instance (with persistent EBS volume).
resource "aws_launch_template" "db_lt" {
  name_prefix   = "${var.app_name}-db-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.db_instance_type
  key_name      = var.db_ec2_key_pair_name

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.db_instance_profile.name
  }

  user_data = base64encode(data.template_file.db_user_data.rendered)

  block_device_mappings {
    device_name = "/dev/xvdf"
    ebs {
      volume_size           = var.db_volume_size_gb
      delete_on_termination = false
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.app_name}-db-instance-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for the DB instance (launched into private subnets).
resource "aws_autoscaling_group" "db_asg" {
  name_prefix         = "${var.app_name}-db-asg-${var.environment}-"
  vpc_zone_identifier = aws_subnet.private[*].id

  desired_capacity = var.db_asg_desired_capacity
  min_size         = var.db_asg_min_size
  max_size         = var.db_asg_max_size

  launch_template {
    id      = aws_launch_template.db_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = { for key, value in merge(local.common_tags, { Name = "${var.app_name}-db-instance-${var.environment}" }) : key => value }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Auto Scaling Policy for the DB instance (target tracking CPU utilization)
resource "aws_autoscaling_policy" "db_target_tracking" {
  name                    = "${var.app_name}-db-target-tracking-${var.environment}"
  autoscaling_group_name  = aws_autoscaling_group.db_asg.name
  policy_type             = "TargetTrackingScaling"
  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.db_cpu_target_high
  }
}

# Data source to obtain the private IP address of the DB instance for the application
data "aws_instance" "db_instance" {
  filter {
    name   = "tag:Name"
    values = ["${var.app_name}-db-instance-${var.environment}"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running", "pending"]
  }
  depends_on = [aws_autoscaling_group.db_asg]
}

############################################################
# Secrets Manager for Docker Hub Credentials
############################################################

resource "random_id" "secret_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "dockerhub_creds" {
  name        = "${var.app_name}/${var.environment}/dockerhub-creds-${random_id.secret_suffix.hex}"
  description = "Docker Hub credentials for ${var.app_name} ${var.environment}"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds_version" {
  secret_id     = aws_secretsmanager_secret.dockerhub_creds.id
  secret_string = jsonencode({
    username = var.dockerhub_username,
    password = var.dockerhub_password,
    email    = var.dockerhub_email
  })
}

############################################################
# Application (Elixir) on EC2
############################################################

# User Data for the Application instance that installs Docker and runs the Elixir container.
data "template_file" "app_user_data" {
  template = <<-EOF
    #!/bin/bash -xe
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    amazon-linux-extras install docker -y
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    yum install -y nmap-ncat
    sleep 30
    docker login -u "${var.dockerhub_username}" -p "${var.dockerhub_password}" docker.io
    # Wait for the DB to be available
    max_retries=${var.max_retries}
    sleep_interval=${var.sleep_interval}
    attempt=1
    echo "Checking DB availability at ${data.aws_instance.db_instance.private_ip}:5432"
    until nc -z ${data.aws_instance.db_instance.private_ip} 5432 || [ $attempt -ge $max_retries ]; do
      echo "Attempt $attempt: DB not ready, waiting ${var.sleep_interval} seconds..."
      sleep ${var.sleep_interval}
      attempt=$((attempt+1))
    done

    # Final check: if DB still not open, exit with error
    if ! nc -z ${data.aws_instance.db_instance.private_ip} 5432; then
      echo "DB still not available after ${var.max_retries} attempts, exiting..."
      exit 1
    fi

    echo "DB is ready; starting the application container."
    docker run -d \
      --name elixir_app  \
      -p ${var.app_container_port}:${var.app_container_port} \
      -e MIX_ENV=prod \
      -e DATABASE_URL="ecto://${var.db_user}:${var.db_password}@${data.aws_instance.db_instance.private_ip}:5432/${var.db_name}" \
      -e DB_USER="${var.db_user}" \
      -e DB_PASSWORD="${var.db_password}" \
      -e DB_HOST="${data.aws_instance.db_instance.private_ip}" \
      -e DB_PORT="5432" \
      -e DB_NAME="${var.db_name}" \
      -e SECRET_KEY_BASE="${var.secret_key_base_value}" \
      -e JWT_SECRET="${var.jwt_secret_value}" \
      -e JWT_SECRET_KEY="${var.jwt_secret_value}" \
      -e SESSION_SIGNING_SALT="${var.session_signing_salt_value}" \
      -e SESSION_ENCRYPTION_SALT="${var.session_encryption_salt_value}" \
      --restart always \
      ${local.app_image_uri}
    
    echo "Elixir application container started."

    # Start Watchtower to automatically update containers (e.g., the Elixir app).
    docker run -d \
      --name watchtower \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -e WATCHTOWER_CLEANUP=true \
      -e WATCHTOWER_POLL_INTERVAL="${var.watchtower_poll_interval}" \
      -e REPO_USER="${var.dockerhub_username}" \
      -e REPO_PASS="${var.dockerhub_password}" \
      --restart always \
      containrrr/watchtower

    echo "Watchtower started."
  EOF

  vars = {
    app_container_port = var.app_container_port,
    db_user            = var.db_user,
    db_password        = var.db_password,
    db_name            = var.db_name
  }
}

# Security Group for Application instances is defined earlier as aws_security_group.app_sg.

# Launch Template for the Application instance.
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.app_name}-app-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.app_instance_type
  key_name      = var.app_ec2_key_pair_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(data.template_file.app_user_data.rendered)

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.app_instance_volume_size_gb
      delete_on_termination = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.app_name}-app-instance-${var.environment}"
  })
}

# Auto Scaling Group for Application instances (launched into public subnets)
resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "${var.app_name}-app-asg-${var.environment}-"
  vpc_zone_identifier = aws_subnet.public[*].id
  desired_capacity    = var.app_asg_desired_count
  min_size            = var.app_asg_min_size
  max_size            = var.app_asg_max_size

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.app_name}-app-instance-${var.environment}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_target_tracking" {
  name                     = "${var.app_name}-app-target-tracking-${var.environment}"
  autoscaling_group_name   = aws_autoscaling_group.app_asg.name
  policy_type              = "TargetTrackingScaling"
  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value       = var.app_cpu_target_value
  }
}

############################################################
# Application Load Balancer
############################################################

resource "aws_lb" "app_alb" {
  name               = "${var.app_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
  tags               = merge(local.common_tags, { Name = "${var.app_name}-alb-${var.environment}" })
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.app_name}-tg-${var.environment}"
  port        = var.app_container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  # ——————————————— Health check on /api/health ———————————————
  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  
  tags = merge(local.common_tags, { Name = "${var.app_name}-tg-${var.environment}" })
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

############################################################
# ACM Certificate & DNS Validation for fmsystem.mokh32.com
############################################################

resource "aws_acm_certificate" "app_cert" {
  domain_name       = "fmsystem.mokh32.com"
  validation_method = "DNS"
  tags              = local.common_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name,
      type   = dvo.resource_record_type,
      record = dvo.resource_record_value
    }
  }
  zone_id = "Z0214201DZ82Y2OWY29K"
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route 53 DNS record to map fmsystem.mokh32.com to the ALB
resource "aws_route53_record" "app_domain" {
  zone_id = "Z0214201DZ82Y2OWY29K"
  name    = "fmsystem"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

# ALB HTTPS Listener using the validated ACM certificate
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.app_cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

############################################################
# Outputs
############################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "db_instance_private_ip" {
  description = "Private IP address of the DB EC2 instance (may change when replaced by the ASG)"
  value       = data.aws_instance.db_instance.private_ip
}

output "dockerhub_secret_arn_output" {
  description = "ARN of the Secrets Manager secret for Docker Hub credentials"
  value       = aws_secretsmanager_secret.dockerhub_creds.arn
}
