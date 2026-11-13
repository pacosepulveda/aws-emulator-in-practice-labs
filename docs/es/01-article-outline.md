# Esquema del Artículo 01 (ES)

## Título propuesto
**AWS Emulator: el emulador oficial de AWS — instalación y primeras pruebas reales**

## Estructura (basada en resultados reales del lab 01)

1. **El problema que resuelve** — probar integraciones AWS sin cuenta, sin coste,
   sin riesgo de llamar a AWS real; contexto: LocalStack dominaba este nicho.
2. **Qué es AWS Emulator** — emulador oficial (sep 2026), Rust, un crate por servicio,
   fidelidad medida y publicada en cada release.
3. **Instalación en Linux** — paquete .deb firmado (verificación GPG paso a paso),
   `/opt/aws-emulator`, primeros comandos. (Evidencia: Exp A)
4. **Arquitectura y funcionamiento** — endpoint único HTTPS localhost:9297, SigV4,
   credenciales efímeras por ejecución, estado en memoria. (Diagrama Mermaid)
5. **Configuración segura de CLI y Boto3** — env vars, anti-llamadas-accidentales a
   AWS real, verificación STS de cuenta 000000000000.
6. **Primeras pruebas** — S3/DynamoDB/SQS con CLI y Boto3; tabla de resultados
   PASS/FAIL/PARTIAL con duraciones. (Evidencia: Exp B, C)
7. **Persistencia y multi-instancia** — qué sobrevive a un reinicio (verificado,
   no asumido). (Evidencia: Exp D)
8. **¿Y en Docker?** — sin imagen oficial; Dockerfile oficial (AL2023 + RPM verificado) con `-b 0.0.0.0`, red bridge y `-p 127.0.0.1:`; el fallo inicial v0 se narra como aprendizaje (pivoting: CPU host, gpg-agent, rpm -K) y la verificación
   GPG. (Evidencia: Exp E)
9. **Problemas encontrados y soluciones** — los que hayamos documentado.
10. **Ventajas y limitaciones** — fidelidad, servicios soportados, brechas IAM.
11. **Consideraciones de seguridad** — "no usar para probar seguridad" (AWS) y
    qué significa: emular config ≠ aplicar controles.
12. **Casos de uso recomendados** y qué NO hacer con el emulador.
13. **Referencias** — docs oficiales, repo, fechas de consulta.

## Métricas sugeridas
- Tabla resumen (GENERADA por make stats): 40 funcionales — 35 PASS / 4 FAIL (conservados como didáctica con causa raíz) / 1 PARTIAL + 1 observación documental
- Tiempo de arranque medido, RAM en reposo medida
