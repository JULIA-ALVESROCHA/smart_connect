#!/usr/bin/env python3
"""
SmartCity Connect - Estudo de desempenho (EMP-RNF03, CID-RNF04, Ponto em aberto 05).

Para cada consulta de requisito, mede o tempo real com EXPLAIN ANALYZE em dois cenarios:
  sem o indice (DROP INDEX dentro de uma transacao desfeita) e com o indice.
Cada medicao e a mediana de 5 execucoes com cache aquecido.
Gera docs/evidencias/04_desempenho.md. Requer psql no PATH e variaveis PG*.
"""
import json, os, statistics, subprocess
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
REPETICOES = 5
CASOS = [
  ("CID-RF07", "Busca de cidadão por trecho do nome (sem acento)", "cid.ix_cidadao_nome_trgm",
   "SELECT id_cidadao, nome FROM cid.cidadao WHERE ref.fn_normalizar(nome) LIKE '%' || ref.fn_normalizar('Joao Batista Ribeiro') || '%'"),
  ("CID-RF07", "Busca por CPF (índice da UNIQUE, sempre presente)", None,
   "SELECT id_cidadao FROM cid.cidadao WHERE cpf = (SELECT cpf FROM cid.cidadao WHERE id_cidadao = 250000)"),
  ("EMP-RF07", "Vagas abertas de uma área, mais recentes primeiro", "emp.ix_vaga_aberta_area",
   "SELECT id_vaga, titulo, salario FROM emp.vaga WHERE status = 'ABERTA' AND id_area = 3 ORDER BY data_publicacao DESC LIMIT 50"),
  ("EMP-RF08", "Candidatos de uma vaga", "emp.ix_candidatura_vaga",
   "SELECT c.id_candidatura, c.status FROM emp.candidatura c WHERE c.id_vaga = 12345"),
  ("EMP-RF08", "Candidatos de uma empresa (vaga + candidatura)", "emp.ix_vaga_empresa",
   "SELECT count(*) FROM emp.candidatura c JOIN emp.vaga v USING (id_vaga) WHERE v.id_empresa = 3211"),
  ("EMP-UC04", "Linha do tempo de uma candidatura", "emp.ix_historico_candidatura",
   "SELECT * FROM emp.candidatura_historico WHERE id_candidatura = 100000 ORDER BY data_hora"),
  ("EDU-RF07", "Alunos de uma disciplina no período", "edu.ix_matricula_disciplina_periodo",
   "SELECT count(*) FROM edu.matricula WHERE id_disciplina = 37 AND id_periodo = 3"),
  ("ASS-RF06", "Histórico de atendimentos de um beneficiário", "ass.ix_atendimento_beneficiario",
   "SELECT * FROM ass.atendimento WHERE id_beneficiario = 4321 ORDER BY data_hora DESC"),
  ("ASS-RF07", "Beneficiários ativos de um programa", "ass.ix_beneficio_programa_ativo",
   "SELECT id_beneficiario, valor_mensal FROM ass.beneficio_concedido WHERE id_programa = 3 AND situacao = 'ATIVO'"),
  ("ASS", "Atendimentos do último mês (BRIN)", "ass.ix_atendimento_data_brin",
   "SELECT count(*) FROM ass.atendimento WHERE data_hora >= now() - interval '30 days'"),
  ("ASS-RF08", "Atendimentos por região (relatório R06, agregação completa)", None,
   "SELECT regiao, sum(atendimentos) FROM rel.r06_atendimentos_por_regiao WHERE bairro IS NULL AND regiao IS NOT NULL GROUP BY regiao"),
  ("DASH", "Painel territorial: visão normal x materializada", None,
   "SELECT * FROM rel.r08_painel_territorial"),
  ("DASH", "Painel territorial materializado", None,
   "SELECT * FROM rel.mv_painel_territorial"),
]


def psql(sql):
    r = subprocess.run(["psql", "-X", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1"], input=sql, text=True,
                       capture_output=True, env=os.environ)
    if r.returncode:
        raise RuntimeError(r.stderr)
    return r.stdout


def medir(consulta, indice=None):
    pre = f"BEGIN; DROP INDEX {indice};" if indice else "BEGIN;"
    tempos, plano = [], None
    psql(f"{pre} {consulta}; ROLLBACK;")  # aquece cache
    for _ in range(REPETICOES):
        out = psql(f"{pre} EXPLAIN (ANALYZE, FORMAT JSON) {consulta}; ROLLBACK;")
        j = json.loads(out[out.index("["):out.rindex("]") + 1])[0]
        tempos.append(j["Execution Time"] + j["Planning Time"])
        plano = j["Plan"]
    return statistics.median(tempos), no_principal(plano)


def no_principal(p):
    """Descreve o metodo de acesso mais relevante do plano."""
    achados = []
    def andar(n):
        t = n["Node Type"]
        if "Scan" in t:
            achados.append(t + (f" ({n['Index Name']})" if "Index Name" in n else f" ({n.get('Relation Name', '')})"))
        for f in n.get("Plans", []):
            andar(f)
    andar(p)
    return "; ".join(dict.fromkeys(achados))[:120]


def main():
    linhas = ["# Estudo de desempenho", "",
              f"Mediana de {REPETICOES} execuções, tempo de planejamento + execução, cache aquecido. "
              "Base com 500 mil cidadãos. \"Sem índice\" = índice removido dentro de uma transação desfeita.", "",
              "| Req. | Consulta | Sem índice (ms) | Com índice (ms) | Ganho | Plano com índice |",
              "|---|---|---:|---:|---:|---|"]
    for cod, desc, indice, sql in CASOS:
        com, plano = medir(sql)
        if indice:
            sem, plano_sem = medir(sql, indice)
            ganho = f"{sem / com:,.0f}x" if com > 0 else "-"
            linhas.append(f"| {cod} | {desc} | {sem:,.2f} | {com:,.2f} | {ganho} | {plano} |")
        else:
            linhas.append(f"| {cod} | {desc} | - | {com:,.2f} | - | {plano} |")
        print(linhas[-1])
    tam = psql("""SELECT string_agg(format('| %s | %s | %s |', n.nspname || '.' || c.relname, pg_size_pretty(pg_relation_size(c.oid)),
                  (SELECT pg_size_pretty(pg_relation_size(i.indrelid)) FROM pg_index i WHERE i.indexrelid = c.oid)), E'\\n' ORDER BY pg_relation_size(c.oid) DESC)
                  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                 WHERE c.relkind = 'i' AND c.relname LIKE 'ix\\_%'""")
    linhas += ["", "## Tamanho dos índices secundários", "", "| Índice | Tamanho | Tamanho da tabela |", "|---|---:|---:|", tam.strip()]
    tot = psql("SELECT pg_size_pretty(pg_database_size(current_database()))").strip()
    linhas += ["", f"Tamanho total do banco: **{tot}**."]
    (RAIZ / "docs" / "evidencias" / "04_desempenho.md").write_text("\n".join(linhas) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
