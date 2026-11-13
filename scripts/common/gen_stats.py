#!/usr/bin/env python3
"""gen_stats.py — genera las estadísticas del lab a partir de los registros
individuales de results.json (fuente única de verdad; los totales NUNCA se
mantienen a mano).

Clasificación metodológica:
  - Pruebas funcionales: resultados de operaciones ejecutadas (PASS/FAIL/PARTIAL/...)
  - Observaciones documentales (OBSERVADO): hechos verificados que no son una
    operación funcional de un servicio AWS emulado; se contabilizan aparte.
"""
import json
import os
import sys

FUNCTIONAL = {"PASS", "FAIL", "PARTIAL", "UNSUPPORTED", "NOT_TESTED", "BLOCKED"}
DOCUMENTAL = {"OBSERVADO"}

def main(results_path: str) -> int:
    data = json.load(open(results_path))
    rows = data["resultados"]
    func = [r for r in rows if r["resultado"] in FUNCTIONAL]
    doc = [r for r in rows if r["resultado"] in DOCUMENTAL]
    unknown = [r for r in rows if r["resultado"] not in FUNCTIONAL | DOCUMENTAL]
    stats = {
        "pruebas_funcionales": len(func),
        "observaciones_documentales": len(doc),
        "totales_funcionales": {k: sum(1 for r in func if r["resultado"] == k)
                                for k in sorted(FUNCTIONAL)},
        "ids_desconocidos": [r["id"] for r in unknown],
        "duracion_total_s": round(sum(r.get("duracion_s", 0) for r in func), 2),
    }
    data["resumen"] = {
        "metodologia": "totales generados desde 'resultados'; OBSERVADO se contabiliza aparte",
        **stats,
        "comprobacion": f"{len(func)} funcionales + {len(doc)} documentales = {len(rows)} registros",
    }
    json.dump(data, open(results_path, "w"), indent=2, ensure_ascii=False)
    print(json.dumps(stats, indent=2, ensure_ascii=False))
    print(f"\nTotales actualizados en {results_path}")
    return 1 if unknown else 0


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "results/01-getting-started/results.json"
    sys.exit(main(path if os.path.isabs(path) else path))
