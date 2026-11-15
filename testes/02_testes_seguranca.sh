#!/usr/bin/env bash
# SmartCity Connect - testes de seguranca: conecta como cada usuario de demonstracao
# e confere o que ele pode e nao pode fazer (GER-RNF01/02, CID-RN05, ASS-RNF01/02, EMP-RNF02).
# Uso: PGHOST=localhost bash testes/02_testes_seguranca.sh
set -u
H=${PGHOST:-localhost}; DB=${PGDATABASE:-smartcity}
ok=0; falha=0
t() { # usuario  esperado(permite|nega)  descricao  sql
  local u=$1 esp=$2 desc=$3 sql=$4 out rc
  out=$(PGPASSWORD=$u psql -h "$H" -U "$u" -d "$DB" -X -q -t -A -v ON_ERROR_STOP=1 \
        -c "BEGIN" -c "$sql" -c "ROLLBACK" 2>&1); rc=$?
  if { [ $esp = permite ] && [ $rc -eq 0 ]; } || { [ $esp = nega ] && [ $rc -ne 0 ]; }; then
    ok=$((ok+1)); r=PASSOU; else falha=$((falha+1)); r=FALHOU; fi
  printf '%-6s | %-16s | %-7s | %s\n          -> %s\n' "$r" "$u" "$esp" "$desc" "$(echo "$out" | tr '\n' ' ' | cut -c1-110)"
}
echo "== GER-RNF01 autenticacao"
out=$(PGPASSWORD=senha_errada psql -h "$H" -U ana_cadastro -d "$DB" -c "select 1" 2>&1)
if echo "$out" | grep -q "password authentication failed"; then ok=$((ok+1)); echo "PASSOU | senha errada e recusada"; else falha=$((falha+1)); echo "FALHOU | $out"; fi

echo "== CID (CID-RN05: so o perfil de cadastro altera dados pessoais)"
t ana_cadastro     permite "Cadastro consulta cidadao pelo CPF completo"       "SELECT cpf, nome_mae FROM cid.cidadao WHERE id_cidadao = 1"
t ana_cadastro     permite "Cadastro atualiza nome social"                      "UPDATE cid.cidadao SET nome_social = 'Teste' WHERE id_cidadao = 1"
t ana_cadastro     nega    "Cadastro nao apaga cidadao"                         "DELETE FROM cid.cidadao WHERE id_cidadao = 1"
t ana_cadastro     nega    "Cadastro nao le dados da assistencia social"        "SELECT * FROM ass.beneficiario LIMIT 1"
t bruno_escola     nega    "Escola nao altera dados pessoais do cidadao"        "UPDATE cid.cidadao SET nome = 'X' WHERE id_cidadao = 1"
t bruno_escola     nega    "Escola nao le CPF completo nem filiacao"            "SELECT cpf, nome_mae FROM cid.cidadao LIMIT 1"
t bruno_escola     permite "Escola ve dados minimos (CPF mascarado)"            "SELECT cpf_mascarado, nome FROM cid.vw_cidadao_basico LIMIT 1"
t bruno_escola     permite "Escola localiza cidadao pelo CPF via funcao"        "SELECT * FROM cid.fn_localizar_cidadao((SELECT '00000000000'))"
echo "== EDU"
t bruno_escola     permite "Secretaria de educacao registra matricula"          "UPDATE edu.matricula SET frequencia_pct = frequencia_pct WHERE id_matricula = 1"
t carla_professora permite "Professor consulta alunos da disciplina"            "SELECT count(*) FROM edu.vw_alunos_disciplina WHERE cod_disciplina = 'EF05-MAT'"
t carla_professora nega    "Professor nao altera matricula"                     "UPDATE edu.matricula SET nota_final = 10 WHERE id_matricula = 1"
t carla_professora nega    "Professor nao ve tabela de alunos com id do cidadao" "SELECT * FROM edu.aluno LIMIT 1"
echo "== EMP (EMP-RNF02 + RLS por empresa)"
t diego_emprego    permite "Operador de emprego le todas as vagas"              "SELECT count(*) FROM emp.vaga"
t diego_emprego    nega    "Operador nao altera historico de candidaturas"      "UPDATE emp.candidatura_historico SET observacao = 'x' WHERE id_historico = 1"
t empresa_demo     permite "Empresa ve vagas"                                   "SELECT count(*) FROM emp.vaga"
t empresa_demo     nega    "RLS: empresa nao enxerga vagas de outra empresa"    "DO \$\$ BEGIN IF (SELECT count(DISTINCT id_empresa) FROM emp.vaga) > 1 THEN RAISE EXCEPTION 'vazou'; END IF; IF (SELECT count(*) FROM emp.vaga) = 0 THEN RAISE EXCEPTION 'vazio'; END IF; RAISE EXCEPTION 'isolado (ok)'; END \$\$"
t empresa_demo     nega    "RLS: empresa nao publica vaga em nome de outra"     "INSERT INTO emp.vaga (id_empresa,id_area,cod_cbo,titulo,tipo_contrato,id_escolaridade_minima) VALUES ((SELECT max(id_empresa) FROM emp.empresa WHERE situacao='ATIVA'),1,'411010','x','CLT',5)"
t empresa_demo     nega    "Empresa nao le dados pessoais do candidato"         "SELECT cpf FROM cid.cidadao LIMIT 1"
echo "== ASS (ASS-RNF01/02 dados sensiveis)"
t elisa_cras       permite "Assistencia le beneficiarios e marca PcD"           "SELECT count(*) FROM ass.beneficiario WHERE pcd"
t elisa_cras       permite "Assistencia avalia elegibilidade (le EDU/EMP via funcao)" "SELECT * FROM ass.fn_avaliar_elegibilidade(1, 1)"
t elisa_cras       nega    "Assistencia nao altera atendimento ja registrado"   "UPDATE ass.atendimento SET descricao = 'x' WHERE id_atendimento = 1"
t elisa_cras       nega    "Assistencia nao le matriculas diretamente"          "SELECT * FROM edu.matricula LIMIT 1"
t bruno_escola     nega    "Escola nao le beneficiarios"                        "SELECT * FROM ass.beneficiario LIMIT 1"
t diego_emprego    nega    "Emprego nao le renda familiar"                      "SELECT renda_mensal FROM ass.familia_membro LIMIT 1"
echo "== Relatorios e auditoria"
t fabio_gestor     permite "Gestor le indicadores agregados"                    "SELECT * FROM rel.kpi_geral"
t fabio_gestor     nega    "Gestor nao le tabela de cidadaos"                   "SELECT * FROM cid.cidadao LIMIT 1"
t gabi_auditora    permite "Auditor le a trilha de auditoria"                   "SELECT count(*) FROM aud.log_auditoria"
t gabi_auditora    nega    "Auditor nao apaga a trilha"                         "DELETE FROM aud.log_auditoria"
t ana_cadastro     nega    "Operador nao le a trilha de auditoria"              "SELECT * FROM aud.log_auditoria LIMIT 1"
echo "-----"; echo "total=$((ok+falha)) passou=$ok falhou=$falha"
[ $falha -eq 0 ]
