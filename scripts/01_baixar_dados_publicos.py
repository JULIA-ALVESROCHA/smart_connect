#!/usr/bin/env python3
"""
SmartCity Connect - Aquisicao e normalizacao de dados publicos brasileiros.

Baixa os arquivos brutos para dados/brutos/ e gera CSVs limpos em dados/referencia/,
prontos para o \\copy do PostgreSQL.

Fontes (detalhes em dados/FONTES.md):
  1. IBGE Localidades (UF e municipios)   API oficial, com espelho em CSV
  2. IBGE CNAE 2.3 (secao a classe)       API oficial, com espelho em CSV
  3. MTE CBO 2002 (ocupacoes)             arquivo oficial "CBO2002 - Ocupacao.csv" (espelho)
  4. IBGE Censo 2010, Nomes no Brasil     frequencia de prenomes por decada de nascimento (espelho)

Uso:
  python3 scripts/01_baixar_dados_publicos.py            # usa dados/brutos se ja existir
  python3 scripts/01_baixar_dados_publicos.py --atualizar # baixa tudo de novo

Somente biblioteca padrao. Nenhuma API paga, nenhuma chave.
"""
import csv, json, sys, unicodedata, urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BRUTOS = RAIZ / "dados" / "brutos"
REF = RAIZ / "dados" / "referencia"
GH = "https://raw.githubusercontent.com"
IBGE = "https://servicodados.ibge.gov.br/api"

# arquivo local -> lista de URLs tentadas em ordem
FONTES_OFICIAIS = {
    "ibge_estados.json": [f"{IBGE}/v1/localidades/estados"],
    "ibge_municipios.json": [f"{IBGE}/v1/localidades/municipios"],
    "ibge_cnae_classes.json": [f"{IBGE}/v2/cnae/classes"],
}
FONTES_ESPELHO = {
    "estados.csv": [f"{GH}/kelvins/municipios-brasileiros/main/csv/estados.csv"],
    "municipios.csv": [f"{GH}/kelvins/municipios-brasileiros/main/csv/municipios.csv"],
    "cnae_secoes.csv": [f"{GH}/pedrounes1/CNAES-IBGE-2_3/main/csv/secoes.csv"],
    "cnae_divisoes.csv": [f"{GH}/pedrounes1/CNAES-IBGE-2_3/main/csv/divisoes.csv"],
    "cnae_grupos.csv": [f"{GH}/pedrounes1/CNAES-IBGE-2_3/main/csv/grupos.csv"],
    "cnae_classes.csv": [f"{GH}/pedrounes1/CNAES-IBGE-2_3/main/csv/classes.csv"],
    "cbo2002_ocupacao.csv": [f"{GH}/cartaproale/cbo-csv/main/CBO2002%20-%20Ocupacao.csv"],
    "nomes-censos-ibge.csv": [f"{GH}/datasets-br/prenomes/master/data/nomes-censos-ibge.csv"],
    "wd_femininos.csv": [f"{GH}/datasets-br/prenomes/master/data/wd_femininos.csv"],
    "wd_masculinos-pt.csv": [f"{GH}/datasets-br/prenomes/master/data/wd_masculinos-pt.csv"],
}


def baixar(nome, urls, forcar):
    destino = BRUTOS / nome
    if destino.exists() and destino.stat().st_size > 0 and not forcar:
        return True
    for url in urls:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "smartcity-connect/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                dados = r.read()
            if len(dados) < 50:
                raise ValueError("resposta vazia")
            destino.write_bytes(dados)
            print(f"  ok      {nome:28s} {len(dados):>9,d} bytes  <- {url}")
            return True
        except Exception as e:  # rede bloqueada, 404 etc.
            print(f"  falhou  {nome:28s} {type(e).__name__}: {str(e)[:60]}")
    return destino.exists()


def ler_csv(nome, **kw):
    with open(BRUTOS / nome, newline="", encoding=kw.pop("encoding", "utf-8-sig")) as f:
        return list(csv.DictReader(f, **kw))


def gravar(nome, cabecalho, linhas):
    with open(REF / nome, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cabecalho)
        w.writerows(linhas)
    print(f"  {nome:22s} {len(linhas):>6,d} linhas")
    return len(linhas)


def sem_acento(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def titulo(s):
    """CNAE vem em caixa alta: normaliza para leitura em relatorios."""
    pequenas = {"de", "da", "do", "das", "dos", "e", "em", "a", "o", "para", "com", "por", "na", "no"}
    out = []
    for i, p in enumerate(s.lower().split()):
        out.append(p if (p in pequenas and i) else p[:1].upper() + p[1:])
    return " ".join(out)


# ---------------------------------------------------------------- localidades
def normalizar_localidades():
    # coordenadas e DDD so existem no espelho; a API oficial e a fonte preferida de nomes
    extra = {}
    if (BRUTOS / "municipios.csv").exists():
        for r in ler_csv("municipios.csv"):
            extra[int(r["codigo_ibge"])] = (r["latitude"], r["longitude"], r["ddd"])
    if (BRUTOS / "ibge_estados.json").exists() and (BRUTOS / "ibge_municipios.json").exists():
        origem = "API IBGE"
        ufs = [(e["id"], e["sigla"], e["nome"], e["regiao"]["nome"])
               for e in json.loads((BRUTOS / "ibge_estados.json").read_text("utf-8"))]
        muns = [(m["id"], m["nome"], int(str(m["id"])[:2]))
                for m in json.loads((BRUTOS / "ibge_municipios.json").read_text("utf-8"))]
    else:
        origem = "espelho CSV"
        ufs = [(int(e["codigo_uf"]), e["uf"], e["nome"], e["regiao"]) for e in ler_csv("estados.csv")]
        muns = [(int(m["codigo_ibge"]), m["nome"], int(m["codigo_uf"])) for m in ler_csv("municipios.csv")]
    print(f"  localidades: origem = {origem}")
    gravar("uf.csv", ["cod_uf", "sigla", "nome", "regiao"], sorted(ufs))
    gravar("municipio.csv", ["cod_ibge", "nome", "cod_uf", "latitude", "longitude", "ddd"],
           [(c, n, u, *extra.get(c, ("", "", ""))) for c, n, u in sorted(muns)])


# ----------------------------------------------------------------------- cnae
def normalizar_cnae():
    if (BRUTOS / "ibge_cnae_classes.json").exists():
        print("  cnae: origem = API IBGE")
        sec, div, gru, cla = {}, {}, {}, {}
        for c in json.loads((BRUTOS / "ibge_cnae_classes.json").read_text("utf-8")):
            g = c["grupo"]; d = g["divisao"]; s = d["secao"]
            sec[s["id"]] = s["descricao"]
            div[d["id"]] = (d["descricao"], s["id"])
            gru[g["id"]] = (g["descricao"], d["id"])
            cla[c["id"]] = (c["descricao"], g["id"])
        S = [(k, v) for k, v in sec.items()]
        D = [(k, *v) for k, v in div.items()]
        G = [(k, *v) for k, v in gru.items()]
        C = [(k, *v) for k, v in cla.items()]
    else:
        print("  cnae: origem = espelho CSV")
        S = [(r["id"], r["descricao"]) for r in ler_csv("cnae_secoes.csv")]
        D = [(r["id"], r["descricao"], r["secao_id"]) for r in ler_csv("cnae_divisoes.csv")]
        G = [(r["id"], r["descricao"], r["divisao_id"]) for r in ler_csv("cnae_grupos.csv")]
        C = [(r["id"], r["descricao"], r["grupo_id"]) for r in ler_csv("cnae_classes.csv")]
    gravar("cnae_secao.csv", ["cod_secao", "descricao"], sorted((a, titulo(b)) for a, b in S))
    gravar("cnae_divisao.csv", ["cod_divisao", "descricao", "cod_secao"], sorted((a, titulo(b), c) for a, b, c in D))
    gravar("cnae_grupo.csv", ["cod_grupo", "descricao", "cod_divisao"], sorted((a, titulo(b), c) for a, b, c in G))
    gravar("cnae_classe.csv", ["cod_classe", "descricao", "cod_grupo"], sorted((a, titulo(b), c) for a, b, c in C))


# ------------------------------------------------------------------------ cbo
def normalizar_cbo():
    linhas = ler_csv("cbo2002_ocupacao.csv", encoding="latin-1", delimiter=";")
    gravar("cbo_ocupacao.csv", ["cod_cbo", "titulo"],
           sorted((r["CODIGO"].strip().zfill(6), r["TITULO"].strip()) for r in linhas if r["CODIGO"].strip()))


# ---------------------------------------------------------------------- nomes
# O arquivo do IBGE nao traz o sexo. Classificacao: listas do Wikidata (mesmo repositorio)
# mais correcoes manuais abaixo para os nomes frequentes ambiguos ou ausentes.
SEXO_FIXO_M = set("""JEAN DENIS YURI ELI GEORGE VALMIR RUAN RUBENS VINICIOS WILIAN ALISSON APARECIDO CAUA
VALDECI JAIME VALDECIR VALDEMIR CLAUDINEI WESLEI KAUAN GEOVANE DARCI IVANILDO KAUA NATAN GEAN EDNALDO
WELITON CAIQUE WELINGTON EDIMILSON CAUAN SIDNEY ALEXSANDRO EDINALDO JONATA KAIQUE ADAILTON DIVINO
GENIVALDO VALDINEI LORIVAL DEIVID ERIVALDO JOELSON JAILTON GEOVANI HEITOR AMAURI""".split())
SEXO_FIXO_F = set("""MARIA SIMONE DANIELE MICHELE VALERIA ANDREA GABRIELE KAREN ELISA VITORIA RAIMUNDA
DAIANE MARLI TATIANE TAIS MARILENE ELISANGELA GEOVANA LUCIENE TAMIRES IVONE CINTIA JOICE ROSILENE NEUSA
NEUZA NEIDE MAIARA FRANCIELE JANETE CICERA GIOVANA CLEIDE RAIANE REGIANE KELLY TAINARA JOELMA MARINALVA
TERESINHA GERALDA CLEONICE IRACI ELIZANGELA LIDIANE DALVA LURDES LUCILENE IVONETE LUCIANE LUCIMAR NILZA
SUELEN ROSIMEIRE CLEUSA ELIENE DAIANA EDILENE ELISABETE ELIETE ODETE DEISE ISABELE ANDREZA JOSEANE
LOURDES YASMIM GISLAINE JAMILE CLAUDETE GESSICA GENI ARLETE VALDIRENE ELIZETE VALQUIRIA JANDIRA ESTEFANI
JURACI RUTE LUZINETE PRICILA ROSALINA LEIDIANE ROSEANE CAMILE FABIANE EDITE SIRLEI VIVIAN CLEUZA VALDETE
LUCIMARA GLAUCIA SALETE ROSIANE IVETE LUCINEIA GRAZIELE ELENICE ADRIANE IASMIN ROSILDA MARISTELA
LUCINEIDE SIRLENE SILMARA SILVANIA NILDA IVANI ANDRESA JEANE CREUZA LINDALVA ROSINEIDE JACIRA GABRIELI
DANIELI IASMIM JOYCE JOSILENE JUDITE MARINETE DIVINA MICHELI GRAZIELA IRANI GEANE VANUSA TAIANE IVANETE
KELI DAYANE ZENAIDE MEIRE DOMINGAS LAIANE MARINES VANDERLEIA BERNADETE IVANILDA""".split())
TOP_NOMES = 700


def normalizar_nomes():
    chave = lambda s: "".join(c for c in sem_acento(s.upper()) if c.isalpha())
    fem = {chave(r["itemLabel"]) for r in ler_csv("wd_femininos.csv")}
    mas = {chave(r["itemLabel"]) for r in ler_csv("wd_masculinos-pt.csv")}
    linhas = ler_csv("nomes-censos-ibge.csv")
    decadas = [c for c in linhas[0] if c != "Nome"]
    total = lambda r: sum(int(r[c] or 0) for c in decadas)
    linhas.sort(key=total, reverse=True)
    saida, descartados = [], 0
    for r in linhas[:TOP_NOMES]:
        n = r["Nome"].strip().upper()
        if n in SEXO_FIXO_M: sexo = "M"
        elif n in SEXO_FIXO_F: sexo = "F"
        elif n in fem and n not in mas: sexo = "F"
        elif n in mas and n not in fem: sexo = "M"
        else:
            descartados += 1
            continue
        saida.append((n.capitalize(), sexo, *[int(r[c] or 0) for c in decadas]))
    gravar("nomes_ibge.csv", ["nome", "sexo", *[d.replace("ate", "nasc_ate_") for d in decadas]], saida)
    cobertura = sum(sum(l[2:]) for l in saida) / sum(total(r) for r in linhas)
    print(f"  nomes: {descartados} sem sexo definido descartados; cobertura = {cobertura:.1%} das ocorrencias do Censo")


def main():
    forcar = "--atualizar" in sys.argv
    BRUTOS.mkdir(parents=True, exist_ok=True)
    REF.mkdir(parents=True, exist_ok=True)
    print("1) Download (fonte oficial primeiro, espelho em seguida)")
    for nome, urls in FONTES_OFICIAIS.items():
        baixar(nome, urls, forcar)
    faltando = [n for n, u in FONTES_ESPELHO.items() if not baixar(n, u, forcar)]
    if faltando:
        sys.exit(f"ERRO: arquivos obrigatorios ausentes: {faltando}")
    print("2) Normalizacao para dados/referencia/")
    normalizar_localidades()
    normalizar_cnae()
    normalizar_cbo()
    normalizar_nomes()
    print("Concluido.")


if __name__ == "__main__":
    main()
