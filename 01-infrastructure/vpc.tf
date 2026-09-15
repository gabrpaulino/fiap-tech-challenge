data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_cidr_block     = "10.0.0.0/16"
  availability_zones = data.aws_availability_zones.available.names

  public_subnet_cidr = {
    for index, az in local.availability_zones :
    az => cidrsubnet(local.vpc_cidr_block, 8, index)
  }

  private_subnet_cidr = {
    for index, az in local.availability_zones :
    az => cidrsubnet(local.vpc_cidr_block, 8, index + length(local.availability_zones))
  }
}

resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "toggle-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidr

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name                     = "toggle-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnet_cidr

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name                              = "toggle-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "toggle-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "toggle-public-rt"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "toggle-nat-eip"
  }
}

# Um NAT Gateway é suficiente para este ambiente. Para alta disponibilidade,
# crie um NAT Gateway e uma route table privada por zona de disponibilidade.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "toggle-nat-gateway"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "toggle-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
