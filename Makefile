# Makefile — AWS Emulator in Practice (lab 01)
# Comandos idempotentes; 'clean' solo elimina recursos de este proyecto.
# Funciona desde cualquier directorio de copia del repositorio.
SHELL := /bin/bash
REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PORT  ?= 9297
PY    := $(REPO_DIR)/.venv/bin

.PHONY: help setup start status test-native test-cli test-sdk test-persistence \
        test-docker test-selftest perf test-all stop clean stats

help:
	@echo "AWS Emulator in Practice — comandos:"
	@echo "  make setup            Instala dependencias fijadas (emulador, CLI, boto3)"
	@echo "  make start / stop     Arranca / detiene el emulador (puerto $(PORT))"
	@echo "  make status           Salud + identidad STS + recursos"
	@echo "  make test-cli         Experimento B (AWS CLI)"
	@echo "  make test-sdk         Experimento C (Boto3) + controles (aborta si no es local)"
	@echo "  make test-selftest    Pruebas negativas de los controles anti-AWS-real"
	@echo "  make test-persistence Experimento D (reinicio + multi-instancia)"
	@echo "  make test-docker      Experimento E (bridge + -p 127.0.0.1:PORT:PORT)"
	@echo "  make test-native      B+C+D (nativo)"
	@echo "  make test-all         B+C+D+E + selftest"
	@echo "  make perf             Mediciones de rendimiento (REPS=n, por defecto 3)"
	@echo "  make stats            Regenera totales desde los registros individuales"
	@echo "  make clean            Elimina SOLO recursos aws-emulator-lab-*"

setup:
	cd "$(REPO_DIR)" && bash scripts/bootstrap/install-deps.sh

start:
	cd "$(REPO_DIR)" && bash scripts/emulator/start.sh $(PORT)

stop:
	cd "$(REPO_DIR)" && bash scripts/emulator/stop.sh $(PORT)

status:
	cd "$(REPO_DIR)" && bash scripts/emulator/status.sh $(PORT)

test-cli:
	cd "$(REPO_DIR)" && source scripts/common/env.sh $(PORT) && \
	  RESULTS_DIR=results/01-getting-started bash labs/01-getting-started/exp_b_aws_cli.sh

test-sdk:
	cd "$(REPO_DIR)" && source scripts/common/env.sh $(PORT) && \
	  RESULTS_DIR=results/01-getting-started $(PY)/python labs/01-getting-started/exp_c_boto3.py

test-selftest:
	cd "$(REPO_DIR)" && source scripts/common/env.sh $(PORT) && \
	  $(PY)/python labs/01-getting-started/exp_c_boto3.py --self-test

test-persistence:
	cd "$(REPO_DIR)" && source scripts/common/env.sh $(PORT) && \
	  bash labs/01-getting-started/exp_d_persistence.sh

test-docker:
	cd "$(REPO_DIR)" && bash labs/01-getting-started/exp_e_docker.sh

test-native: test-cli test-sdk test-persistence

test-all: test-cli test-sdk test-selftest test-persistence test-docker

perf:
	cd "$(REPO_DIR)" && bash scripts/common/perf.sh

stats:
	cd "$(REPO_DIR)" && $(PY)/python scripts/common/gen_stats.py

clean:
	cd "$(REPO_DIR)" && source scripts/common/env.sh $(PORT) && \
	for r in $$($(PY)/python labs/01-getting-started/exp_c_boto3.py --list-ours 2>/dev/null); do \
	  echo "eliminando bucket $$r"; aws s3 rb "s3://$$r" --force >/dev/null; done; \
	for t in $$($(PY)/python scripts/common/list_ours_dynamodb.py 2>/dev/null); do \
	  echo "eliminando tabla $$t"; aws dynamodb delete-table --table-name "$$t" >/dev/null; done; \
	for q in $$($(PY)/python scripts/common/list_ours_sqs.py 2>/dev/null); do \
	  echo "eliminando cola $$q"; aws sqs delete-queue --queue-url "$$q" >/dev/null; done; \
	echo "Limpieza completada (solo recursos aws-emulator-lab-*)"
