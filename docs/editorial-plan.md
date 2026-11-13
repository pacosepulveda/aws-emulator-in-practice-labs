# Plan editorial (formato breve, 700-1.000 palabras por artículo)

Formato: artículo de blog breve centrado en UN hallazgo o pregunta técnica.
Toda la profundidad vive en este repositorio (reproducible). Idiomas: ES y EN.

| # | Artículo (título tentativo) | Hallazgo central | Fuente |
|---|---|---|---|
| 1 | He probado AWS Emulator: el nuevo emulador oficial de AWS | Qué es, cómo se instala con verificación, qué cumple de lo que promete la doc (arranque 0,6 s, estado en memoria verificado, 33/33 PASS) | Lab 01 |
| 2 | AWS Emulator en Docker: problemas y soluciones | `-b 0.0.0.0` es imprescindible (el fallo v0 y su causa), CPU x86-64-v2, rpm -K sin gpg-agent, aislamiento localhost | Lab 01 |
| 3 | ¿Funciona Terraform con AWS Emulator? | Sí, con matices: provider v6, endpoints, y la divergencia de fidelidad de describe_table (drift falso) | Lab 02 |
| 4 | AWS Emulator vs LocalStack | Comparativa con la batería reutilizable (requiere diseño de backend, ver localstack-review.md) | Labs 01+02 |
| 5 | AWS Emulator y seguridad | Emular configuración ≠ aplicar controles; controles anti-AWS-real y pruebas negativas | Lab 01 |
| 6 | Rendimiento y consumo de recursos | Metodología RSS/PSS, 0,6 s arranque, 286 MiB vs 160 MiB documentales | Lab 01 |

Reglas editoriales:
- El artículo enlaza SIEMPRE al repo (hallazgo + cómo reproducirlo).
- Sin datos internos de infraestructura (ver escaneo de la rama pública).
- Resultados = results.json generados automáticamente; nada de totales a mano.
