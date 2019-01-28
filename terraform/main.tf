#############################
# Demonstrate Good VPC Arch #
#############################

provider "aws" {
  region = "us-east-1"
  profile = "fuzeops"
}

variable "name" {
  default = "fuzenet"
  type    = "string"
}

variable "network" {
  default = "10.99.0.0/16"
  type    = "string"
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "${var.network}"

  tags = "${
    map(
     "Name", "${var.name}",
    )
  }"
}

# Allocates a public subnet for 3 AZs; use 4 bits
# NOTE: Public subnets are 1/2 size of Private subnets
resource "aws_subnet" "public" {
  count = 3

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "${cidrsubnet(var.network, 4, count.index)}"
  vpc_id            = "${aws_vpc.main.id}"

  tags = "${
    map(
     "Name", "${data.aws_availability_zones.available.names[count.index]} public",
     "Tier", "public",
    )
  }"
}

# Allocate Internet Gateway for use by public subnets
resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.name} IGW"
  }
}

# Setup internet traffic thru IGW
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.public.id}"
  }

  tags {
    Name = "all public subnets"
  }
}

# Give IGW routing table to public subnets
resource "aws_route_table_association" "public" {
  count = 3
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public.id}"
}

# Allocates a private subnet for each AZ from the given network; use two new bits
# NOTE: Private subnets are 2x larger than public subnets
resource "aws_subnet" "private" {
  count = 3

  vpc_id                  = "${aws_vpc.main.id}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block              = "${cidrsubnet(var.network, 2, count.index + 1)}"
  map_public_ip_on_launch = false

  tags = "${
    map(
     "Name", "${data.aws_availability_zones.available.names[count.index]} private",
     "Tier", "private",
    )
  }"
}

# Used by private subnets to get internet access
# NOTE: Must be launched inside a public subnet
# TODO: These cost money once provisioned; turn off soon!
resource "aws_nat_gateway" "nat" {
  count = 3
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  depends_on    = ["aws_internet_gateway.public"]
}

# Public IP addresses for the NAT gateways
resource "aws_eip" "nat" {
  count      = 3
  vpc        = true
  depends_on = ["aws_internet_gateway.public"]
}

# Setup internet traffic thru NAT gateways
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags {
    Name = "${data.aws_availability_zones.available.names[count.index]} private"
  }
}

# Give NAT routing table to private subnets
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}
