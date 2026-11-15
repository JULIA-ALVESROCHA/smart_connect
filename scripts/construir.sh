#!/usr/bin/env bash
# =====================================================================
# SmartCity Connect - construcao completa e reproduzivel
#   bash scripts/construir.sh            # escala completa (500 mil habitantes)
#   bash scripts/construir.sh --pequeno  # 50 mil habitantes, para testar rapido
# Variaveis de conexao: PGHOST, PGPORT, PGUSER, PGPASSWORD (padrao: libpq).
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${SMARTCITY_DB:-smartcity}
GER_ARGS=()
[ "${1:-}" = "--pequeno" ] && GER_ARGS=(--habitantes 50000 --empresas 1500 --escolas 20)
export PGDATABASE=$DB
export PGOPTIONS="-c client_min_messages=warning"
psql_() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }
etapa() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
inicio=$(date +%s)

etapa "1/7 Dados públicos (IBGE, CNAE, CBO)"
python3 scripts/01_baixar_dados_publicos.py

etapa "2/7 Dados sintéticos de Nova Esperança Digital"
python3 scripts/02_gerar_dados_sinteticos.py ${GER_ARGS[@]+"${GER_ARGS[@]}"}

etapa "3/7 Banco e esquema (DDL, restrições, gatilhos, auditoria)"
psql_ -d postgres -c "DROP DATABASE IF EXISTS $DB WITH (FORCE)" -c "CREATE DATABASE $DB ENCODING 'UTF8' TEMPLATE template0"
for f in sql/01_*.sql sql/02_*.sql sql/03_*.sql sql/04_*.sql sql/05_*.sql sql/06_*.sql sql/07_*.sql; do echo "  $f"; psql_ -f "$f"; done

etapa "4/7 Carga (COPY) e índices"
psql_ -f sql/08_carga.sql
psql_ -f sql/09_indices.sql

etapa "5/7 Segurança e relatórios"
psql_ -f sql/10_seguranca.sql
psql_ -f sql/11_relatorios.sql

etapa "6/7 Testes"
mkdir -p docs/evidencias
psql -X -f testes/01_testes_regras_de_negocio.sql 2>&1 | grep -v -E '^(BEGIN|SET|CREATE|DO|ROLLBACK)?$' | tee docs/evidencias/01_testes_regras_de_negocio.txt | tail -3
bash testes/02_testes_seguranca.sh > docs/evidencias/02_testes_seguranca.txt; tail -1 docs/evidencias/02_testes_seguranca.txt
psql -X -f testes/03_auditoria_conformidade.sql | tee docs/evidencias/03_auditoria_conformidade.txt | grep -c ' OK$' | sed 's/^/  regras de conformidade OK: /'
if grep -q 'VIOLAÇÃO' docs/evidencias/03_auditoria_conformidade.txt || grep -q FALHOU docs/evidencias/01_testes_regras_de_negocio.txt; then
  echo "ERRO: ha testes falhando"; exit 1; fi

etapa "7/7 Evidências: consultas, operações, desempenho, dashboard"
psql -X -f sql/12_consultas.sql > docs/evidencias/05_consultas.txt 2>&1
psql -X -f sql/13_operacoes_exemplo.sql > docs/evidencias/06_operacoes_exemplo.txt 2>&1
python3 testes/04_desempenho.py > /dev/null
python3 dashboard/gerar_dashboard.py
python3 scripts/03_gerar_documentacao.py
psql -X -c "SELECT * FROM rel.kpi_geral" -x
echo "Concluído em $(( $(date +%s) - inicio )) s."
