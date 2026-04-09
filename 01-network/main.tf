# FILE: ./01-network/main.tf

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "k3s-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-northeast-2a"
  tags = { Name = "k3s-public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
  tags = { Name = "k3s-private-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "k3s-igw" }
}

# ==========================================
# 💡 여기서부터 NAT 스위치(var.enable_nat)가 적용된 부분입니다!
# ==========================================

resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat ? 1 : 0
  
  # count가 적용된 리소스는 [0] 인덱스로 접근해야 합니다.
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id
  tags = { Name = "k3s-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 기존에 있던 route { ... } 블록을 제거하여 빈 껍데기로 만듭니다.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
}

# NAT Gateway가 생성될 때만(enable_nat = true), Private 라우팅 규칙을 추가합니다.
resource "aws_route" "private_nat_route" {
  count                  = var.enable_nat ? 1 : 0
  
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}