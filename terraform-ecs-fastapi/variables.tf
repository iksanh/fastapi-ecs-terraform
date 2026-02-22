variable "aws_region" {
  type = string
  description = "region aws"
  default = "us-east-1"  
}

variable "db_name" {
  type = string
  description = "Database Name"
  default = "db_fastapi"
}

variable "db_username" {
  type = string
  description = "USER DB"
  default = "postgres"
}

variable "db_password" {
  type = string
  description = "PASSWORD DB"
  default = "postgres123"
  sensitive = true
}






