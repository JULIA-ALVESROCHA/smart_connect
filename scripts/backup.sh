#!/usr/bin/env bash
# =====================================================================
# SmartCity Connect - backup logico com verificacao de restauracao
#   bash scripts/backup.sh               # gera backups/smartcity_AAAAMMDD_HHMM.dump
#   bash scripts/backup.sh --verificar   # tambem restaura numa base temporaria e compara contagens
# Formato custom (-Fc): comprimido, restauracao seletiva e paralela (pg_restore -j).
# Retencao: mantem os 7 mais recentes. Para producao, ver docs/05_seguranca_auditoria_backup.md
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${PGDATABASE:-smartcity}; DIR=backups; RETER=7
mkdir -p "$DIR"; chmod 700 "$DIR"
ARQ="$DIR/${DB}_$(date +%Y%m%d_%H%M).dump"
pg_dump -Fc -Z 6 -d "$DB" -f "$ARQ"
sha256sum "$ARQ" > "$ARQ.sha256"
echo "backup: $ARQ ($(du -h "$ARQ" | cut -f1))"
ls -1t "$DIR"/*.dump | tail -n +$((RETER + 1)) | while read -r velho; do rm -f "$velho" "$velho.sha256"; done
if [ "${1:-}" = "--verificar" ]; then
  T=${DB}_restore_teste
  psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $T" -c "CREATE DATABASE $T TEMPLATE template0"
  pg_restore -j 2 -d "$T" "$ARQ"
  Q="SELECT string_agg(n || '=' || c, ' ' ORDER BY n) FROM (SELECT 'cidadao' n, count(*) c FROM cid.cidadao UNION ALL SELECT 'matricula', count(*) FROM edu.matricula
     UNION ALL SELECT 'candidatura', count(*) FROM emp.candidatura UNION ALL SELECT 'atendimento', count(*) FROM ass.atendimento UNION ALL SELECT 'auditoria', count(*) FROM aud.log_auditoria) x"
  A=$(psql -X -At -d "$DB" -c "$Q"); B=$(psql -X -At -d "$T" -c "$Q")
  echo "origem:     $A"; echo "restaurado: $B"
  psql -X -q -d postgres -c "DROP DATABASE $T"
  [ "$A" = "$B" ] && echo "restauracao verificada: contagens identicas" || { echo "ERRO: divergencia"; exit 1; }
fi
