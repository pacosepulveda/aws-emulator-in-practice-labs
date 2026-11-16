# Lab 02 — Terraform contra AWS Emulator (etapa A: S3 + DynamoDB + SQS)

# Pin de versión por herramienta instalada (SHA-256 verificado), no por
# constraint: "1.13.3" exacto excluía OpenTofu 1.10 (hallazgo I-3).
# 1.13.3 = Terraform · 1.10.5 = OpenTofu, ambos ≥1.6
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.16.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.emulator_access_key
  secret_key                  = var.emulator_secret_key

  # TLS con la CA del emulador (nunca insecure_skip_verify)
  # v6 renombró ca_bundle → custom_ca_bundle
  custom_ca_bundle            = var.emulator_ca_bundle

  # Endpoints explícitos por servicio (localhost del emulador).
  # ATENCIÓN (hallazgo I-2): omitir aquí un servicio usado por recursos del plan
  # hace que el provider LLAME AL AWS REAL con las credenciales del emulador
  # (visto con IAM: 25 reintentos contra iam.amazonaws.com). Todos los servicios
  # que use la configuración DEBEN estar listados.
  endpoints {
    s3       = var.emulator_endpoint
    dynamodb = var.emulator_endpoint
    sqs      = var.emulator_endpoint
    sts      = var.emulator_endpoint
    iam      = var.emulator_endpoint
  }

  # Requeridos para un emulador (sin validación contra AWS real)
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true
  # (v6: no existe skip_ec2_metadata_check; el scrub de env en env.sh cubre EC2 metadata)
}

variable "emulator_endpoint" {
  type    = string
  default = "https://127.0.0.1:9297"
}

variable "emulator_ca_bundle" {
  type        = string
  description = "Ruta a la CA del emulador (~/.aws/emulator/<puerto>/ca.pem)"
}

variable "emulator_access_key" {
  type        = string
  sensitive   = true
  description = "Access key del emulador (fichero emulator_credentials)"
}

variable "emulator_secret_key" {
  type        = string
  sensitive   = true
}

variable "resource_prefix" {
  type    = string
  default = "aws-emulator-lab-02"
}

# Sufijo persistido en el state (estable entre planes; timestamp() se reevalúa
# en cada plan y provocaría reemplazos completos — hallazgo de diseño propio I-2)
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  run_id = random_id.suffix.hex
}

# ---- S3 ----
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.resource_prefix}-tf-${local.run_id}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---- DynamoDB ----
resource "aws_dynamodb_table" "state" {
  name         = "${var.resource_prefix}-tf-${local.run_id}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
}

# ---- SQS ----
resource "aws_sqs_queue" "tasks" {
  name = "${var.resource_prefix}-tf-${local.run_id}"
}

# ---- IAM (I-2) ----
resource "aws_iam_role" "lab_role" {
  name = "${var.resource_prefix}-tf-${local.run_id}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lab_policy" {
  name = "${var.resource_prefix}-tf-${local.run_id}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.artifacts.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lab_attach" {
  role       = aws_iam_role.lab_role.name
  policy_arn = aws_iam_policy.lab_policy.arn
}

output "bucket_name" {
  value = aws_s3_bucket.artifacts.id
}

output "table_name" {
  value = aws_dynamodb_table.state.name
}

output "queue_url" {
  value = aws_sqs_queue.tasks.url
}
