#!/usr/bin/env python3
"""exp_c_boto3.py — Experimento C: S3/DynamoDB/SQS con Boto3 contra el emulador.

SEGURIDAD (fail-closed):
  - Aborta ANTES de crear clientes si el endpoint no es local (parsing de URL,
    no búsqueda de subcadena).
  - Credenciales de laboratorio explícitas y aisladas (nunca la cadena de
    proveedores por defecto de Boto3).
  - Variables de entorno AWS incompatibles eliminadas antes de crear clientes
    (endpoints por servicio, credenciales, perfiles, web identity, contenedores).
  - Comprueba identidad STS (cuenta 000000000000) antes de crear recursos; si
    falla, aborta sin realizar ninguna operación de escritura.
  - Endpoints explícitos para cada cliente.

Uso:
    python exp_c_boto3.py                 # ejecuta todas las pruebas
    python exp_c_boto3.py --self-test     # pruebas negativas de los controles
    python exp_c_boto3.py --list-ours     # lista recursos aws-emulator-lab-*
"""
from __future__ import annotations
import json
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from urllib.parse import urlparse

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

# ---------------------------------------------------------------------------
# 1. Controles anti-AWS-real: resolución del endpoint y limpieza de entorno
# ---------------------------------------------------------------------------

ENDPOINT = os.environ.get("AWS_ENDPOINT_URL", "")

# 1a. Limpieza de variables incompatibles (endpoints por servicio, credenciales
# alternativas, perfiles, web identity, contenedores)
_SCRUB = [
    "AWS_S3_ENDPOINT", "AWS_DYNAMODB_ENDPOINT", "AWS_SQS_ENDPOINT", "AWS_STS_ENDPOINT",
    "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN",
    "AWS_SECURITY_TOKEN", "AWS_PROFILE", "AWS_DEFAULT_PROFILE",
    "AWS_ROLE_ARN", "AWS_WEB_IDENTITY_TOKEN_FILE",
    "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", "AWS_CONTAINER_CREDENTIALS_FULL_URI",
]
for _var in _SCRUB:
    os.environ.pop(_var, None)

# Variables de proxy que podrían redirigir tráfico local por un proxy externo
for _var in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy",
             "ALL_PROXY", "all_proxy"):
    os.environ.pop(_var, None)
os.environ["NO_PROXY"] = "127.0.0.1,localhost"


def _endpoint_is_local(url: str) -> bool:
    """Valida por parsing que el endpoint es un endpoint local del laboratorio."""
    if not url:
        return False
    try:
        p = urlparse(url)
    except ValueError:
        return False
    return (
        p.scheme == "https"
        and p.hostname in ("127.0.0.1", "localhost", "::1")
        and (p.port or 443) < 10000
    )


# 1b. ABORT si el endpoint no es estrictamente local
if not _endpoint_is_local(ENDPOINT):
    sys.exit(
        "FATAL: AWS_ENDPOINT_URL no es un endpoint local válido "
        f"(obtenido: {ENDPOINT!r}). El script no ejecutará ninguna operación."
    )

# 1c. Credenciales de laboratorio explícitas (del fichero del emulador; nunca
# la cadena de proveedores de Boto3)
PORT = urlparse(ENDPOINT).port
EMU_DIR = os.path.expanduser(f"~/.aws/emulator/{PORT}")
_creds = {}
with open(os.path.join(EMU_DIR, "emulator_credentials")) as fh:
    for line in fh:
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.strip().split("=", 1)
            _creds[k.strip()] = v.strip()
LAB_CREDENTIALS = {
    "aws_access_key_id": _creds.get("aws_access_key_id", ""),
    "aws_secret_access_key": _creds.get("aws_secret_access_key", ""),
}
if not LAB_CREDENTIALS["aws_access_key_id"] or not LAB_CREDENTIALS["aws_secret_access_key"]:
    sys.exit("FATAL: no se pudieron leer las credenciales del emulador. Abortando.")

CA_BUNDLE = os.path.join(EMU_DIR, "ca.pem")

# ---------------------------------------------------------------------------
# 2. Clientes: endpoints explícitos, credenciales explícitas, timeouts cortos
# ---------------------------------------------------------------------------
CFG = Config(retries={"max_attempts": 2}, inject_host_prefix=False,
             connect_timeout=5, read_timeout=10)


def _client(service: str):
    return boto3.client(
        service,
        endpoint_url=ENDPOINT,            # endpoint explícito por cliente
        aws_access_key_id=LAB_CREDENTIALS["aws_access_key_id"],
        aws_secret_access_key=LAB_CREDENTIALS["aws_secret_access_key"],
        region_name="us-east-1",
        config=CFG,
        verify=CA_BUNDLE,                 # TLS explícito con la CA del emulador
    )


S3, DDB, SQS, STS = _client("s3"), _client("dynamodb"), _client("sqs"), _client("sts")

# ---------------------------------------------------------------------------
# 3. Comprobación de identidad ANTES de cualquier operación (precondición)
# ---------------------------------------------------------------------------
try:
    _account = STS.get_caller_identity()["Account"]
except Exception as e:  # noqa: BLE001
    sys.exit(f"FATAL: STS no respondió desde {ENDPOINT}: {e}. Abortando sin operaciones.")
if _account != "000000000000":
    sys.exit(
        f"FATAL: la identidad devuelta es la cuenta {_account!r} (esperada "
        "000000000000). NO se ejecutará ninguna operación: posibles credenciales "
        "o endpoint reales."
    )

# ---------------------------------------------------------------------------
# 4. Marco de resultados
# ---------------------------------------------------------------------------
RUN_ID = f"{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}{uuid.uuid4().hex[:6]}"
RESULTS: list[dict] = []
PREFIX = f"aws-emulator-lab-01-{RUN_ID}"


def record(test_id, desc, status, detail="", duration=0.0):
    RESULTS.append({
        "run_id": RUN_ID, "id": test_id, "objetivo": desc, "resultado": status,
        "detalle": str(detail)[:400], "duracion_s": round(duration, 3),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    icon = {"PASS": "✅", "FAIL": "❌", "PARTIAL": "⚠️", "UNSUPPORTED": "🚫"}.get(status, "·")
    print(f"{icon} {test_id}: {status} {('— ' + str(detail)) if detail else ''} ({duration:.2f}s)")


def timed(fn):
    t0 = time.perf_counter()
    try:
        detail = fn() or ""
        return detail, time.perf_counter() - t0, None
    except ClientError as e:
        code = e.response["Error"]["Code"]
        return (f"ClientError {code}: {e.response['Error']['Message']}",
                time.perf_counter() - t0, e)
    except Exception as e:  # noqa: BLE001
        return f"{type(e).__name__}: {e}", time.perf_counter() - t0, e


def _wait_table_active(name: str, attempts: int = 40):
    for _ in range(attempts):
        if DDB.describe_table(TableName=name)["Table"]["TableStatus"] == "ACTIVE":
            return
        time.sleep(0.25)


# ---------------------------------------------------------------------------
# 5. Pruebas funcionales (con limpieza garantizada vía finally)
# ---------------------------------------------------------------------------
def run_functional() -> int:
    failures = 0
    bucket = f"{PREFIX}-bucket"
    table = f"{PREFIX}-tbl"
    queue_name = f"{PREFIX}-q"

    ident, dur, _ = timed(lambda: STS.get_caller_identity()["Account"])
    record("C1", "STS identidad (precondición, cuenta 000000000000)", "PASS",
           f"cuenta={ident}", dur)

    _, dur, err = timed(lambda: S3.create_bucket(Bucket=bucket))
    record("C2", "S3 create_bucket", "PASS" if not err else "FAIL", err or bucket, dur)
    failures += bool(err)
    try:
        detail, dur, err = timed(lambda: (
            S3.put_object(Bucket=bucket, Key="demo/py.txt", Body=b"contenido-boto3"),
            S3.list_objects_v2(Bucket=bucket)["Contents"],
            S3.get_object(Bucket=bucket, Key="demo/py.txt")["Body"].read(),
            S3.delete_object(Bucket=bucket, Key="demo/py.txt")))
        record("C3", "S3 put/list/get/delete objeto",
               "PASS" if not err else "FAIL", err or "round-trip OK", dur)
        failures += bool(err)

        detail, dur, err = timed(lambda: (
            DDB.create_table(
                TableName=table,
                AttributeDefinitions=[{"AttributeName": "pk", "AttributeType": "S"}],
                KeySchema=[{"AttributeName": "pk", "KeyType": "HASH"}],
                BillingMode="PAY_PER_REQUEST"),
            _wait_table_active(table),
            DDB.put_item(TableName=table,
                         Item={"pk": {"S": "a"}, "datos": {"M": {"x": {"N": "1"}}}}),
            DDB.get_item(TableName=table, Key={"pk": {"S": "a"}})["Item"]["datos"]["M"]["x"]["N"],
        ))
        record("C4", "DynamoDB create/wait-ACTIVE/put/get",
               "PASS" if not err else "FAIL", err or "map+number OK", dur)
        failures += bool(err)

        qurl_holder = {}

        def sqs_roundtrip():
            qurl = SQS.create_queue(QueueName=queue_name)["QueueUrl"]
            SQS.send_message(QueueUrl=qurl, MessageBody=json.dumps({"tarea": "demo"}))
            msgs = SQS.receive_message(QueueUrl=qurl, MaxNumberOfMessages=1).get("Messages", [])
            assert msgs and json.loads(msgs[0]["Body"])["tarea"] == "demo"
            SQS.delete_message(QueueUrl=qurl, ReceiptHandle=msgs[0]["ReceiptHandle"])
            return qurl

        detail, dur, err = timed(lambda: qurl_holder.setdefault("q", sqs_roundtrip()))
        record("C5", "SQS create/send/receive/delete-message",
               "PASS" if not err else "FAIL", err or "mensaje JSON OK", dur)
        failures += bool(err)

        _, dur, err = timed(lambda: S3.delete_bucket(Bucket=bucket))
        record("C6", "S3 delete_bucket (limpieza)", "PASS" if not err else "FAIL",
               err or "HTTP 204", dur)
        failures += bool(err)
    finally:
        # Limpieza garantizada incluso con errores intermedios
        for cleanup in (
            lambda: S3.delete_object(Bucket=bucket, Key="demo/py.txt"),
            lambda: S3.delete_bucket(Bucket=bucket),
            lambda: DDB.delete_table(TableName=table),
            lambda: SQS.delete_queue(
                QueueUrl=SQS.get_queue_url(QueueName=queue_name)["QueueUrl"]),
        ):
            try:
                cleanup()
            except Exception:  # noqa: BLE001,S110
                pass

    out_dir = os.environ.get("RESULTS_DIR", "results/01-getting-started")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"results_c_boto3_{RUN_ID}.json")
    with open(path, "w") as fh:
        json.dump({"experimento": "C-boto3", "run_id": RUN_ID,
                   "endpoint": ENDPOINT, "resultados": RESULTS},
                  fh, indent=2, ensure_ascii=False)
    print(f"\nResultados escritos en {path} (run {RUN_ID})")
    return failures


# ---------------------------------------------------------------------------
# 6. Pruebas negativas: los controles deben ABORTAR, no degradarse
# ---------------------------------------------------------------------------
def run_self_test() -> int:
    print("== Pruebas negativas de los controles anti-AWS-real ==")
    failures = 0
    import subprocess

    def expect_abort(url, desc):
        nonlocal failures
        saved = os.environ.get("AWS_ENDPOINT_URL")
        os.environ["AWS_ENDPOINT_URL"] = url
        try:
            proc = subprocess.run([sys.executable, os.path.abspath(__file__)],
                                  capture_output=True, text=True, timeout=120)
            out = (proc.stderr or "") + (proc.stdout or "")
            ok = proc.returncode != 0 and "FATAL" in out
            print(f"  {'✅ PASS' if ok else '❌ FAIL'} — aborta con {desc}")
            failures += 0 if ok else 1
        finally:
            if saved is None:
                os.environ.pop("AWS_ENDPOINT_URL", None)
            else:
                os.environ["AWS_ENDPOINT_URL"] = saved

    expect_abort("https://amazonaws.com", "endpoint AWS real")
    expect_abort("http://127.0.0.1:9297", "endpoint local sin TLS")
    expect_abort("", "endpoint ausente")
    expect_abort("https://10.0.0.5:9297", "endpoint no-local (IP privada no loopback)")
    print("RESULT self-test:", "PASS" if failures == 0 else f"FAIL ({failures})")
    return failures


def main() -> int:
    if "--list-ours" in sys.argv:
        for b in S3.list_buckets()["Buckets"]:
            if b["Name"].startswith("aws-emulator-lab-"):
                print(b["Name"])
        return 0
    if "--self-test" in sys.argv:
        return run_self_test()
    return run_functional()


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
