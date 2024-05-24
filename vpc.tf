resource "aws_vpc" "main" {
    cidr_block  = var.vpc_cidr
    instance_tenancy = "default"
    enable_dns_hostnames = var.enable_dns_hostnames

    tags = merge(
        var.common_tags, 
        var.vpc_tags,
        {
            Name = local.resource_name
        }
    )
}

## connecting with vpc internet_gateway#

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags, 
    {
        Name = local.resource_name
    }
  )
}

## public subet  ##

resource "aws_subnet" "public" {          #first name is public[0], Second name is public[1]
  count = length(var.public_subnet_cidrs)   
  availability_zone= local.az_name[count.index]
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.public_subnet_cidrs_tags,
    {
        Name = "${local.resource_name}-public-${local.az_name[count.index]}"
    }
  )
}

resource "aws_subnet" "private" {  #first name is private[0], Second name is private[1]
  count = length(var.private_subnet_cidrs)
  availability_zone= local.az_name[count.index]
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.private_subnet_cidrs_tags,
    {
        Name = "${local.resource_name}-private-${local.az_name[count.index]}"
    }
  )
}

resource "aws_subnet" "database" {  # first name is database[0], Second name is database[1]
  count = length(var.database_subnet_cidrs)
  availability_zone= local.az_name[count.index]
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.database_subnet_cidrs_tags,
    {
        Name = "${local.resource_name}-database-${local.az_name[count.index]}"
    }
  )
}

resource "aws_db_subnet_group" "default" {
  name       = "${local.resource_name}"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.common_tags,
    var.database_subnet_group_tags,
    {
        Name = "${local.resource_name}"
    }
  )
}


resource "aws_eip" "nat" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "nat" {          
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  
  
#As instance are creating 2, One in us-east-1a & us-east-1b, So if you give public[0] this nat will create in 
## one only in us-east-1a subnet. 

  tags = merge(
    var.common_tags,
    var.nat_gateway_tags,
    {
        Name = "${local.resource_name}" # expense-dev
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]  #this is explicit dependecy.
  # This is will be first create internet_gatway and then nat will connect to it
}

## public route table ##

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
        Name = "${local.resource_name}-public"
    }
  )
}

## private route table ##

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
    {
        Name = "${local.resource_name}-private"
    }
  )
}

## database route table ##

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.database_route_table_tags,
    {
        Name = "${local.resource_name}-database"
    }
  )
}

## Internet and Nat Gateway inside route tables ##
resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id 
}

resource "aws_route" "private_route_nat" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id 
}

resource "aws_route" "database_route_nat" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id 
}

## route table assoications with subnets ##
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)    
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)    
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)
  subnet_id      = element(aws_subnet.database[*].id, count.index)    
  route_table_id = aws_route_table.database.id
}


