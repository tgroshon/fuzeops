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
