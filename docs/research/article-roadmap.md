# Hoja de ruta de artículos — AWS Emulator in Practice

Estado: propuesta inicial (2026-11-13). Se revisará tras el lab 01.

| Nº | Artículo | Prioridad | Estado |
|----|----------|-----------|--------|
| 01 | Instalación y primeros pasos | Alta — **en curso** | Lab definido |
| 02 | Infrastructure as Code con AWS Emulator | **Alta (siguiente — REORDENADO 2026-11-13)** | Diseño en labs/02-infrastructure-as-code/DESIGN.md |
| 03 | AWS Emulator vs LocalStack | Alta (tercero) | Pendiente IaC |
| 04 | Cloud Security con el emulador | Alta (diferenciador del blog) | Pendiente |
| 05 | Serverless 100% local | Media | Pendiente |
| 06 | Pipelines DevSecOps | Media | Pendiente |
| 07 | Auditor CSPM en Python | Media-alta (muy "blog") | Pendiente |
| 08 | Agentes IA construyendo infra | Alta (trend + perfil del autor) | Pendiente |

## Notas editoriales

- **Orden confirmado:** 01→02 como se planeó; 02 necesita los mismos tests del 01
  reutilizados contra LocalStack (diseño ya preparado).
- **Posible artículo adicional 09:** "Fidelidad medida: qué dice el scores.json.gz
  de AWS y qué observamos nosotros" — los releases diarios publican puntuaciones
  de fidelidad por servicio; analizarlas es contenido exclusivo y barato de producir.
- **Posible artículo adicional 10:** "Emuladores oficiales vs mocks: qué debe saber
  un auditor" — posicionamiento cloud security del blog.
- 08 (agentes IA) se beneficiará de ejecutar primero 04 (IaC): los agentes generan
  Terraform, así que el harness IaC reutiliza.
- El lab 03 (seguridad) debe incluir explícitamente la advertencia de que emular
  configuración ≠ aplicar controles (posición oficial de AWS + nuestra verificación).
