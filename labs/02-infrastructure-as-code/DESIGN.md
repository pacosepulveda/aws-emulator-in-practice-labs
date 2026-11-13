# Laboratorio 04→02 — Infrastructure as Code con AWS Emulator (DISEÑO, no implementado)

**Nota de orden:** tras la revisión de 2026-11-13, la serie pasa a ser: 01 instalación →
**02 IaC** → 03 comparativa LocalStack → … (la comparativa con LocalStack se retrasa).

## Objetivo

Desplegar la **misma infraestructura lógica de referencia** con tres herramientas
(Terraform/OpenTofu, CloudFormation, AWS CDK) contra AWS Emulator, comparar
resultados y reutilizar la arquitectura en artículos posteriores.

## Arquitectura de referencia propuesta

```
          ┌── S3 bucket (config/artifacts) ──┐
Agente ──►│ DynamoDB tabla (estado/app)      │──► IAM: rol + policy mínima
          │ SQS cola (tareas)                │
          │ (+ Lambda y API Gateway si la    │
          │   cobertura del emulador permite)│
          └──────────────────────────────────┘
```

**Etapa A (núcleo):** S3 + DynamoDB + SQS + IAM (rol con policy de acceso restringido
a esos recursos). **Etapa B (ampliación, condicionada a cobertura):** Lambda básica +
API Gateway. La decisión de incluir B se tomará tras revisar el `scores.json.gz` y
los issues `things-that-do-not-work/` de esas APIs.

## Investigación pendiente antes de implementar

| Área | Qué investigar | Fuente |
|---|---|---|
| Terraform + AWS provider | versión del provider, endpoints custom (`endpoints` block), skip_credentials_validation/skip_metadata/skip_requesting_account_id, TLS con ca_bundle | registry.terraform.io + docs emulador (point-sdk) |
| OpenTofu | diferencias reales con Terraform 1.x; ¿mismo provider funciona? | opentofu.org |
| CloudFormation | soporte del emulador: create/update/delete/change sets; drift detection (los releases mencionan fixes de CFn) | docs emulador + issues/ |
| AWS CDK | bootstrap (CDKToolkit: buckets/roles ECR/SSM) — riesgo de bootstrap parcialmente emulado; posible workaround con bootstrapless synth o despliegue directo de plantillas | aws-cdk docs + issues/ |
| Endpoints/TLS | cómo apunta cada herramienta al endpoint https con CA autofirmada | doc point-sdk-to-emulator |
| Estado | persistencia en memoria del emulador vs tfstate; estrategias para re-ejecuciones limpias | lab 01 (D) + tests propios |

## Experimentos previstos (a implementar tras aprobar el diseño)

1. **I-1 Terraform:** init/plan/apply/drift/destroy de la referencia (etapa A)
2. **I-2 OpenTofu:** mismo código — compatibilidad real
3. **I-3 CloudFormation:** stack equivalente; updates y delete
4. **I-4 CDK:** synth + deploy (documentando cualquier workaround del bootstrap)
5. **I-5 Comparativa:** resultados unificados, tiempos, limitaciones por herramienta

## Criterios de medición (heredados del lab 01)

- Mismo registro estructurado (run_id, timestamps ISO 8601, PASS/FAIL/PARTIAL)
- Recursos con prefijo `aws-emulator-lab-iac-*`
- Reutilizable contra LocalStack (capa de configuración por backend — ver
  docs/research/localstack-review.md)
