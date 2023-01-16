provider "aws" {
    region = "us-east-2"
    access_key = "AKIAZGZIHEH47FDMZC7D"
    secret_key = "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"
}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod-vpc"
  }
}



resource "aws_internet_gateway" "gw_1" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw_1.id
  }

  tags = {
    Name = "Prod"
  }
}

resource "aws_subnet" "prod-subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-2a"

    tags = {
        Name = "prod-subnet-1"
    }
}

#connects subnet to route table
resource "aws_route_table_association" "association-1" {
  subnet_id      = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow-web" {
  name        = "allow-web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-web-traffic"
  }
}

resource "aws_network_interface" "web-nic" {
  subnet_id       = aws_subnet.prod-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

}

resource "aws_eip" "eip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.web-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw_1]

}

resource "aws_instance" "web-server" {
    ami = "ami-0ff39345bd62c82a5"
    instance_type = "t2.micro"
    availability_zone = "us-east-2a"
    key_name = "EC2 Tutorial"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo installation successful > /var/www/html/index.html'
                EOF
    
    tags = {
        Name = "web-server-1"
    }


}