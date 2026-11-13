#!/usr/bin/env bash
# perf.sh — mediciones de rendimiento del emulador con metodología consistente.
# Repite N veces: arranque (proceso y hasta health), RSS/PSS en reposo (t=0 y t=30s),
# memoria tras batería de pruebas y tras limpieza. Genera JSON+Markdown.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
REPS="${REPS:-3}"
PORT="${PORT:-9297}"
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$REPO_DIR/results/01-getting-started/perf_${RUN_ID}.json"
LOGS="$REPO_DIR/results/01-getting-started/logs"
mkdir -p "$(dirname "$OUT")" "$LOGS"

mem_of_pid() {  # RSS y PSS en KiB desde /proc (PSS vía smaps_rollup)
  local pid=$1
  local rss=$(awk '/VmRSS/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
  local pss=$(awk '/^Pss:/{print $2}' "/proc/$pid/smaps_rollup" 2>/dev/null || echo 0)
  echo "$rss $pss"
}

echo "Deteniendo instancias previas del puerto $PORT..."
bash "$SCRIPT_DIR/emulator/stop.sh" "$PORT" >/dev/null 2>&1 || true

python3 - "$OUT" "$REPS" "$PORT" "$LOGS" <<'PYEOF'
import json, statistics, subprocess, sys, time, os
out_path, reps, port, logs = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
repo = os.path.expanduser("~/aws-emulator-in-practice")

def stop():
    subprocess.run([f"{repo}/scripts/emulator/stop.sh", port],
                   capture_output=True, cwd=repo)

def start():
    t0 = time.perf_counter()
    r = subprocess.run([f"{repo}/scripts/emulator/start.sh", port],
                       capture_output=True, text=True, cwd=repo)
    t_full = time.perf_counter() - t0
    # arranque del proceso hasta health = lo que informa start.sh
    line = [l for l in r.stdout.splitlines() if "arranque" in l]
    t_proc = float(line[0].split("arranque:")[1].strip().rstrip("s")) if line else None
    pid = int(line[0].split("pid ")[1].split(",")[0]) if line else None
    return pid, t_proc, t_full

def mem(pid):
    rss = pss = 0
    try:
        with open(f"/proc/{pid}/status") as fh:
            rss = int([l for l in fh if l.startswith("VmRSS")][0].split()[1])
        with open(f"/proc/{pid}/smaps_rollup") as fh:
            pss = int([l for l in fh if l.startswith("Pss:")][0].split()[1])
    except Exception:
        pass
    return {"rss_kib": rss, "pss_kib": pss}

data = {"fecha": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "repeticiones": reps, "puerto": port, "mediciones": []}

for i in range(reps):
    stop(); time.sleep(2)
    pid, t_proc, t_full = start()
    m_arranque = mem(pid); time.sleep(30); m_reposo30 = mem(pid)
    env = dict(os.environ,
               AWS_ENDPOINT_URL=f"https://127.0.0.1:{port}",
               AWS_SHARED_CREDENTIALS_FILE=os.path.expanduser(f"~/.aws/emulator/{port}/emulator_credentials"),
               AWS_CONFIG_FILE=os.path.expanduser(f"~/.aws/emulator/{port}/config"),
               AWS_CA_BUNDLE=os.path.expanduser(f"~/.aws/emulator/{port}/ca.pem"),
               AWS_EC2_METADATA_DISABLED="true")
    rc = subprocess.run(["bash", f"{repo}/scripts/emulator/../emulator/status.sh", port],
                        env=env, capture_output=True)  # operaciones de lectura ligeras
    t0 = time.perf_counter()
    for _ in range(10):
        subprocess.run(["aws", "s3", "ls"], env=env, capture_output=True)
    t_bateria = time.perf_counter() - t0
    m_bateria = mem(pid)
    stop(); time.sleep(2)
    data["mediciones"].append({
        "repeticion": i + 1,
        "arranque_proceso_s": round(t_proc, 2),
        "arranque_hasta_health_s": round(t_full, 2),
        "mem_arranque": m_arranque, "mem_reposo_30s": m_reposo30,
        "bateria_10x_s3_ls_s": round(t_bateria, 2), "mem_tras_bateria": m_bateria,
        "log": f"logs/perf_{port}_rep{i+1}.log",
    })

def med(xs): return round(statistics.median(xs), 1)
for key in ("arranque_proceso_s", "arranque_hasta_health_s", "bateria_10x_s3_ls_s"):
    vals = [m[key] for m in data["mediciones"]]
    data[key] = {"mediana": med(vals), "min": min(vals), "max": max(vals)}
for stage in ("mem_arranque", "mem_reposo_30s", "mem_tras_bateria"):
    rss = [m[stage]["rss_kib"] for m in data["mediciones"]]
    pss = [m[stage]["pss_kib"] for m in data["mediciones"]]
    data[stage] = {"rss_mib_mediana": med([v/1024 for v in rss]),
                   "pss_mib_mediana": med([v/1024 for v in pss]),
                   "rss_mib_min_max": [round(min(rss)/1024,1), round(max(rss)/1024,1)]}

json.dump(data, open(out_path, "w"), indent=2)
print(json.dumps({k: data[k] for k in data if k != "mediciones"}, indent=2))
print(f"\nGuardado: {out_path}")
PYEOF
