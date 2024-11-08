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
  default     = "ami-06aa3f7caf3a30282"  # Ubuntu 24.04 LTS dans us-east-1
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
