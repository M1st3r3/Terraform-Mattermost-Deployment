# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Generate a new RSA key
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the AWS key pair
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = var.key_name  
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Save the private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/${var.key_name}"

  # Set appropriate permissions for the key file
  provisioner "local-exec" {
    command = "chmod 400 ${path.module}/${var.key_name}"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mattermost-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "mattermost-igw"
  }
}

# Subnet public
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "mattermost-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "mattermost-rt"
  }
}

# Association de la Route Table avec le subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "server_sg" {
  name        = "mattermost-sg"
  description = "Security group for Mattermost server"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mattermost-sg"
  }
}

# EC2 Instance
resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.server_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "mattermost-server"
  }

  provisioner "local-exec" {
    command = "touch inventory"
  }
}

# Elastic IP
resource "aws_eip" "server_eip" {
  instance = aws_instance.server.id
  domain   = "vpc"
}

#Creation du fichier inventory
resource "local_file" "inventory" {
  content = data.template_file.inventory.rendered
  filename = "inventory"
}

data "template_file" "inventory" {
  template = <<-EOT
  [mattermost]
  ${aws_eip.server_eip.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${path.module}/${var.key_name}
  EOT

  depends_on = [aws_eip.server_eip]
}

#Lancement du script Ansible
resource "null_resource" "connect_ansible_hosts" {
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/${var.key_name}")
    host        = "${aws_eip.server_eip.public_ip}"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is Getting Ready for ansible'"
    ]
  }
  provisioner "local-exec" {
    command = "ansible-playbook -i inventory playbook.yml"
    working_dir = path.module
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }
  }
}

# Outputs
output "public_ip" {
  value = aws_eip.server_eip.public_ip
}


output "ssh_connection" {
  value = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.server_eip.public_ip}"
}





