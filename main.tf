provider "aws" {}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable availability_zone {}
variable "env_prefix" {}
variable my_ip {}
variable "instance_type" {}

resource "aws_vpc" "dockerApp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "dockerApp-subnet-1" {
  vpc_id = aws_vpc.dockerApp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "dockerApp-igw" {
  vpc_id = aws_vpc.dockerApp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

resource "aws_route_table" "dockerApp-rt" {
  vpc_id = aws_vpc.dockerApp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dockerApp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-rt"
  }
}

resource "aws_route_table_association" "dockerApp-art-subnet" {
  subnet_id = aws_subnet.dockerApp-subnet-1.id
  route_table_id = aws_route_table.dockerApp-rt.id
}

resource "aws_security_group" "dockerApp-sg" {
  name = "dockerApp-sg"
  vpc_id = aws_vpc.dockerApp-vpc.id

  ingress{
    from_port = 22
    to_port = 22
    cidr_blocks = [var.my_ip]
    protocol = "TCP"
  }

  ingress{
    from_port = 8080
    to_port = 8080
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "TCP"
  }

  egress{
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "-1"
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "dockerApp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id = aws_subnet.dockerApp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.dockerApp-sg.id]
  availability_zone = var.availability_zone
  associate_public_ip_address = true
  key_name = "dockerApp"
  tags = {
    Name = "${var.env_prefix}-dockerApp-server"
  }
  user_data_replace_on_change = true
  user_data = <<EOF
                #!/bin/bash
                sudo yum update -y && sudo yum install docker -y
                sudo systemctl start docker
                sudo usermod -aG docker ec2-user
                docker run -p 8080:80 nginx
                EOF
  
}

output "server" {
  value = data.aws_ami.latest-amazon-linux-image.id
}