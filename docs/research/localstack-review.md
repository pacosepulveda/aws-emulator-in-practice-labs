# LocalStack — investigación inicial (planes y términos) · 2026-11-13

**Estado:** investigación documental SOLO. No se han registrado cuentas, aceptado
términos ni instalado nada. Cualquier registro/contratación requerirá decisión
explícita de Francisco.

## Preguntas abiertas que esta investigación debe responder (fase 3)

1. Planes actuales y precios (Community gratis vs Pro comercial) y qué servicios
   APIs incluye cada uno exactamente.
2. Términos de uso: ¿permite publicar comparativas técnicas con datos de rendimiento?
   ¿hay restricciones de uso profesional/laboratorio?
3. Plan Hobby: existencias actuales, límites (nº de servicios, uso, duración).
4. Opciones de evaluación sin registro (imagen local gratuita sin API key).
5. Historial de cambios de licencia (la cobertura de Community se redujo en el
   pasado — relevante para comparativas justas).

## Propuesta de comparación (a ejecutar cuando Francisco apruebe)

- **Grupo A — gratuito sin registro:** mismo set de pruebas del lab 01 (S3, DynamoDB,
  SQS, STS) contra LocalStack Community. Resultados directamente comparables.
- **Grupo B — comercial (NO contratado):** documentar qué tests fallarían por
  licencia (ej. IAM avanzado, Lambda con ciertos features, RDS) según su tabla
  de features publicada, marcándolos como COMMERCIAL en vez de FAIL.
- **Grupo C — versiones históricas:** si la cobertura Community actual es inferior
  a la de versiones antiguas, documentarlo explícitamente para no comparar injustamente.

## Capa de configuración por backend (diseño propuesto)

El código actual está acoplado al emulador (env.sh, endpoint, credenciales de
~/.aws/emulator/<port>). Propuesta para fase 3 sin debilitar controles:

```
scripts/common/backends/
├── aws-emulator.env   # exporta ENDPOINT, CREDS, CA, cuenta esperada 000000000000
├── localstack.env     # exportará lo equivalente (endpoint, creds dummy, CA)
└── README.md
env.sh <backend> <puerto>   # validaciones de identidad específicas por backend
```

Cada backend declara: endpoint, ficheros de credenciales, CA bundle, identidad
esperada (STS) y lista de scrub de variables. Los tests siguen siendo agnósticos.
