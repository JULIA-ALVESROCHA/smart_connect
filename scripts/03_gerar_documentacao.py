#!/usr/bin/env python3
"""
SmartCity Connect - gera diagramas ER (Mermaid -> SVG) e o dicionario de dados
diretamente do catalogo do PostgreSQL. A documentacao nunca diverge do banco.
Saida: docs/diagramas/*.mmd, *.svg e docs/03_dicionario_de_dados.md
Requer psql; para SVG, mermaid-cli (mmdc). Sem mmdc, gera so os .mmd.
"""
import json, os, shutil, subprocess
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIAG = RAIZ / "docs" / "diagramas"; DIAG.mkdir(parents=True, exist_ok=True)
ESQUEMAS = ["ref", "cid", "edu", "emp", "ass", "aud"]


def q(sql):
    r = subprocess.run(["psql", "-X", "-q", "-t", "-A", "-c", sql], capture_output=True, text=True, env=os.environ)
    if r.returncode: raise SystemExit(r.stderr)
    return json.loads(r.stdout.strip() or "[]")


cols = q("""SELECT json_agg(x ORDER BY esq, tab, ord) FROM (
  SELECT n.nspname esq, c.relname tab, a.attnum ord, a.attname col, format_type(a.atttypid, a.atttypmod) tipo, a.attnotnull nn,
         pg_get_expr(d.adbin, d.adrelid) padrao, col_description(c.oid, a.attnum) com,
         EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid AND k.contype = 'p' AND a.attnum = ANY (k.conkey)) pk,
         EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid AND k.contype = 'f' AND a.attnum = ANY (k.conkey)) fk,
         EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid AND k.contype = 'u' AND k.conkey = ARRAY[a.attnum]) uk
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_attribute a ON a.attrelid = c.oid
    LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
   WHERE c.relkind = 'r' AND n.nspname = ANY ('{ref,cid,edu,emp,ass,aud}') AND a.attnum > 0 AND NOT a.attisdropped) x""")
tabs = q("""SELECT json_agg(x) FROM (SELECT n.nspname esq, c.relname tab, obj_description(c.oid) com, c.reltuples::bigint linhas
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = 'r' AND n.nspname = ANY ('{ref,cid,edu,emp,ass,aud}')) x""")
fks = q("""SELECT json_agg(x) FROM (
  SELECT n.nspname esq, c.relname tab, fn.nspname resq, f.relname rtab,
         (SELECT array_agg(attname ORDER BY attnum) FROM pg_attribute WHERE attrelid = k.conrelid AND attnum = ANY (k.conkey)) cols,
         (SELECT bool_and(attnotnull) FROM pg_attribute WHERE attrelid = k.conrelid AND attnum = ANY (k.conkey)) obrig,
         EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = k.conrelid AND i.indisunique AND i.indpred IS NULL
                 AND (i.indkey::int2[])[0:] @> k.conkey AND array_length(i.indkey::int2[], 1) = array_length(k.conkey, 1)) unico
    FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_class f ON f.oid = k.confrelid JOIN pg_namespace fn ON fn.oid = f.relnamespace
   WHERE k.contype = 'f' AND n.nspname = ANY ('{ref,cid,edu,emp,ass,aud}')) x""")
chks = q("""SELECT json_agg(x) FROM (SELECT n.nspname esq, c.relname tab, k.conname nome, pg_get_constraintdef(k.oid) def, k.contype tipo
  FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE k.contype IN ('c','u','x') AND n.nspname = ANY ('{ref,cid,edu,emp,ass,aud}') ORDER BY 1,2,3) x""")
trgs = q("""SELECT json_agg(x) FROM (SELECT n.nspname esq, c.relname tab, t.tgname nome, p.proname funcao
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_proc p ON p.oid = t.tgfoid
  WHERE NOT t.tgisinternal AND n.nspname = ANY ('{ref,cid,edu,emp,ass,aud}') ORDER BY 1,2,3) x""")

COLS = defaultdict(list)
for c in cols: COLS[(c["esq"], c["tab"])].append(c)
ent = lambda e, t: f"{e}_{t}"


def tipo_mmd(t):
    t = t.replace("character varying", "varchar").replace("character", "char").replace("timestamp with time zone", "timestamptz")
    return t.split("(")[0].replace(" ", "_").replace(".", "_")


def diagrama(nome, titulo, esquemas, detalhe=True):
    linhas = ["---", f"title: \"{titulo}\"", "---", "erDiagram"]
    usadas = {(e, t) for (e, t) in COLS if e in esquemas}
    externas = set()
    for f in fks:
        if f["esq"] in esquemas and (f["resq"], f["rtab"]) not in usadas: externas.add((f["resq"], f["rtab"]))
    for (e, t) in sorted(usadas | externas):
        if detalhe and (e, t) in usadas:
            linhas.append(f"  {ent(e, t)} {{")
            for c in COLS[(e, t)]:
                k = ",".join(x for x, ok in (("PK", c["pk"]), ("FK", c["fk"]), ("UK", c["uk"])) if ok)
                linhas.append(f"    {tipo_mmd(c['tipo'])} {c['col']}{' ' + k if k else ''}")
            linhas.append("  }")
        else:
            linhas.append(f'  {ent(e, t)} {{\n    _ externo\n  }}' if (e, t) in externas else f"  {ent(e, t)} {{\n    _ _\n  }}")
    for f in fks:
        if f["esq"] not in esquemas: continue
        lado_filho = "|o" if f["unico"] else "}o"
        lado_pai = "||" if f["obrig"] else "o|"
        linhas.append(f'  {ent(f["resq"], f["rtab"])} {lado_pai}--{lado_filho} {ent(f["esq"], f["tab"])} : "{",".join(f["cols"])}"')
    (DIAG / f"{nome}.mmd").write_text("\n".join(linhas) + "\n", encoding="utf-8")
    return nome


nomes = [diagrama("er_00_visao_geral", "SmartCity Connect: visão geral (entidades e cardinalidades)", ["cid", "edu", "emp", "ass"], detalhe=False),
         diagrama("er_01_cid", "Módulo CID: Cadastro de Cidadãos", ["cid"]),
         diagrama("er_02_edu", "Módulo EDU: Gestão da Educação", ["edu"]),
         diagrama("er_03_emp", "Módulo EMP: Emprego e Desenvolvimento Econômico", ["emp"]),
         diagrama("er_04_ass", "Módulo ASS: Assistência Social", ["ass"]),
         diagrama("er_05_ref", "Referência pública (IBGE, CNAE, CBO)", ["ref"])]
mmdc = shutil.which("mmdc")
if mmdc:
    cfg = DIAG / ".puppeteer.json"; cfg.write_text('{"args":["--no-sandbox"]}')
    for n in nomes:
        for ext in ("svg", "png"):
            subprocess.run([mmdc, "-q", "-p", str(cfg), "-i", str(DIAG / f"{n}.mmd"), "-o", str(DIAG / f"{n}.{ext}"), "-b", "white", "-w", "2400"], check=True)
    cfg.unlink()
    print(f"  {len(nomes)} diagramas ER em docs/diagramas/ (.mmd, .svg e .png)")

# ---------------------------------------------------------------- dicionario
NOME_ESQ = {"ref": "Referência pública", "cid": "CID · Cadastro de Cidadãos", "edu": "EDU · Gestão da Educação",
            "emp": "EMP · Emprego e Desenvolvimento Econômico", "ass": "ASS · Assistência Social", "aud": "AUD · Auditoria"}
TAB = {(t["esq"], t["tab"]): t for t in tabs}
REST = defaultdict(list)
for k in chks: REST[(k["esq"], k["tab"])].append(k)
GAT = defaultdict(list)
for t in trgs: GAT[(t["esq"], t["tab"])].append(t)
FKT = defaultdict(list)
for f in fks: FKT[(f["esq"], f["tab"])].append(f)
md = ["# Dicionário de dados", "", "Gerado do catálogo do PostgreSQL por `scripts/03_gerar_documentacao.py`. "
      "Legenda: **PK** chave primária, **FK** chave estrangeira, **UK** única, **NN** obrigatória.", ""]
for e in ESQUEMAS:
    md += [f"## {NOME_ESQ[e]} (`{e}`)", ""]
    for (es, t) in sorted(k for k in COLS if k[0] == e):
        info = TAB[(es, t)]
        md += [f"### `{es}.{t}`", "", (info["com"] or "").strip(), "", f"Linhas: {max(0, info['linhas']):,}".replace(",", "."), "",
               "| Coluna | Tipo | Chave | NN | Padrão | Descrição |", "|---|---|---|---|---|---|"]
        for c in COLS[(es, t)]:
            k = " ".join(x for x, ok in (("PK", c["pk"]), ("FK", c["fk"]), ("UK", c["uk"])) if ok)
            md.append(f"| `{c['col']}` | {c['tipo']} | {k} | {'sim' if c['nn'] else ''} | {('`' + c['padrao'][:40] + '`') if c['padrao'] else ''} | {(c['com'] or '').replace('|', '/')} |")
        if FKT[(es, t)]:
            md += ["", "Chaves estrangeiras: " + "; ".join(f"`{','.join(f['cols'])}` → `{f['resq']}.{f['rtab']}`" for f in FKT[(es, t)])]
        if REST[(es, t)]:
            md += ["", "Restrições:"] + [f"- `{k['nome']}`: `{k['def'][:160]}`" for k in REST[(es, t)]]
        if GAT[(es, t)]:
            md += ["", "Gatilhos: " + ", ".join(f"`{g['nome']}` ({g['funcao']})" for g in GAT[(es, t)])]
        md.append("")
(RAIZ / "docs" / "03_dicionario_de_dados.md").write_text("\n".join(md), encoding="utf-8")
print(f"  dicionario de dados: {sum(1 for k in COLS)} tabelas, {len(cols)} colunas, {len(fks)} FKs")
