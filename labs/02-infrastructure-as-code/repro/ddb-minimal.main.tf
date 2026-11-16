# Caso mínimo: drift de DynamoDB tras apply (sin timestamp, sin random, sin extras).
# El plan inmediatamente posterior al apply debe ser vacío en AWS real; aquí
# registramos exactamente qué atributos cambian y con qué action.
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.16.0"
    }
  }
}

variable "endpoint" {
  type    = string
  default = "https://127.0.0.1:9297"
}
variable "ca_bundle" {
  type = string
}
variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.access_key
  secret_key                  = var.secret_key
  custom_ca_bundle            = var.ca_bundle
  endpoints {
    s3       = var.endpoint
    dynamodb = var.endpoint
    sqs      = var.endpoint
    sts      = var.endpoint
    iam      = var.endpoint
  }
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true
}

resource "aws_dynamodb_table" "repro" {
  name         = "aws-emulator-lab-02-repro-min"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
}
