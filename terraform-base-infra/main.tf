resource "aws_vpc" "base" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "base-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  cidr_block        = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  vpc_id            = aws_vpc.base.id
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  cidr_block        = var.private_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.base.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "isolated" {
  count             = length(var.isolated_subnet_cidrs)
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.base.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "isolated-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "vpc-gateway"
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  count = length(aws_subnet.public)
  vpc   = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "nat_gateway_route" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index % length(aws_nat_gateway.nat)].id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_availability_zones" "available" {}
