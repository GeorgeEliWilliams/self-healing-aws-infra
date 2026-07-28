resource "aws_vpc" "k3s_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true
    
    tags = {
        Name = "k3s-vpc"
    }
  
}

resource "aws_subnet" "k3s_public_subnet" {
    vpc_id                  = aws_vpc.k3s_vpc.id
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "eu-west-1a"

    tags = {
        Name = "k3s-public-subnet"
    }

}

resource "aws_internet_gateway" "k3s_igw" {
    vpc_id = aws_vpc.k3s_vpc.id

    tags = {
        Name = "k3s-internet-gateway"
    }
}

resource "aws_route_table" "k3s_public_rt" {
    vpc_id = aws_vpc.k3s_vpc.id

    tags = {
        Name = "k3s-public-route-table"
    }
}

resource "aws_route" "k3s_public_route" {
    route_table_id         = aws_route_table.k3s_public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id             = aws_internet_gateway.k3s_igw.id
}

resource "aws_route_table_association" "k3s_public_rt_assoc" {
    subnet_id      = aws_subnet.k3s_public_subnet.id
    route_table_id = aws_route_table.k3s_public_rt.id
}