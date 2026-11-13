# Metodología de medición — Lab 01

**Script:** `scripts/common/perf.sh` (REPS=n, PORT=9297) · **Salida:** `results/01-getting-started/perf_<run>.json`

## Tiempo de arranque

Dos definiciones separadas (ambas se registran):

1. **arranque_proceso_s:** tiempo desde el lanzamiento del binario hasta que el
   health check responde `ok` (lo que informa `scripts/emulator/start.sh`, que
   sondea `/__admin/health` con la CA generada cada 0,5 s).
2. **arranque_hasta_health_s:** el procedimiento completo del script (incluye
   guard de health previo, escritura de pidfile y la espera activa).

`T0 = date +%s.%N` antes de `nohup aws-emulator -p PORT -t off &` y
`T1` tras el primer health OK.

## Memoria (RSS y PSS)

- **RSS:** `VmRSS` de `/proc/<pid>/status` (KB→MiB).
- **PSS:** campo `Pss:` de `/proc/<pid>/smaps_rollup` (proporcional: reparte las
  páginas compartidas entre procesos; más representativo que RSS para comparar).

## Fases medidas (por repetición)

| Fase | Definición |
|---|---|
| mem_arranque | inmediatamente tras el primer health OK |
| mem_reposo_30s | tras 30 s sin tráfico |
| bateria_10x_s3_ls_s | duración de 10 llamadas `aws s3 ls` |
| mem_tras_bateria | tras la batería |
| (limpieza) | stop.sh tras cada repetición; la memoria tras limpieza se deriva del arranque de la siguiente repetición |

## Repeticiones y agregación

- 3 repeticiones por defecto (`REPS=n` configurable), instancias limpias entre ellas
  (stop→sleep 2→start).
- Se reportan **mediana, min y max** por métrica (nada de medias de una sola muestra).
- Segunda instancia: cubierta por el experimento D/E (arranque en otro puerto con
  aislamiento verificado); su memoria se mide con el mismo mecanismo al añadir
  casos futuros.

## Clasificación frente a la documentación

Una diferencia entre nuestra medición (RSS/PSS, proceso completo) y una cifra de la
documentación se registra como **dato observado**, no como fallo funcional, salvo
evidencia de comportamiento incorrecto.
