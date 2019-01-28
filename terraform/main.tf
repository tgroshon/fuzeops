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

variable "ssh_key_name" {
  default = "tgroshon"
  type    = "string"
}

variable "ubuntu_ami" {
  # Lookup AMI with: "https://cloud-images.ubuntu.com/locator/"
  default = "ami-08b8af1c94b41235d"
  type    = "string"
}

variable "security_group_id" {
  default = "sg-0353c0a46f3f372b6"
  type = "string"
}

data "aws_security_group" "kata" {
  id = "${var.security_group_id}"
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

##########################
# Provision the Test Box #
##########################

resource "aws_instance" "katabox" {
  count = 1

  ami           = "${var.ubuntu_ami}"
  instance_type = "t2.micro"
  key_name      = "${var.ssh_key_name}"

  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  vpc_security_group_ids = ["${data.aws_security_group.kata.id}"]

  tags = {
    Name = "FuzeKataBox"
  }
}

# Normally would do this, but would rather not commit IP addresses
# to a public repo.  Will do manually in Console.
#################################

# resource "aws_security_group" "ssh" {
#   name        = "SSH Whitelist"
#   description = "Security group to restrict SSH access"
#   vpc_id      = "${aws_vpc.main.id}"

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["${var.ssh_my_id}/32", "${var.ip_whitelist_fuze}/32"]
#   }

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["${var.ssh_my_id}/32", "${var.ip_whitelist_fuze}/32"]
#   }

#   ingress {
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     cidr_blocks = ["${var.ssh_my_id}/32", "${var.ip_whitelist_fuze}/32"]
#   }
# }
