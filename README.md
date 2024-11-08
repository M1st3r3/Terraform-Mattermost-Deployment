# Table
- [Mattermost AWS Automation](#mattermost-aws-automation)
  1. [Features](#features)
  2. [Requirements](#requirements)
  2. [Key Components](#key-components)
  3. [Usage](#usage)
- [Prerequisites](#prerequisites)
- [Automatic Deployment of an EC2 Instance with Terraform](#automatic-deployment-of-an-ec2-instance-with-terraform)
  1. [variables.tf File](#variablestf-file)
  2. [terraform.tfvars File](#terraformtfvars-file)
  3. [main.tf File](#maintf-file)
- [Automatic Deployment of Mattermost](#automatic-deployment-of-mattermost)
  1. [Deployment with Bash Script](#deployment-with-bash-script)
  2. [Deployment with an Ansible Playbook](#deployment-with-an-ansible-playbook)
- [Complete Automation of Mattermost Installation with HTTPS](#complete-automation-of-mattermost-installation-with-https)
  1. [Project Structure](#project-structure)
  2. [Key Modifications](#key-modifications)
  3. [Usage](#usage)

## Mattermost AWS Automation
This repository contains a comprehensive set of scripts and configurations for automating the deployment of Mattermost on AWS using Terraform and Ansible. It provides a streamlined, reproducible process for setting up a production-ready Mattermost instance with HTTPS support.

### Features
- Automated EC2 instance deployment using Terraform
- Mattermost installation and configuration using Ansible
- HTTPS setup with Let's Encrypt
- Dynamic DNS update with No-IP
- Docker-based Mattermost deployment
- Nginx reverse proxy configuration

### Requirements

To reproduce this project, you'll need:

1. An AWS account
2. A Dynamic DNS hostname from noip.com

**Note:** This project can be reproduced at no cost, as it uses an EC2 instance eligible for the AWS Free Tier. Additionally, noip.com offers one free hostname.

### Key Components
- Terraform scripts for AWS infrastructure setup
- Ansible playbook for Mattermost deployment and configuration
- Bash scripts for alternative deployment methods
- Docker Compose templates for Mattermost and PostgreSQL
- Nginx configuration templates for HTTP and HTTPS

### Usage
This project allows you to deploy a fully functional Mattermost server on AWS with minimal manual intervention. It's ideal for teams looking to set up their own secure, self-hosted chat solution.

**Video Demo:** [Link](https://www.youtube.com/watch?v=ExGxrRk-42o)

## Prerequisites

Before starting, make sure you have installed the necessary tools on your local machine:

```bash
# Update the system
sudo apt update && sudo apt upgrade -y

# Add the HashiCorp repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform and Ansible
sudo apt update
sudo apt install -y terraform ansible

# Install the Docker collection for Ansible
ansible-galaxy collection install community.docker
```

## Automatic Deployment of an EC2 Instance with Terraform

To complete this deployment, you'll need three files:

```bash
.
├── main.tf
├── terraform.tfvars
└── variables.tf

1 directory, 3 files
```

### `variables.tf` File

The `variables.tf` file is used only to declare variables that will be dynamically assigned. Here is its purpose:

```hcl
# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Type of EC2 instance"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 24.04 LTS in us-east-1"
  type        = string
  default     = "ami-06aa3f7caf3a30282"  # Ubuntu 24.04 LTS in us-east-1
}

variable "key_name" {
  description = "Name of SSH key pair"
  type        = string
}

variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
}
```

**Important Note:** Do not modify this file directly. All value changes should be made in the `terraform.tfvars` file.

### `terraform.tfvars` File

The `terraform.tfvars` file contains specific values for each variable declared in `variables.tf`. Here's an example of its contents:

```hcl
# terraform.tfvars

aws_region    = "us-east-1"
vpc_cidr      = "10.0.0.0/16"
subnet_cidr   = "10.0.1.0/24"
instance_type = "t2.micro"
ami_id        = "ami-06aa3f7caf3a30282"

key_name      = "!_to_change_!"
aws_access_key = "!_to_change_!"
aws_secret_key = "!_to_change_!"
```

**Important:** To adapt this file to your setup, update the following values:
- `aws_access_key`: Replace with your AWS access key
- `aws_secret_key`: Replace with your AWS secret key
- `key_name`: Replace with the name of your SSH key pair

**Warning:** Never share your AWS access keys (access key and secret key) publicly. Keep them confidential and avoid including them in public Git repositories.

### `main.tf` File

The `main.tf` file is the core of our Terraform configuration. It defines the necessary AWS infrastructure to deploy an Ubuntu 24.04 instance on t2.micro, along with all required networking and security components.

Here is an overview of the resources created:

1. **VPC**: An isolated virtual network in the AWS cloud.
2. **Internet Gateway**: Enables communication between the VPC and the Internet.
3. **Public Subnet**: A public subnet within the VPC.
4. **Route Table**: Configures routing for the subnet.
5. **Security Group**: Sets firewall rules for the EC2 instance.
6. **EC2 Instance**: The Ubuntu 24.04 instance itself.
7. **Elastic IP**: A static public IP address associated with the instance.

```hcl
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
}

# Elastic IP
resource "aws_eip" "server_eip" {
  instance = aws_instance.server.id
  domain   = "vpc"
}

# Outputs
output "public_ip" {
  value = aws_eip.server_eip.public_ip
}

output "ssh_connection" {
  value = "ssh -i ${var.key_name}.pem ubuntu@${aws_eip.server_eip.public_ip}"
}
```

#### Key Points:

- **VPC and Networking**: The VPC is configured with a specified CIDR block, and an Internet Gateway is attached to allow Internet access.

- **Subnet and Routing**: A public subnet is created and associated with a routing table that directs traffic to the Internet Gateway.

- **Security Group**: Configured to allow inbound SSH (port 22), HTTP (port 80), and HTTPS (port 443) traffic, as well as all outbound traffic.

- **EC2 Instance**: Uses the specified AMI and instance type from the variables. A 20 GB root volume is attached.

- **Elastic IP**: Attached to the EC2 instance to provide a static public IP address.

#### Outputs:

The script provides two useful outputs:

1. `public_ip`: The public IP address of the instance.
2. `ssh_connection`: A ready-to-use SSH command to connect to the instance.

#### Usage:

To deploy this infrastructure:

1. Ensure your AWS credentials are correctly set in `terraform.tfvars`.
2. Be sure to already have an ssh key pair 
3. Initialize Terraform: `terraform init`
4. Plan the deployment: `terraform plan`
5. Apply the configuration: `terraform apply`

**Security Note**: Be sure to restrict SSH (port 22) access to your IP address or a specific IP range in a production environment.

## Automatic Deployment of Mattermost

I’ve created two methods to automatically deploy a Mattermost server:

1. Using a Bash script
2. Using an Ansible playbook (not detailed in this document)

### Deployment with Bash Script

We provide two versions of the Bash script:

1. Without HTTPS certificate
2. With HTTPS certificate

#### Version Without HTTPS Certificate

This script performs the following actions:

1. System update
2. Installation of Docker and Docker Compose
3. Creation of necessary directories for Mattermost
4. Configuration of permissions
5. Creation of the `docker-compose.yml` file
6. Starting the containers

To use this script:

1. Create a file named `install_mattermost.sh`
2. Copy the script content into the file
3. Make the script executable: `chmod +x install_mattermost.sh`
4. Run the script: `sudo ./install_mattermost.sh`

```bash
#!/bin/bash
# scripts/install_mattermost.sh

# System update
apt update -y
apt upgrade -y

# Docker installation
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y
apt install -y docker-ce

# Start Docker
systemctl start docker
systemctl enable docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create directories for Mattermost
mkdir -p /opt/mattermost/config
mkdir -p /opt/mattermost/data
mkdir -p /opt/mattermost/logs
mkdir -p /opt/mattermost/plugins
mkdir -p /opt/mattermost/client/plugins

# Set correct permissions for Mattermost directories
chown -R 2000:2000 /opt/mattermost/config
chown -R 2000:2000 /opt/mattermost/data
chown -R 2000:2000 /opt/mattermost/logs
chown -R 2000:2000 /opt/mattermost/plugins
chown -R 2000:2000 /opt/mattermost/client/plugins

# Create docker-compose.yml
cat > /opt/mattermost/docker-compose.yml <<EOF
version: "3"
services:
  db:
    image: postgres:13
    restart: always
    environment:
      POSTGRES_USER: mmuser
      POSTGRES_PASSWORD: mmuser-password
      POSTGRES_DB: mattermost
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - mm-network

  mattermost:
    image: mattermost/mattermost-team-edition:latest
    restart: always
    depends_on:
      - db
    environment:
      MM_USERNAME: mmuser
      MM_PASSWORD: mmuser-password
      MM_DBNAME: mattermost
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mmuser:mmuser-password@db:5432/mattermost?sslmode=disable
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
    ports:
      - "8065:8065"
    networks:
      - mm-network

networks:
  mm-network:
    driver: bridge
EOF

# Start containers
cd /opt/mattermost
docker-compose up -d
```

#### Version with HTTPS Certificate

This version includes additional steps:

1. Installing and configuring Nginx
2. Generating an SSL certificate with Certbot
3. Configuring Nginx to use HTTPS

**Important:** Before running this script:

1. Set up your DNS to point to the public IP of your AWS instance.
2. Update the `HOSTNAME` variable in the script to contain your domain name.

To use this script:

1. Create a file named `install_mattermost_https.sh`
2. Copy the script contents into the file
3. Modify the `HOSTNAME` variable
4. Make the script executable: `chmod +x install_mattermost_https.sh`
5. Run the script: `sudo ./install_mattermost_https.sh`

```bash
#!/bin/bash

# Set the hostname
HOSTNAME="!_DOMAIN_NAME_!"

# Update the system
apt update -y
apt upgrade -y

# Install required packages
apt install -y apt-transport-https ca-certificates curl software-properties-common nginx certbot python3-certbot-nginx

# Add Docker repository and install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y
apt install -y docker-ce

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create Mattermost directories
mkdir -p /opt/mattermost/{config,data,logs,plugins,client/plugins}

# Set correct permissions for Mattermost directories
chown -R 2000:2000 /opt/mattermost/{config,data,logs,plugins,client/plugins}

# Create initial Nginx configuration without SSL
cat > /etc/nginx/sites-available/mattermost <<EOF
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site and remove default
ln -s /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Generate SSL certificate
certbot --nginx -d $HOSTNAME --non-interactive --agree-tos --email admin@$HOSTNAME

# Update Nginx configuration with SSL
cat > /etc/nginx/sites-available/mattermost <<EOF
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $HOSTNAME;

    ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Test Nginx configuration again
nginx -t

# Restart Nginx
systemctl restart nginx

# Create docker-compose.yml
cat > /opt/mattermost/docker-compose.yml <<EOF
version: "3"
services:
  db:
    image: postgres:13
    restart: always
    environment:
      POSTGRES_USER: mmuser
      POSTGRES_PASSWORD: mmuser-password
      POSTGRES_DB: mattermost
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - mm-network

  mattermost:
    image: mattermost/mattermost-team-edition:latest
    restart: always
    depends_on:
      - db
    environment:
      MM_USERNAME: mmuser
      MM_PASSWORD: mmuser-password
      MM_DBNAME: mattermost
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mmuser:mmuser-password@db:5432/mattermost?sslmode=disable
      MM_SERVICESETTINGS_SITEURL: https://$HOSTNAME
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
    ports:
      - "127.0.0.1:8065:8065"
    networks:
      - mm-network

networks:
  mm-network:
    driver: bridge
EOF

# Start Mattermost containers
cd /opt/mattermost
docker-compose up -d

echo "Installation complete!"
echo "Please access Mattermost at https://$HOSTNAME"
```

- Make sure to change the default passwords in the `docker-compose.yml` file.
- Limit SSH access to your server.
- Regularly update your system and Docker containers.

#### Accessing Mattermost

After running the script, you can access Mattermost:

- Without HTTPS: `http://your-ip:8065`
- With HTTPS: `https://your-domain.com`

If you encounter issues:

1. Check Docker logs: `docker-compose logs`
2. Ensure the necessary ports are open in your firewall.
3. Check Nginx logs for any HTTPS-related issues.

### Deployment with an Ansible Playbook

This method uses Ansible to automate the deployment of Mattermost with HTTPS.

#### Project Structure

```
.
├── inventory
├── playbook.yml
└── templates
    ├── docker-compose.yml.j2
    ├── nginx-http.conf.j2
    └── nginx-https.conf.j2

2 directories, 5 files
```

#### Inventory Configuration

Create an `inventory` file with the following content:

```ini
[mattermost]
!_EC2_PUB_IP_! ansible_user=ubuntu ansible_ssh_private_key_file=!_PATH_TO_PRIV_KEY_!
```

Be sure to replace the IP address and SSH key path with your own.

#### Templates

In the `templates` folder, create the following files:

1. `docker-compose.yml.j2`

```bash
version: "3"
services:
  db:
    image: postgres:13
    restart: always
    environment:
      POSTGRES_USER: mmuser
      POSTGRES_PASSWORD: mmuser-password
      POSTGRES_DB: mattermost
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      - mm-network

  mattermost:
    image: mattermost/mattermost-team-edition:latest
    restart: always
    depends_on:
      - db
    environment:
      MM_USERNAME: mmuser
      MM_PASSWORD: mmuser-password
      MM_DBNAME: mattermost
      MM_SQLSETTINGS_DRIVERNAME: postgres
      MM_SQLSETTINGS_DATASOURCE: postgres://mmuser:mmuser-password@db:5432/mattermost?sslmode=disable
      MM_SERVICESETTINGS_SITEURL: https://{{ hostname }}
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
    ports:
      - "127.0.0.1:8065:8065"
    networks:
      - mm-network

networks:
  mm-network:
    driver: bridge
```

2. `nginx-http.conf.j2`

```bash
server {
    listen 80;
    server_name {{ hostname }};
    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```


3. `nginx-https.conf.j2`

```bash
server {
    listen 80;
    server_name {{ hostname }};
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name {{ hostname }};
    ssl_certificate /etc/letsencrypt/live/{{ hostname }}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{ hostname }}/privkey.pem;

    location / {
        proxy_pass http://localhost:8065;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

These files contain the configurations for Docker Compose and Nginx, respectively.

#### Ansible Playbook

The `playbook.yml` file contains all the tasks required to deploy Mattermost with an HTTPS certificate:

1. System update
2. Installation of dependencies (Docker, Nginx, Certbot)
3. Nginx configuration
4. SSL certificate generation
5. Deploying Mattermost with Docker Compose

```yaml
---
- name: Install and Configure Mattermost with SSL
  hosts: all
  become: yes
  vars:
    hostname: "!_DNS_NAME_!"
    mattermost_root: "/opt/mattermost"
    certbot_email: "admin@{{ hostname }}"

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Upgrade packages
      apt:
        upgrade: yes

    - name: Install packages
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
          - nginx
          - certbot
          - python3-certbot-nginx
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
        state: present

    - name: Install Docker
      apt:
        name: docker-ce
        state: present
        update_cache: yes

    - name: Check if Docker service is started and enabled
      service:
        name: docker
        state: started
        enabled: yes

    - name: Install Docker Compose
      get_url:
        url: "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-{{ ansible_system }}-{{ ansible_architecture }}"
        dest: /usr/local/bin/docker-compose
        mode: '0755'

    - name: Create directories for Mattermost
      file:
        path: "{{ item }}"
        state: directory
        owner: 2000
        group: 2000
        mode: '0755'
      with_items:
        - "{{ mattermost_root }}/config"
        - "{{ mattermost_root }}/data"
        - "{{ mattermost_root }}/logs"
        - "{{ mattermost_root }}/plugins"
        - "{{ mattermost_root }}/client/plugins"

    - name: Configure Nginx for HTTP
      template:
        src: templates/nginx-http.conf.j2
        dest: /etc/nginx/sites-available/mattermost
        mode: '0644'

    - name: Enable Mattermost site
      file:
        src: /etc/nginx/sites-available/mattermost
        dest: /etc/nginx/sites-enabled/mattermost
        state: link

    - name: Disable default NGINX site
      file:
        path: /etc/nginx/sites-enabled/default
        state: absent

    - name: Restart Nginx
      service:
        name: nginx
        state: restarted

    - name: Generate SSL certificate with Certbot
      command: >
        certbot --nginx -d {{ hostname }}
        --non-interactive --agree-tos
        --email {{ certbot_email }}
      args:
        creates: "/etc/letsencrypt/live/{{ hostname }}/fullchain.pem"

    - name: Configure Nginx for HTTPS
      template:
        src: templates/nginx-https.conf.j2
        dest: /etc/nginx/sites-available/mattermost
        mode: '0644'

    - name: Enable Mattermost site
      file:
        src: /etc/nginx/sites-available/mattermost
        dest: /etc/nginx/sites-enabled/mattermost
        state: link

    - name: Restart Nginx
      service:
        name: nginx
        state: restarted

    - name: Create docker-compose.yml file
      template:
        src: templates/docker-compose.yml.j2
        dest: "{{ mattermost_root }}/docker-compose.yml"
        mode: '0644'

    - name: Start Mattermost containers
      community.docker.docker_compose_v2:
        project_src: "{{ mattermost_root }}"
        state: present
```

#### Running the Playbook

To run the playbook:

1. Ensure that Ansible is installed on your local machine.
2. Configure your DNS to point to the IP address of your server.
3. Modify the `hostname` variable in the playbook to match your domain.
4. Run the command:

```
ansible-playbook -i inventory playbook.yml
```

- The playbook automatically configures HTTPS with Let's Encrypt.
- Ensure that your SSH keys and credentials are kept secure.
- Consider using Ansible encrypted variables for passwords.

- You can modify the templates to adjust the configurations to suit your needs.
- Adjust the variables in the playbook to customize the installation.

In case of issues:

1. Check the Ansible logs for specific errors.
2. Ensure that all necessary ports are open (80, 443, 22).
3. Check the Docker and Nginx logs on the target server.

- Consider regularly updating Mattermost and other components.
- Monitor the expiration of your SSL certificate and renew it if necessary.

This approach with Ansible provides a reproducible and easily maintainable method to deploy Mattermost, ideal for large-scale production or test environments.

## Complete Automation of Mattermost Installation with HTTPS

This section explains how to fully automate the installation of Mattermost on AWS, including the HTTPS configuration, using Terraform and Ansible.

### Project Structure

Organize your project as follows:

```
.
├── main.tf                  # Main Terraform configuration
├── variables.tf             # Terraform variable definitions
├── terraform.tfvars         # Terraform variable values
├── playbook.yml             # Ansible playbook
└── templates/
    ├── docker-compose.yml.j2    # Docker Compose template
    ├── nginx-http.conf.j2       # Nginx HTTP configuration
    └── nginx-https.conf.j2      # Nginx HTTPS configuration
```

### Key Modifications

#### 1. Terraform Configuration (`main.tf`)

Main changes include:

- Automatically generating an SSH key for the EC2 instance.
- Creating a dynamic Ansible inventory file.
- Automatically running the Ansible playbook after the infrastructure is created.

Notable additions:

```hcl
# Generating the SSH key
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Creating the AWS key pair
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = var.key_name  
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Saving the private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/${var.key_name}"
  file_permission = "0400"
}

# Creating the Ansible inventory file
resource "local_file" "inventory" {
  content  = templatefile("${path.module}/inventory.tpl", {
    ip = aws_eip.server_eip.public_ip,
    key_file = var.key_name
  })
  filename = "${path.module}/inventory"
}

#Running Ansible Script
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
```

#### 2. Ansible Playbook (`playbook.yml`)

Main changes:

- Dynamically updating the No-IP DNS record.
- Waiting for DNS propagation before continuing.

Example additions:

```yaml
    noip_username: "!_TO_BE_CHANGED_!"
    noip_password: "!_TO_BE_CHANGED_!"

  tasks:
    - name: Retrieve the public IP address of the EC2 instance
      set_fact:
        host_ip: "{{ inventory_hostname }}"

    - name: Update the No-IP DNS record with the EC2 IP address
      uri:
        url: "https://dynupdate.no-ip.com/nic/update?hostname={{ hostname }}&myip={{ host_ip }}"
        method: GET
        url_username: "{{ noip_username }}"
        url_password: "{{ noip_password }}"
        force_basic_auth: yes
        return_content: yes
        validate_certs: yes
      delegate_to: localhost
      become: no
      register: noip_response

    - name: No-IP response
      debug:
        var: noip_response
      become: no

    - name: Wait for DNS propagation
      pause:
        minutes: 1
      become: no
```

### Usage

To deploy Mattermost:

1. Configure your variables in `terraform.tfvars` and your No-IP credentials in `playbook.yml`.
2. Initialize Terraform:
   ```
   terraform init
   ```
3. Apply the configuration:
   ```
   terraform apply
   ```

This command will:
- Create the AWS infrastructure
- Generate the SSH keys
- Run the Ansible playbook to install and configure Mattermost

- Ensure that your AWS credentials are configured correctly.
- Verify that all necessary variables are set in `terraform.tfvars` and `playbook.yml`.
- DNS propagation may take time. The playbook includes a pause, but you may need to adjust this delay.

This approach fully automates the process, from creating the infrastructure to installing and configuring Mattermost with HTTPS.

In summary, if you choose this method, the only necessary changes in the configuration files are as follows:

In **terraform.tfvars**:
```hcl
key_name       = "!_TO_BE_REPLACED_!"
aws_access_key = "!_TO_BE_REPLACED_!"
aws_secret_key = "!_TO_BE_REPLACED_!"
```

In **playbook.yml**:
```yaml
hostname:       "!_DOMAIN_NAME_!"
noip_username:  "!_NOIP_EMAIL_!"
noip_password:  "!_NOIP_PASSWORD_!"
```

Finally, in your NOIP account, you only need to create a domain without associating an IP address to it.

**Note:** All files to automate everything with Terraform are located in the `all-in-one` folder.