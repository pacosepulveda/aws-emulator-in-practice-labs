# Prueba negativa: provider SIN endpoint iam (deliberadamente omitido) y
# max_retries=1 para fallo rápido. Debe ejecutarse DENTRO del namespace emulab
# (sin ruta a internet): ninguna petición puede salir del host y el plan debe
# fallar con un error de red controlado (Network is unreachable).
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.16.0"
    }
  }
}

variable "ca_bundle" { type = string }
variable "access_key" { type = string }
variable "secret_key" { type = string }

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.access_key
  secret_key                  = var.secret_key
  custom_ca_bundle            = var.ca_bundle
  max_retries                 = 1
  endpoints {
    s3       = "https://127.0.0.1:9320"
    dynamodb = "https://127.0.0.1:9320"
    sqs      = "https://127.0.0.1:9320"
    sts      = "https://127.0.0.1:9320"
    # iam deliberadamente OMITIDO: sin la barrera de red esto llamaría a
    # iam.amazonaws.com con credenciales del emulador (hallazgo I-2.1)
  }
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true
}

resource "aws_iam_role" "negative" {
  name = "aws-emulator-lab-02-netns-neg"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
