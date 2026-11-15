#!/usr/bin/env python3
"""
SmartCity Connect - Gerador de dados sinteticos de Nova Esperanca Digital.

Dados individuais reais (pessoas, CPFs, familias de baixa renda, alunos) sao sigilosos
e nao existem em base aberta. Este script gera registros ficticios, mas coerentes entre
si e com as regras de negocio, usando dados publicos como base:
  - prenomes e sua frequencia por decada de nascimento: IBGE, Censo 2010
  - naturalidade: municipios do IBGE
  - setor das empresas: classes da CNAE 2.3
  - ocupacao das vagas: titulos e codigos da CBO 2002
  - criterios de programas sociais: legislacao federal vigente

Escala (slides do professor): 500 mil habitantes, 20 bairros, 15 mil empresas, 200 escolas.

Uso:
  python3 scripts/02_gerar_dados_sinteticos.py                  # escala completa
  python3 scripts/02_gerar_dados_sinteticos.py --habitantes 50000 --empresas 1500 --escolas 20

Somente biblioteca padrao. Mesma semente = mesmos dados.
"""
import argparse, csv, random, unicodedata
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("--habitantes", type=int, default=500_000)
ap.add_argument("--empresas", type=int, default=15_000)
ap.add_argument("--escolas", type=int, default=200)
ap.add_argument("--semente", type=int, default=20261114)
ap.add_argument("--data-ref", default=None, help="data de referencia AAAA-MM-DD (padrao: hoje)")
args = ap.parse_args()

RAIZ = Path(__file__).resolve().parent.parent
REF = RAIZ / "dados" / "referencia"
OUT = RAIZ / "dados" / "gerados"
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(args.semente)
HOJE = date.fromisoformat(args.data_ref) if args.data_ref else date.today()
ANO = HOJE.year
SM = 1621.00                     # salario minimo 2026 (Decreto 12.797/2025)
COD_MUNICIPIO = 3199901          # codigo ficticio de Nova Esperanca Digital (MG)
DDD = "35"


def ler(nome):
    with open(REF / nome, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def gravar(nome, cabecalho, linhas):
    with open(OUT / f"{nome}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cabecalho)
        w.writerows(linhas)
    print(f"  {nome:28s} {len(linhas):>9,d}")


def sem_acento(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")


def data_entre(a, b):
    if b <= a:
        return a
    return date.fromordinal(rng.randint(a.toordinal(), b.toordinal()))


def idade_em(nasc, ref):
    return ref.year - nasc.year - ((ref.month, ref.day) < (nasc.month, nasc.day))


def ts(d, h=None, m=None):
    return f"{d.isoformat()} {h if h is not None else rng.randint(8, 17):02d}:{m if m is not None else rng.randint(0, 59):02d}:00-03"


def cpf_dv(base9):
    d = [int(c) for c in base9]
    s1 = sum(x * (10 - i) for i, x in enumerate(d))
    d1 = (s1 * 10) % 11 % 10
    s2 = sum(x * (11 - i) for i, x in enumerate(d)) + d1 * 2
    d2 = (s2 * 10) % 11 % 10
    return f"{base9}{d1}{d2}"


def cnpj_dv(base12):
    d = [int(c) for c in base12]
    w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    r = 11 - sum(a * b for a, b in zip(d, w1)) % 11
    d1 = 0 if r >= 10 else r
    w2 = [6] + w1
    r = 11 - sum(a * b for a, b in zip(d + [d1], w2)) % 11
    d2 = 0 if r >= 10 else r
    return f"{base12}{d1}{d2}"


def numeros_unicos(n, digitos, proibidos=()):
    usados, saida = set(proibidos), []
    lo, hi = 10 ** (digitos - 1), 10 ** digitos - 1
    while len(saida) < n:
        x = rng.randint(lo, hi)
        if x not in usados:
            usados.add(x)
            saida.append(str(x))
    return saida


# =============================================================== nomes (IBGE)
ACENTOS = {"Jose": "José", "Joao": "João", "Antonio": "Antônio", "Sebastiao": "Sebastião", "Lucia": "Lúcia",
           "Marcia": "Márcia", "Luis": "Luís", "Vitoria": "Vitória", "Julia": "Júlia", "Leticia": "Letícia",
           "Patricia": "Patrícia", "Fabio": "Fábio", "Sergio": "Sérgio", "Mario": "Mário", "Claudio": "Cláudio",
           "Marcio": "Márcio", "Flavio": "Flávio", "Julio": "Júlio", "Cesar": "César", "Andre": "André",
           "Vinicius": "Vinícius", "Antonia": "Antônia", "Claudia": "Cláudia", "Sonia": "Sônia", "Vania": "Vânia",
           "Tania": "Tânia", "Cecilia": "Cecília", "Livia": "Lívia", "Lais": "Laís", "Debora": "Débora",
           "Barbara": "Bárbara", "Monica": "Mônica", "Veronica": "Verônica", "Angela": "Ângela", "Rogerio": "Rogério",
           "Otavio": "Otávio", "Caua": "Cauã", "Kaua": "Kauã", "Conceicao": "Conceição", "Helio": "Hélio",
           "Celia": "Célia", "Valeria": "Valéria", "Natalia": "Natália", "Inacio": "Inácio", "Moises": "Moisés",
           "Jessica": "Jéssica", "Tais": "Taís", "Thais": "Thaís", "Cicero": "Cícero", "Cicera": "Cícera",
           "Erica": "Érica", "Heloisa": "Heloísa", "Damiao": "Damião", "Adao": "Adão", "Simao": "Simão",
           "Aurelio": "Aurélio", "Mauricio": "Maurício", "Fabricio": "Fabrício", "Fabiola": "Fabíola",
           "Glaucia": "Gláucia", "Cintia": "Cíntia", "Silvia": "Sílvia", "Flavia": "Flávia", "Vinicios": "Vinícios",
           "Ines": "Inês", "Tomas": "Tomás", "Nicolas": "Nícolas", "Agata": "Ágata", "Zelia": "Zélia"}
NOMES = {"F": [[], []], "M": [[], []]}   # sexo -> [nomes, pesos acumulados por decada]
for sexo in "FM":
    linhas = [r for r in ler("nomes_ibge.csv") if r["sexo"] == sexo]
    cols = [c for c in linhas[0] if c.startswith("nasc_ate_")]
    NOMES[sexo][0] = [ACENTOS.get(r["nome"], r["nome"]) for r in linhas]
    for c in cols:
        acum, t = [], 0
        for r in linhas:
            t += int(r[c]) + 1
            acum.append(t)
        NOMES[sexo][1].append(acum)

SOBRENOMES_P = """Silva 10;Santos 7;Oliveira 5.5;Souza 5;Rodrigues 3.5;Ferreira 3.3;Alves 3.2;Pereira 3.1;Lima 2.8;Gomes 2.5;
Costa 2.4;Ribeiro 2.3;Martins 2.2;Carvalho 2.1;Almeida 2;Lopes 1.8;Soares 1.7;Fernandes 1.7;Vieira 1.6;Barbosa 1.6;
Gonçalves 1.6;Rocha 1.5;Araújo 1.5;Dias 1.4;Nascimento 1.4;Andrade 1.3;Moreira 1.3;Nunes 1.2;Marques 1.2;Machado 1.2;
Mendes 1.1;Freitas 1.1;Cardoso 1;Ramos 1;Santana 1;Teixeira 1;Melo 1;Castro .9;Campos .9;Batista .9;Reis .9;Moraes .8;
Pinto .8;Miranda .8;Barros .8;Borges .7;Monteiro .7;Correia .7;Nogueira .7;Cunha .7;Azevedo .6;Tavares .6;Duarte .6;
Farias .6;Cavalcanti .5;Medeiros .5;Macedo .5;Fonseca .5;Guimarães .5;Coelho .5;Brito .5;Leite .5;Bezerra .5;Garcia .5;
Sales .4;Rezende .4;Assis .4;Paiva .4;Xavier .4;Siqueira .4;Pires .4;Vasconcelos .4;Figueiredo .4;Magalhães .4;
Amaral .4;Matos .4;Neves .4;Faria .4;Peixoto .3;Franco .3;Toledo .3;Prado .3;Lacerda .3;Dantas .3;Sampaio .3;
Vargas .3;Aguiar .3;Queiroz .3;Bueno .3;Camargo .3;Pacheco .3;Viana .3;Antunes .3;Braga .3;Diniz .3"""
_s = [x.strip().rsplit(" ", 1) for x in SOBRENOMES_P.replace("\n", "").split(";")]
SOBRENOMES = [a for a, _ in _s]
SOBRE_ACUM, _t = [], 0
for _, p in _s:
    _t += float(p)
    SOBRE_ACUM.append(_t)


def prenome(sexo, ano_nasc):
    dec = min(8, max(0, (ano_nasc - 1920) // 10))
    return rng.choices(NOMES[sexo][0], cum_weights=NOMES[sexo][1][dec])[0]


def sobrenome():
    return rng.choices(SOBRENOMES, cum_weights=SOBRE_ACUM)[0]


# ================================================================ territorio
print("Gerando dados sinteticos | referencia", HOJE, "| semente", args.semente)
REGIOES = [(1, "Centro"), (2, "Norte"), (3, "Sul"), (4, "Leste"), (5, "Oeste")]
# (nome, regiao, peso populacional, fator de renda)
BAIRROS = [("Centro", 1, 5.0, 1.55), ("Jardim das Acácias", 1, 4.0, 1.90), ("Bela Vista", 1, 4.5, 1.60),
           ("Cidade Nova", 1, 5.5, 1.25), ("Parque Tecnológico", 2, 3.0, 2.00), ("Alto da Serra", 2, 4.5, 1.30),
           ("Nova Aurora", 2, 6.0, 0.85), ("Vila Esperança", 2, 6.5, 0.62), ("Jardim Primavera", 3, 5.5, 1.00),
           ("Santa Clara", 3, 5.0, 1.10), ("Vila Operária", 3, 6.0, 0.72), ("Lagoa Dourada", 3, 3.5, 1.45),
           ("São Judas", 4, 5.5, 0.80), ("Morada do Sol", 4, 5.0, 0.95), ("Vila União", 4, 6.5, 0.60),
           ("Residencial Horizonte", 4, 4.5, 1.15), ("Jardim América", 5, 5.0, 1.05), ("Boa Esperança", 5, 6.0, 0.68),
           ("Parque das Águas", 5, 4.0, 1.35), ("Distrito Industrial", 5, 4.5, 0.78)]
NB = len(BAIRROS)
FATOR = [b[3] for b in BAIRROS]
gravar("cid_regiao", ["id_regiao", "nome"], REGIOES)
gravar("cid_bairro", ["id_bairro", "nome", "id_regiao"], [(i + 1, b[0], b[1]) for i, b in enumerate(BAIRROS)])

TEMAS = ["das Flores", "dos Ipês", "das Palmeiras", "do Comércio", "da Independência", "Sete de Setembro",
         "Quinze de Novembro", "da República", "das Acácias", "dos Jacarandás", "do Rosário", "da Matriz",
         "das Orquídeas", "dos Bandeirantes", "Tiradentes", "Minas Gerais", "da Liberdade", "da Paz",
         "das Laranjeiras", "do Café", "dos Girassóis", "Santos Dumont", "da Esperança", "Primeiro de Maio"]
logradouros, logr_por_bairro, usados_log = [], defaultdict(list), set()
total_log = max(200, round(args.habitantes / 110))
pesos_b = [b[2] for b in BAIRROS]
for b in range(NB):
    alvo = max(8, round(total_log * pesos_b[b] / sum(pesos_b)))
    while len(logr_por_bairro[b]) < alvo:
        tipo = rng.choices(["Rua", "Avenida", "Travessa", "Alameda", "Praça"], weights=[74, 12, 7, 5, 2])[0]
        r = rng.random()
        if r < 0.10:
            nome = rng.choice(TEMAS)
        else:
            sx = rng.choice("FM")
            tit = rng.choices(["", "Professor ", "Doutor ", "Vereador ", "Padre ", "Coronel "],
                              weights=[70, 8, 8, 6, 4, 4])[0] if sx == "M" else \
                rng.choices(["", "Professora ", "Doutora ", "Dona ", "Irmã "], weights=[70, 12, 6, 8, 4])[0]
            nome = f"{tit}{prenome(sx, rng.randint(1900, 1960))} {sobrenome()}"
            if rng.random() < 0.5:
                nome += " " + sobrenome()
        if (tipo, nome) in usados_log:
            continue
        usados_log.add((tipo, nome))
        idl = len(logradouros) + 1
        logradouros.append((idl, f"3799{idl:04d}", tipo, nome, b + 1))
        logr_por_bairro[b].append(idl)
gravar("cid_logradouro", ["id_logradouro", "cep", "tipo", "nome", "id_bairro"], logradouros)
LOGR_BAIRRO = {l[0]: l[4] - 1 for l in logradouros}


def numero_porta():
    return str(rng.randint(1, 2500))


# ================================================================== cidadaos
municipios = ler("municipio.csv")
MUN_MG = [int(m["cod_ibge"]) for m in municipios if m["cod_uf"] == "31"]
MUN_TODOS = [int(m["cod_ibge"]) for m in municipios]

P_nome, P_nasc, P_sexo, P_mae, P_mun, P_renda, P_hh, P_papel = [], [], [], [], [], [], [], []
H_bairro, H_logr, H_num, H_compl, H_membros = [], [], [], [], []


def naturalidade(crianca):
    r = rng.random()
    if r < (0.86 if crianca else 0.52):
        return COD_MUNICIPIO
    if r < (0.95 if crianca else 0.82):
        return rng.choice(MUN_MG)
    return rng.choice(MUN_TODOS)


def renda_adulto(idade, f):
    r = rng.random()
    if idade >= 65:
        if r < 0.62: return SM
        if r < 0.80: return round(SM * (1 + rng.expovariate(1.2)) * f ** 0.7, 2)
        return 0.0
    p0 = min(0.50, max(0.08, 0.24 - 0.13 * (f - 1))) + (0.20 if idade < 25 else 0)
    if r < p0: return 0.0
    if r < p0 + min(0.32, 0.17 / f): return float(rng.randrange(300, 1500, 50))
    return round(SM * max(1.0, rng.lognormvariate(0.22, 0.62)) * f ** 0.85, 2)


def nasc_com_idade(lo, hi):
    return date.fromordinal(HOJE.toordinal() - rng.randint(lo * 365 + 60, hi * 365 + 300))


def nova_pessoa(hh, sexo, nasc, sobren, papel, mae=None, renda=None):
    idade = idade_em(nasc, HOJE)
    nome = f"{prenome(sexo, nasc.year)} {' '.join(sobren)}"
    if rng.random() < 0.18:   # nome composto
        nome = f"{prenome(sexo, nasc.year)} {nome}"
    if mae is None:
        mae = f"{prenome('F', nasc.year - 26)} {sobren[0]}" + (f" {sobrenome()}" if rng.random() < 0.6 else "")
    P_nome.append(nome); P_nasc.append(nasc); P_sexo.append(sexo); P_mae.append(mae)
    P_mun.append(naturalidade(idade < 18)); P_hh.append(hh); P_papel.append(papel)
    P_renda.append(renda if renda is not None else (renda_adulto(idade, FATOR[H_bairro[hh]]) if idade >= 18 else
                                                     (float(rng.randrange(300, 900, 50)) if idade >= 16 and rng.random() < 0.12 else 0.0)))
    H_membros[hh].append(len(P_nome) - 1)
    return len(P_nome) - 1


while len(P_nome) < args.habitantes:
    hh = len(H_bairro)
    b = rng.choices(range(NB), weights=pesos_b)[0]
    H_bairro.append(b); H_logr.append(rng.choice(logr_por_bairro[b])); H_num.append(numero_porta())
    H_compl.append(rng.choice(["Apto 101", "Apto 202", "Apto 303", "Casa 2", "Fundos", "Bloco B Apto 12"]) if rng.random() < 0.17 else "")
    H_membros.append([])
    tipo = rng.choices("ABCDE", weights=[21, 25, 31, 12, 11])[0]
    s1, s2 = sobrenome(), sobrenome()
    if tipo == "A":      # pessoa sozinha
        idoso = rng.random() < 0.37
        sx = rng.choice("FM") if not idoso else rng.choices("FM", weights=[62, 38])[0]
        nova_pessoa(hh, sx, nasc_com_idade(62, 92) if idoso else nasc_com_idade(20, 61), [s1, s2], "ref")
        continue
    if tipo == "B":      # casal sem filhos em casa
        idoso = rng.random() < 0.40
        n1 = nasc_com_idade(60, 88) if idoso else nasc_com_idade(21, 59)
        nova_pessoa(hh, "F", n1, [sobrenome(), s1], "ref")
        nova_pessoa(hh, "M", date.fromordinal(n1.toordinal() - rng.randint(-1500, 2200)), [s2, s1], "ref")
        continue
    # familias com filhos (C casal, D monoparental, E estendida)
    n_mae = nasc_com_idade(22, 58)
    id_mae = id_pai = None
    if tipo != "D" or rng.random() < 0.88:
        id_mae = nova_pessoa(hh, "F", n_mae, [sobrenome(), s1], "ref")
    if tipo in "CE" and (tipo == "C" or rng.random() < 0.6) or id_mae is None:
        id_pai = nova_pessoa(hh, "M", date.fromordinal(n_mae.toordinal() - rng.randint(-1200, 2500)), [s2, s1], "ref")
    nome_mae = P_nome[id_mae] if id_mae is not None else None
    sob_filho = [P_nome[id_mae].split()[-1] if id_mae is not None else sobrenome(), s1]
    idade_mae = idade_em(n_mae, HOJE)
    for _ in range(rng.choices([1, 2, 3, 4], weights=[50, 35, 11, 4])[0]):
        id_max = min(27, idade_mae - 18)
        if id_max < 0: break
        idf = rng.randint(max(0, idade_mae - 44), id_max)
        nasc = date.fromordinal(HOJE.toordinal() - idf * 365 - rng.randint(1, 364))
        nova_pessoa(hh, rng.choice("FM"), nasc, sob_filho, "filho", mae=nome_mae)
    if tipo == "E":
        for _ in range(rng.choices([1, 2], weights=[65, 35])[0]):
            nova_pessoa(hh, rng.choices("FM", weights=[62, 38])[0],
                        date.fromordinal(n_mae.toordinal() - rng.randint(20 * 365, 34 * 365)), [sobrenome(), s1], "avo")

NP, NH = len(P_nome), len(H_bairro)
P_idade = [idade_em(n, HOJE) for n in P_nasc]
H_pc = [sum(P_renda[p] for p in H_membros[h]) / len(H_membros[h]) for h in range(NH)]
cpfs = [cpf_dv(x) for x in numeros_unicos(NP, 9)]
INICIO_BASE = date(2012, 1, 2)
cidadaos = []
for i in range(NP):
    cad = data_entre(max(INICIO_BASE, P_nasc[i]), HOJE)
    atu = data_entre(cad, HOJE) if rng.random() < 0.45 else cad
    email = ""
    if P_idade[i] >= 16 and rng.random() < 0.38:
        pt = sem_acento(P_nome[i]).lower().split()
        email = f"{pt[0]}.{pt[-1]}{rng.randint(1, 9999)}@example.com"
    sit = "ATIVO"
    cidadaos.append((i + 1, cpfs[i], P_nome[i], P_nasc[i], P_sexo[i], P_mae[i], P_mun[i], email, sit, ts(cad), ts(atu, 18)))
gravar("cid_cidadao", ["id_cidadao", "cpf", "nome", "data_nascimento", "sexo", "nome_mae", "cod_municipio_nascimento",
                       "email", "situacao", "data_cadastro", "data_atualizacao"], cidadaos)
del cidadaos

telefones = []
for h in range(NH):
    fixo = f"3{rng.randint(1000000, 9999999)}" if rng.random() < 0.13 else None
    for k, p in enumerate(H_membros[h]):
        if P_idade[p] < 12 or (P_idade[p] < 18 and rng.random() < 0.45) or rng.random() < 0.07:
            continue
        telefones.append((p + 1, DDD, f"9{rng.randint(10000000, 99999999)}", "CELULAR", "t"))
        if fixo and P_papel[p] != "filho":
            telefones.append((p + 1, DDD, fixo, "FIXO", "f"))
        elif rng.random() < 0.06:
            telefones.append((p + 1, DDD, f"9{rng.randint(10000000, 99999999)}", "RECADO", "f"))
gravar("cid_telefone", ["id_cidadao", "ddd", "numero", "tipo", "principal"], telefones)
del telefones

enderecos = []
for h in range(NH):
    inicio_atual = data_entre(date(2000, 1, 1), HOJE - timedelta(days=20))
    trechos = [(H_logr[h], H_num[h], H_compl[h], inicio_atual, None)]
    r = rng.random()
    for _ in range(2 if r < 0.07 else 1 if r < 0.27 else 0):
        fim = trechos[0][3]
        ini = fim - timedelta(days=rng.randint(200, 3200))
        trechos.insert(0, (rng.choice(logradouros)[0], numero_porta(), "", ini, fim))
    for p in H_membros[h]:
        primeiro = True
        for (lg, nu, co, ini, fim) in trechos:
            if fim is not None and P_nasc[p] >= fim:
                continue
            # o primeiro endereco conhecido de quem ja existia comeca no nascimento ou no inicio do trecho
            enderecos.append((p + 1, lg, nu, co, max(ini, P_nasc[p]), fim or ""))
            primeiro = False
gravar("cid_endereco_cidadao", ["id_cidadao", "id_logradouro", "numero", "complemento", "data_inicio", "data_fim"], enderecos)
del enderecos

# ================================================================== educacao
AREAS_CON = [(1, "Linguagens"), (2, "Matemática"), (3, "Ciências da Natureza"), (4, "Ciências Humanas"), (5, "Ensino Religioso")]
# (id, sigla, nome, area, anos, carga anos iniciais, carga anos finais)
COMPONENTES = [(1, "LPO", "Língua Portuguesa", 1, range(1, 10), 240, 200), (2, "MAT", "Matemática", 2, range(1, 10), 200, 200),
               (3, "CIE", "Ciências", 3, range(1, 10), 80, 120), (4, "HIS", "História", 4, range(1, 10), 80, 80),
               (5, "GEO", "Geografia", 4, range(1, 10), 80, 80), (6, "ART", "Arte", 1, range(1, 10), 40, 80),
               (7, "EDF", "Educação Física", 1, range(1, 10), 80, 80), (8, "ERE", "Ensino Religioso", 5, range(1, 10), 40, 40),
               (9, "ING", "Língua Inglesa", 1, range(6, 10), 0, 80)]
gravar("edu_area_conhecimento", ["id_area", "nome"], AREAS_CON)
gravar("edu_componente_curricular", ["id_componente", "sigla", "nome", "id_area"], [c[:4] for c in COMPONENTES])
disciplinas, DISC = [], {}        # DISC[(sigla, ano)] = id
for ano_e in range(1, 10):
    for c in COMPONENTES:
        if ano_e in c[4]:
            idd = len(disciplinas) + 1
            disciplinas.append((idd, f"EF{ano_e:02d}-{c[1]}", f"{c[2]} - {ano_e}º ano", c[0], ano_e, c[5] if ano_e <= 5 else c[6]))
            DISC[(c[1], ano_e)] = idd
gravar("edu_disciplina", ["id_disciplina", "codigo", "nome", "id_componente", "ano_escolar", "carga_horaria"], disciplinas)
DISC_ANO = defaultdict(list)
for (sg, a), idd in DISC.items():
    DISC_ANO[a].append(idd)
PERIODOS = [(1, ANO - 2, "ENCERRADO"), (2, ANO - 1, "ENCERRADO"), (3, ANO, "ABERTO")]
gravar("edu_periodo_letivo", ["id_periodo", "ano", "data_inicio", "data_fim", "situacao"],
       [(i, a, date(a, 2, 3), date(a, 12, 18), s) for i, a, s in PERIODOS])

# criancas por bairro definem onde ficam as escolas
CORTE = date(ANO, 3, 31)
criancas_b = [0] * NB
for p in range(NP):
    if 6 <= idade_em(P_nasc[p], CORTE) <= 15:
        criancas_b[H_bairro[P_hh[p]]] += 1
n_esc_b = [max(1, round(args.escolas * c / max(1, sum(criancas_b)))) for c in criancas_b]
while sum(n_esc_b) > args.escolas: n_esc_b[n_esc_b.index(max(n_esc_b))] -= 1
while sum(n_esc_b) < args.escolas: n_esc_b[n_esc_b.index(min(n_esc_b))] += 1
escolas, ESC_BAIRRO, nomes_esc = [], defaultdict(list), set()
inep = numeros_unicos(args.escolas, 6)
for b in range(NB):
    for k in range(n_esc_b[b]):
        ai, af = (1, 9) if k == 0 else rng.choices([(1, 5), (6, 9), (1, 9)], weights=[48, 27, 25])[0]
        while True:
            sx = rng.choice("FM")
            tit = rng.choice(["Professor", "Doutor", "Padre", "Vereador", "Prefeito"] if sx == "M" else ["Professora", "Dona", "Irmã", "Doutora"])
            nome = f"Escola Municipal {tit} {prenome(sx, rng.randint(1900, 1955))} {sobrenome()} {sobrenome()}"
            if nome not in nomes_esc:
                nomes_esc.add(nome); break
        ide = len(escolas) + 1
        escolas.append((ide, f"31{inep[ide - 1]}", nome, rng.choice(logr_por_bairro[b]), numero_porta(), ai, af,
                        f"{DDD}3{rng.randint(1000000, 9999999)}", "ATIVA"))
        ESC_BAIRRO[b].append(ide)
gravar("edu_escola", ["id_escola", "cod_inep", "nome", "id_logradouro", "numero", "ano_inicial", "ano_final", "telefone", "situacao"], escolas)
ESC_ANOS = {e[0]: (e[5], e[6]) for e in escolas}
REGIAO_B = [b[1] for b in BAIRROS]


def escolher_escola(b, ano_e):
    op = [e for e in ESC_BAIRRO[b] if ESC_ANOS[e][0] <= ano_e <= ESC_ANOS[e][1]]
    return rng.choice(op)   # a primeira escola de cada bairro oferta do 1o ao 9o ano


alunos, matriculas, ALUNO_ATIVO, alunos_escola = [], [], set(), defaultdict(int)
ras = numeros_unicos(NP // 6 + 10, 8)
for p in range(NP):
    ic = idade_em(P_nasc[p], CORTE)
    if not 6 <= ic <= 16:
        continue
    rep = rng.choices([0, 1, 2], weights=[88, 10, 2])[0]
    ano_e = ic - 5 - rep
    if not 1 <= ano_e <= 9:
        if rep and 1 <= ic - 5 <= 9: ano_e, rep = ic - 5, 0
        else: continue
    h = P_hh[p]
    baixa = H_pc[h] <= SM / 2
    if rng.random() > (0.965 if baixa else 0.74):
        continue                               # fora da rede municipal (rede estadual, privada ou fora da escola)
    r = rng.random()
    sit = "ATIVO" if r < (0.955 if baixa else 0.975) else ("EVADIDO" if r < (0.985 if baixa else 0.985) else "TRANSFERIDO")
    ide = escolher_escola(H_bairro[h], ano_e)
    ida = len(alunos) + 1
    rep25 = rep >= 1 and rng.random() < 0.45
    rep24 = (rep >= 2 or (rep >= 1 and not rep25)) and rng.random() < 0.45
    anos = {ANO: ano_e}
    anos[ANO - 1] = ano_e if rep25 else ano_e - 1
    anos[ANO - 2] = anos[ANO - 1] if rep24 else anos[ANO - 1] - 1
    ano_ingresso = ANO - (ano_e - 1) - rep if rng.random() < 0.88 else rng.randint(max(ANO - (ano_e - 1) - rep, ANO - 6), ANO)
    alunos.append((ida, p + 1, ide, f"RA{ras[ida - 1]}", ano_e, rng.choices(["MANHA", "TARDE", "INTEGRAL"], weights=[48, 40, 12])[0],
                   date(ano_ingresso, 2, rng.randint(1, 20)), sit))
    alunos_escola[ide] += 1
    if sit == "ATIVO": ALUNO_ATIVO.add(p)
    habilidade = min(9.6, max(5.2, rng.gauss(7.3, 1.1)))
    for idp, ano_l, _ in PERIODOS:
        ae = anos[ano_l]
        if ae < 1 or ano_l < ano_ingresso or not ESC_ANOS[ide][0] <= ae <= ESC_ANOS[ide][1]:
            continue
        repetiu = (ano_l == ANO - 1 and rep25) or (ano_l == ANO - 2 and rep24)
        dm = date(ano_l, 1, rng.randint(8, 30))
        for k, idd in enumerate(DISC_ANO[ae]):
            if ano_l == ANO:
                st = "CURSANDO" if sit == "ATIVO" else "CANCELADA"
                matriculas.append((ida, idd, idp, dm, st, "", round(min(100, max(55, rng.gauss(91, 6))), 2) if st == "CURSANDO" else ""))
            else:
                nota = rng.gauss(4.9, 1.2) if repetiu and (k < 2 or rng.random() < 0.5) else max(6.0, rng.gauss(habilidade, 1.0))
                nota = round(min(10, max(0, nota)), 1)
                matriculas.append((ida, idd, idp, dm, "APROVADO" if nota >= 6 else "REPROVADO", nota,
                                   round(min(100, max(50, rng.gauss(92 if nota >= 6 else 78, 5))), 2)))
gravar("edu_aluno", ["id_aluno", "id_cidadao", "id_escola", "ra", "ano_escolar", "turno", "data_ingresso", "situacao"], alunos)
gravar("edu_matricula", ["id_aluno", "id_disciplina", "id_periodo", "data_matricula", "situacao", "nota_final", "frequencia_pct"], matriculas)
ALUNO_CID = {a[1] - 1 for a in alunos}
n_alunos = len(alunos)
del matriculas

# professores: adultos com renda formal, fora de familias de baixa renda
cand_prof = [p for p in range(NP) if 25 <= P_idade[p] <= 63 and P_renda[p] >= 2 * SM]
rng.shuffle(cand_prof)
professores, atribuicoes, PROF_CID = [], set(), set()
regs = numeros_unicos(len(cand_prof) + 1, 8)
NOME_COMP = {c[1]: c[2] for c in COMPONENTES}


def novo_professor(formacao):
    p = cand_prof.pop()
    idp = len(professores) + 1
    PROF_CID.add(p)
    adm = data_entre(max(date(1990, 2, 1), date(P_nasc[p].year + 23, 2, 1)), date(ANO - 2, 1, 20))
    professores.append((idp, p + 1, regs[idp - 1], formacao,
                        rng.choices(["GRADUACAO", "ESPECIALIZACAO", "MESTRADO", "DOUTORADO"], weights=[38, 47, 12, 3])[0], adm, "ATIVO"))
    return idp


for e in escolas:
    ide, (ai, af) = e[0], (e[5], e[6])
    turmas = max(1, min(4, round(alunos_escola[ide] / ((af - ai + 1) * 28))))
    postos = []   # (formacao, [disciplinas])
    for a in range(ai, min(af, 5) + 1):
        for _ in range(turmas):
            postos.append(("Licenciatura em Pedagogia", [DISC[(s, a)] for s in ("LPO", "MAT", "CIE", "HIS", "GEO")]))
    if ai <= 5:
        for s in ("ART", "EDF", "ERE"):
            for _ in range(2 if turmas >= 3 else 1):
                postos.append((f"Licenciatura em {NOME_COMP[s]}", [DISC[(s, a)] for a in range(ai, min(af, 5) + 1)]))
    if af >= 6:
        for c in COMPONENTES:
            for _ in range(2 if turmas >= 3 else 1):
                postos.append((f"Licenciatura em {c[2]}", [DISC[(c[1], a)] for a in range(max(ai, 6), af + 1)]))
    for formacao, discs in postos:
        atual = novo_professor(formacao)
        for idp, ano_l, _ in reversed(PERIODOS):
            for d in discs:
                atribuicoes.add((ide, d, idp, atual))
            if rng.random() < 0.14 and cand_prof:      # rotatividade: no ano anterior era outro docente
                atual = novo_professor(formacao)
gravar("edu_professor", ["id_professor", "id_cidadao", "registro_funcional", "formacao", "titulacao", "data_admissao", "situacao"], professores)
gravar("edu_atribuicao_docente", ["id_escola", "id_disciplina", "id_periodo", "id_professor"], sorted(atribuicoes))

# =================================================================== emprego
AREAS = ["Administração e Finanças", "Comércio e Vendas", "Tecnologia da Informação", "Saúde", "Educação",
         "Indústria e Produção", "Construção Civil", "Logística e Transporte", "Alimentação e Hospitalidade",
         "Serviços Gerais e Segurança", "Agropecuária", "Atendimento e Telemarketing"]
gravar("emp_area_profissional", ["id_area", "nome"], list(enumerate(AREAS, 1)))
# titulo CBO | escolaridade minima | salario em multiplos do minimo
OCUP = {1: "Assistente administrativo|5|1.5;Auxiliar de escritório|5|1.2;Auxiliar de contabilidade|5|1.5;Contador|7|4.2;Analista financeiro (instituições financeiras)|7|3.8;Administrador|7|4.0;Auxiliar de pessoal|5|1.4;Analista de recursos humanos|7|3.0;Recepcionista, em geral|5|1.2;Auxiliar de faturamento|5|1.4;Comprador|5|2.2",
        2: "Vendedor de comércio varejista|5|1.3;Operador de caixa|5|1.2;Repositor de mercadorias|3|1.1;Gerente de loja e supermercado|5|2.8;Atendente de lojas e mercados|3|1.1;Promotor de vendas|5|1.3;Representante comercial autônomo|5|2.2;Vendedor em comércio atacadista|5|1.6",
        3: "Analista de desenvolvimento de sistemas|7|4.8;Analista de suporte computacional|6|3.0;Técnico de suporte ao usuário de tecnologia da informação|5|1.8;Administrador de banco de dados|7|5.2;Analista de redes e de comunicação de dados|7|4.2;Técnico em manutenção de equipamentos de informática|5|1.6;Gerente de projetos de tecnologia da informação|7|7.0;Administrador de redes|7|4.4",
        4: "Técnico de enfermagem|5|1.9;Enfermeiro|7|3.4;Auxiliar de enfermagem|5|1.5;Farmacêutico|7|3.5;Atendente de farmácia - balconista|5|1.2;Fisioterapeuta geral|7|2.8;Auxiliar em saúde bucal|5|1.3;Recepcionista de consultório médico ou dentário|5|1.2;Cuidador de idosos|3|1.3;Nutricionista|7|2.6;Técnico em radiologia e imagenologia|5|2.2",
        5: "Professor de nível médio no ensino fundamental|5|1.8;Auxiliar de desenvolvimento infantil|5|1.2;Professor de nível superior do ensino fundamental (primeira a quarta série)|7|2.6;Instrutor de aprendizagem e treinamento comercial|5|2.0;Coordenador pedagógico|7|3.4;Inspetor de alunos de escola privada|5|1.2;Professor de língua inglesa|7|2.4",
        6: "Alimentador de linha de produção|3|1.2;Operador de máquinas fixas, em geral|3|1.5;Soldador|3|1.9;Mecânico de manutenção de máquinas, em geral|5|2.3;Eletricista de manutenção eletroeletrônica|5|2.2;Técnico em segurança do trabalho|5|2.4;Inspetor de qualidade|5|1.9;Supervisor de produção da indústria alimentícia|5|2.9;Montador de máquinas|3|1.7",
        7: "Pedreiro|2|1.6;Servente de obras|2|1.1;Eletricista de instalações|3|1.8;Pintor de obras|2|1.5;Carpinteiro|2|1.6;Mestre (construção civil)|3|2.8;Engenheiro civil|7|6.0;Encanador|2|1.6;Armador de estrutura de concreto|2|1.6;Técnico de obras civis|5|2.4",
        8: "Motorista de caminhão (rotas regionais e internacionais)|3|2.0;Motorista de carro de passeio|3|1.4;Almoxarife|5|1.4;Conferente de carga e descarga|3|1.3;Auxiliar de logística|5|1.3;Operador de empilhadeira|3|1.5;Ajudante de motorista|2|1.1;Estoquista|3|1.2;Motorista de ônibus urbano|3|1.9",
        9: "Cozinheiro geral|3|1.4;Garçom|3|1.2;Auxiliar nos serviços de alimentação|2|1.1;Atendente de lanchonete|3|1.1;Padeiro|3|1.5;Confeiteiro|3|1.5;Recepcionista de hotel|5|1.3;Chefe de cozinha|5|2.6;Barman|3|1.3;Pizzaiolo|3|1.4",
        10: "Faxineiro|2|1.1;Porteiro de edifícios|3|1.2;Zelador de edifício|3|1.2;Jardineiro|2|1.2;Auxiliar de manutenção predial|3|1.3;Vigia|3|1.2;Copeiro|2|1.1;Trabalhador de serviços de limpeza e conservação de áreas públicas|2|1.1;Lavador de veículos|2|1.1",
        11: "Trabalhador agropecuário em geral|2|1.1;Tratorista agrícola|2|1.5;Trabalhador da cultura de café|2|1.1;Técnico agrícola|5|2.2;Caseiro (agricultura)|2|1.2;Trabalhador da pecuária (bovinos leite)|2|1.2;Operador de colheitadeira|3|1.9;Engenheiro agrônomo|7|5.0;Trabalhador volante da agricultura|2|1.0",
        12: "Operador de telemarketing ativo e receptivo|5|1.1;Operador de telemarketing receptivo|5|1.1;Atendente de agência|5|1.4;Atendente comercial (agência postal)|5|1.4;Operador de telemarketing ativo|5|1.1;Supervisor de telemarketing e atendimento|5|2.0;Operador de telemarketing técnico|5|1.3;Telefonista|3|1.1"}
_k = lambda s: sem_acento(s.lower())
CBO = {_k(r["titulo"]): (r["cod_cbo"], r["titulo"]) for r in ler("cbo_ocupacao.csv")}
OCUPACOES, fora = {}, 0
for a, txt in OCUP.items():
    OCUPACOES[a] = []
    for item in txt.split(";"):
        t, esc, mult = item.split("|")
        if _k(t) in CBO: OCUPACOES[a].append((CBO[_k(t)][0], CBO[_k(t)][1], int(esc), float(mult)))
        else: fora += 1
print(f"  ocupacoes CBO usadas: {sum(len(v) for v in OCUPACOES.values())} (sem correspondencia: {fora})")

# secao CNAE -> (peso, ramos para razao social, prefixos de fantasia, areas provaveis)
SECOES = {"G": (33, ["Comércio de Alimentos|47", "Materiais de Construção|47", "Confecções|47", "Autopeças|45", "Supermercados|47", "Móveis e Eletro|47", "Farmácia|47", "Papelaria|47", "Distribuidora|46"], ["Mercado", "Loja", "Empório", "Casa", "Magazine"], [2, 2, 2, 1, 8, 12]),
          "C": (8, ["Indústria de Alimentos|10", "Metalúrgica|24,25", "Indústria Têxtil|13,14", "Indústria de Plásticos|22", "Laticínios|10", "Torrefação de Café|10", "Indústria de Móveis|31"], ["Indústria", "Fábrica"], [6, 6, 6, 1, 8]),
          "F": (7, ["Construtora|41", "Engenharia e Construções|42", "Reformas e Acabamentos|43", "Instalações Elétricas|43"], ["Construtora", "Obras"], [7, 7, 7, 1]),
          "I": (8, ["Restaurante|56", "Lanchonete|56", "Bar e Petiscaria|56", "Hotelaria|55", "Pizzaria|56"], ["Restaurante", "Padaria", "Cantina", "Hotel", "Sabor"], [9, 9, 9, 10]),
          "H": (5, ["Transportes|49", "Logística|52", "Transportadora|49", "Entregas Rápidas|53"], ["Trans", "Expresso", "Log"], [8, 8, 8, 1]),
          "J": (4, ["Tecnologia|62", "Sistemas|62", "Soluções Digitais|63", "Informática|62", "Telecom|61"], ["Tech", "Soft", "Data", "Net"], [3, 3, 3, 12, 1]),
          "M": (7, ["Contabilidade|69", "Consultoria|70", "Engenharia|71", "Assessoria Empresarial|70", "Publicidade|73"], ["Escritório", "Consult", "Grupo"], [1, 1, 1, 3]),
          "N": (8, ["Serviços Terceirizados|81,82", "Limpeza e Conservação|81", "Segurança Patrimonial|80", "Recursos Humanos|78", "Call Center|82"], ["Serv", "Multi", "Apoio"], [10, 10, 12, 12, 1]),
          "P": (3, ["Centro Educacional|85", "Escola de Idiomas|85", "Cursos Profissionalizantes|85", "Colégio|85"], ["Colégio", "Instituto", "Escola"], [5, 5, 5, 1]),
          "Q": (5, ["Clínica Médica|86", "Serviços de Saúde|86", "Laboratório de Análises|86", "Odontologia|86", "Casa de Repouso|87"], ["Clínica", "Vida", "Saúde"], [4, 4, 4, 1]),
          "S": (6, ["Serviços de Beleza|96", "Lavanderia|96", "Assistência Técnica|95"], ["Studio", "Espaço", "Central"], [10, 12, 6, 1]),
          "A": (1.5, ["Agropecuária|01", "Fazenda|01", "Cafeicultura|01", "Hortifruti|01"], ["Fazenda", "Agro", "Sítio"], [11, 11, 11, 8]),
          "K": (1.5, ["Correspondente Bancário|66", "Corretora de Seguros|66", "Cooperativa de Crédito|64"], ["Cred", "Seguros"], [1, 1, 12]),
          "L": (2, ["Imobiliária|68", "Administradora de Imóveis|68"], ["Imóveis", "Imobiliária"], [1, 2, 12]),
          "R": (1, ["Academia|93", "Produções Culturais|90", "Clube Recreativo|93"], ["Academia", "Arena"], [10, 5, 12])}
div_secao = {r["cod_divisao"]: r["cod_secao"] for r in ler("cnae_divisao.csv")}
gru_div = {r["cod_grupo"]: r["cod_divisao"] for r in ler("cnae_grupo.csv")}
CLASSES_DIV = defaultdict(list)
for r in ler("cnae_classe.csv"):
    CLASSES_DIV[gru_div[r["cod_grupo"]]].append(r["cod_classe"])
sec_ids, sec_pesos = list(SECOES), [SECOES[s][0] for s in SECOES]
# empresas concentram-se no Centro, Cidade Nova, Parque Tecnologico e Distrito Industrial
peso_emp_b = [14, 6, 7, 9, 8, 3, 4, 3, 4, 5, 4, 3, 4, 3, 3, 3, 4, 3, 3, 14]
PORTES = ["MEI", "ME", "EPP", "MEDIA", "GRANDE"]
VAGAS_PORTE = {"MEI": 0.3, "ME": 1.5, "EPP": 4, "MEDIA": 12, "GRANDE": 35}
INICIO_EMP = date(ANO - 2, 1, 2)
empresas, EMP_INFO = [], {}
cnpjs = [cnpj_dv(x + "0001") for x in numeros_unicos(args.empresas, 8)]
for i in range(args.empresas):
    sec = rng.choices(sec_ids, weights=sec_pesos)[0]
    _, ramos, prefixos, areas = SECOES[sec]
    porte = rng.choices(PORTES, weights=[30, 45, 18, 5, 2])[0]
    ramo, divs = rng.choice(ramos).split("|")
    classe = rng.choice(CLASSES_DIV[rng.choice(divs.split(","))])
    if porte == "MEI":
        sx = rng.choice("FM")
        razao = f"{prenome(sx, rng.randint(1965, 2000))} {sobrenome()} {sobrenome()} {cnpjs[i][:8]}"
    else:
        razao = f"{sobrenome()} & {sobrenome()} {ramo} {'S.A.' if porte == 'GRANDE' else 'Ltda'}" if rng.random() < 0.55 \
            else f"{ramo} {rng.choice([b[0] for b in BAIRROS] + SOBRENOMES[:40])} {'S.A.' if porte == 'GRANDE' else 'Ltda'}"
    fantasia = f"{rng.choice(prefixos)} {rng.choice(SOBRENOMES[:60] + [b[0] for b in BAIRROS])}" if rng.random() < 0.8 else ""
    b = rng.choices(range(NB), weights=peso_emp_b)[0]
    abertura = date.fromordinal(HOJE.toordinal() - int(rng.triangular(30, 45 * 365, 4 * 365)))
    sit = rng.choices(["ATIVA", "SUSPENSA", "BAIXADA"], weights=[90, 4, 6])[0]
    cad = data_entre(max(abertura, INICIO_BASE), max(abertura, INICIO_EMP))
    empresas.append((i + 1, cnpjs[i], razao, fantasia, classe, porte, rng.choice(logr_por_bairro[b]), numero_porta(),
                     f"contato{i + 1}@example.com", f"{DDD}3{rng.randint(1000000, 9999999)}", abertura, sit, ts(cad)))
    EMP_INFO[i + 1] = (porte, areas, sit, abertura)
gravar("emp_empresa", ["id_empresa", "cnpj", "razao_social", "nome_fantasia", "cod_cnae_classe", "porte", "id_logradouro", "numero",
                       "email", "telefone", "data_abertura", "situacao", "data_cadastro"], empresas)

# candidatos
pesos_c = []
elegiveis_c = [p for p in range(NP) if 16 <= P_idade[p] <= 62 and p not in PROF_CID]
for p in elegiveis_c:
    pesos_c.append(3.2 if P_renda[p] == 0 else 1.6 if P_renda[p] < SM else 0.35)
n_cand = min(len(elegiveis_c) // 3, round(args.habitantes * 0.096))
escolhidos = set()
acum, t = [], 0
for w in pesos_c:
    t += w; acum.append(t)
while len(escolhidos) < n_cand:
    escolhidos.update(rng.choices(elegiveis_c, cum_weights=acum, k=n_cand - len(escolhidos)))
candidatos, CAND_AREA, CAND_ESC, CAND_ATIVO_CID = [], defaultdict(list), {}, set()
for p in sorted(escolhidos):
    idc = len(candidatos) + 1
    f = FATOR[H_bairro[P_hh[p]]]
    esc = rng.choices(range(1, 9), weights=[1, 9 / f, 9, 10, 38, 12 * f, 16 * f, 5 * f])[0] if P_idade[p] >= 22 else \
        rng.choices([2, 3, 4, 5, 6], weights=[4, 8, 30, 46, 12])[0]
    pesos_a = [9, 14, 5 if esc >= 5 else 1, 7, 4, 10, 8, 9, 10, 12, 2, 8]
    area = rng.choices(range(1, 13), weights=pesos_a)[0]
    sit = "ATIVO" if rng.random() < 0.93 else "INATIVO"
    candidatos.append([idc, p + 1, esc, area, round(SM * rng.choice([1, 1.1, 1.2, 1.5, 2, 2.5, 3, 4]) * (1.6 if esc >= 7 else 1), 2),
                       f"Experiência em {AREAS[area - 1].lower()}. Escolaridade: nível {esc}.", None, sit])
    CAND_AREA[area].append(idc); CAND_ESC[idc] = esc
    if sit == "ATIVO": CAND_ATIVO_CID.add(p)
TODOS_CAND = list(range(1, len(candidatos) + 1))

vagas, candidaturas, historico = [], [], []
CONTRATADOS, prim_cand = set(), {}
ATIVOS = ["ENVIADA", "EM_ANALISE", "ENTREVISTA", "APROVADA"]
CAMINHO = ["ENVIADA", "EM_ANALISE", "ENTREVISTA", "APROVADA", "CONTRATADA"]
AGORA = datetime(HOJE.year, HOJE.month, HOJE.day, 8, 0)


def fmt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S-03")


def registrar_candidatura(idv, idc, inicio, limite, final):
    """Gera a candidatura e a linha do tempo ate o status final, sempre por transicoes validas."""
    if final in CAMINHO:
        passos = CAMINHO[:CAMINHO.index(final) + 1]
    else:  # RECUSADA ou CANCELADA depois de alguma etapa
        passos = CAMINHO[:rng.choices([1, 2, 3, 4], weights=[40, 35, 20, 5])[0]] + [final]
    span = max(60.0, (limite - inicio).total_seconds())
    cortes = sorted(rng.random() for _ in range(len(passos) - 1))
    tempos = [inicio] + [inicio + timedelta(seconds=int(span * c)) for c in cortes]
    idk = len(candidaturas) + 1
    candidaturas.append((idk, idc, idv, fmt(tempos[0]), final, fmt(tempos[-1])))
    for j, st in enumerate(passos):
        obs = "Vaga encerrada" if st == "RECUSADA" and rng.random() < 0.3 else ""
        historico.append((idk, passos[j - 1] if j else "", st, fmt(tempos[j]), "carga_inicial", obs))
    d = tempos[0].date()
    if idc not in prim_cand or d < prim_cand[idc]:
        prim_cand[idc] = d


for ide, (porte, areas, sit, abertura) in EMP_INFO.items():
    if sit != "ATIVA":
        continue
    media = VAGAS_PORTE[porte]
    n = int(rng.expovariate(1 / media) + rng.random()) if media >= 1 else (1 if rng.random() < media else 0)
    for _ in range(n):
        area = rng.choice(areas)
        cod, tit, esc, mult = rng.choice(OCUPACOES[area])
        pub = data_entre(max(INICIO_EMP, abertura), HOJE)
        dias = (HOJE - pub).days
        if dias <= 45: status = rng.choices(["ABERTA", "SUSPENSA", "PREENCHIDA", "ENCERRADA", "CANCELADA"], weights=[78, 3, 12, 4, 3])[0]
        elif dias <= 120: status = rng.choices(["ABERTA", "SUSPENSA", "PREENCHIDA", "ENCERRADA", "CANCELADA"], weights=[18, 3, 56, 16, 7])[0]
        else: status = rng.choices(["ABERTA", "PREENCHIDA", "ENCERRADA", "CANCELADA"], weights=[2, 66, 23, 9])[0]
        fech = None if status in ("ABERTA", "SUSPENSA") else min(HOJE, pub + timedelta(days=rng.randint(7, 75)))
        tipo = rng.choices(["CLT", "TEMPORARIO", "ESTAGIO", "APRENDIZ", "PJ"], weights=[78, 8, 6 if esc >= 5 else 0, 4, 4])[0]
        sal = round(SM * mult * rng.uniform(0.92, 1.25) * (0.6 if tipo in ("ESTAGIO", "APRENDIZ") else 1), 2)
        pos = rng.choices([1, 2, 3, 5, 8], weights=[68, 17, 8, 5, 2])[0] if porte not in ("MEI", "ME") else 1
        idv = len(vagas) + 1
        # candidaturas
        ini_dt = datetime(pub.year, pub.month, pub.day, 8, 0)
        lim_dt = AGORA if fech is None else datetime(fech.year, fech.month, fech.day, 17, 30)
        napp = int(rng.gammavariate(2.0, 3.6)) + (1 if status == "PREENCHIDA" else 0)
        pool_a = CAND_AREA[area]
        apps = set()
        for _ in range(napp * 2):
            if len(apps) >= napp: break
            c = rng.choice(pool_a) if rng.random() < 0.75 else rng.choice(TODOS_CAND)
            if CAND_ESC[c] >= esc - (1 if rng.random() < 0.1 else 0):
                apps.add(c)
        apps = list(apps)
        rng.shuffle(apps)
        contratar = 0
        if status == "PREENCHIDA":
            livres = [c for c in apps if c not in CONTRATADOS and CAND_ESC[c] >= esc]
            if not livres:
                status = "ENCERRADA"
            else:
                pos = min(pos, len(livres)); contratar = pos
                apps = livres[:pos] + [c for c in apps if c not in livres[:pos]]
        elif status == "ENCERRADA" and pos > 1:
            contratar = rng.randint(0, pos - 1)
        elif status in ("ABERTA", "SUSPENSA") and pos > 1 and rng.random() < 0.25:
            contratar = rng.randint(1, pos - 1)
        vagas.append((idv, ide, area, cod, tit, f"Vaga para {tit.lower()}. Contrato {tipo}.", tipo, sal, pos, esc, pub, fech or "", status))
        for c in apps:
            d_app = ini_dt + timedelta(seconds=rng.randint(0, max(3600, int((lim_dt - ini_dt).total_seconds() * 0.7))))
            if d_app >= lim_dt: d_app = ini_dt + timedelta(hours=2)
            if contratar and c not in CONTRATADOS and CAND_ESC[c] >= esc:
                contratar -= 1; CONTRATADOS.add(c)
                registrar_candidatura(idv, c, d_app, lim_dt, "CONTRATADA")
            elif status in ("ABERTA", "SUSPENSA"):
                final = rng.choices(ATIVOS + ["RECUSADA", "CANCELADA"], weights=[36, 26, 12, 4, 17, 5])[0]
                registrar_candidatura(idv, c, d_app, AGORA, final)
                if final == "RECUSADA" and status == "ABERTA" and rng.random() < 0.06:
                    # EMP-RN03: depois de recusado, o candidato pode tentar de novo a mesma vaga
                    ult = datetime.strptime(candidaturas[-1][5][:19], "%Y-%m-%d %H:%M:%S")
                    if ult + timedelta(hours=30) < AGORA:
                        registrar_candidatura(idv, c, ult + timedelta(hours=26), AGORA, rng.choice(ATIVOS[:2]))
            else:
                registrar_candidatura(idv, c, d_app, lim_dt, rng.choices(["RECUSADA", "CANCELADA"], weights=[86, 14])[0])
for c in candidatos:
    idc = c[0]
    base = prim_cand.get(idc)
    c[6] = (base - timedelta(days=rng.randint(0, 40))) if base else data_entre(INICIO_EMP, HOJE)
gravar("emp_candidato", ["id_candidato", "id_cidadao", "id_escolaridade", "id_area_interesse", "pretensao_salarial",
                         "resumo_profissional", "data_cadastro", "situacao"], candidatos)
gravar("emp_vaga", ["id_vaga", "id_empresa", "id_area", "cod_cbo", "titulo", "descricao", "tipo_contrato", "salario", "qtd_posicoes",
                    "id_escolaridade_minima", "data_publicacao", "data_encerramento", "status"], vagas)
gravar("emp_candidatura", ["id_candidatura", "id_candidato", "id_vaga", "data_candidatura", "status", "data_status"], candidaturas)
gravar("emp_candidatura_historico", ["id_candidatura", "status_anterior", "status_novo", "data_hora", "usuario", "observacao"], historico)
CAND_CID = {c[1] - 1 for c in candidatos}
del candidaturas, historico

# ======================================================== assistencia social
PROGRAMAS = [
    (1, "PBF", "Programa Bolsa Família", "FEDERAL", "Lei 14.601/2023", 600.00, date(2023, 3, 1)),
    (2, "BPC-IDOSO", "Benefício de Prestação Continuada - Pessoa Idosa", "FEDERAL", "Lei 8.742/1993 (LOAS), art. 20", SM, date(1996, 1, 1)),
    (3, "BPC-PCD", "Benefício de Prestação Continuada - Pessoa com Deficiência", "FEDERAL", "Lei 8.742/1993 (LOAS), art. 20", SM, date(1996, 1, 1)),
    (4, "QUALIFICA", "Qualifica Nova Esperança", "MUNICIPAL", "Lei Municipal 1.204/2024 (fictícia)", 300.00, date(2024, 3, 1)),
    (5, "MATERIAL", "Auxílio Material Escolar", "MUNICIPAL", "Lei Municipal 1.118/2022 (fictícia)", 120.00, date(2022, 1, 10)),
    (6, "ALIMENTA", "Cartão Alimentação Municipal", "MUNICIPAL", "Lei Municipal 1.167/2023 (fictícia)", 180.00, date(2023, 6, 1))]
CRITERIOS = [(1, "RENDA_PER_CAPITA_MAX", 218.00), (1, "FREQUENCIA_ESCOLAR", ""),
             (2, "RENDA_PER_CAPITA_MAX", round(SM / 4, 2)), (2, "IDADE_MIN", 65),
             (3, "RENDA_PER_CAPITA_MAX", round(SM / 4, 2)), (3, "PCD", ""),
             (4, "RENDA_PER_CAPITA_MAX", round(SM / 2, 2)), (4, "IDADE_MIN", 16), (4, "CADASTRO_EMPREGO", ""),
             (5, "RENDA_PER_CAPITA_MAX", round(SM / 2, 2)), (5, "POSSUI_ALUNO", ""),
             (6, "RENDA_PER_CAPITA_MAX", round(SM / 2, 2))]
gravar("ass_programa", ["id_programa", "codigo", "nome", "esfera", "base_legal", "valor_referencia", "data_inicio", "ativo"],
       [(*p, "t") for p in PROGRAMAS])
gravar("ass_criterio_elegibilidade", ["id_programa", "tipo_criterio", "valor"], CRITERIOS)

# unidades: 8 CRAS (territorios) e 2 CREAS
TERRITORIOS = [[0, 1, 2], [3, 9], [4, 5, 6], [7], [8, 10, 11], [12, 13], [14, 15], [16, 17, 18, 19]]
unidades, abrang, CRAS_B = [], [], {}
for k, bs in enumerate(TERRITORIOS, 1):
    unidades.append((k, f"CRAS {BAIRROS[bs[-1] if len(bs) > 1 else bs[0]][0]}", "CRAS", rng.choice(logr_por_bairro[bs[0]]), numero_porta()))
    for b in bs:
        abrang.append((b + 1, k)); CRAS_B[b] = k
unidades.append((9, "CREAS Centro", "CREAS", rng.choice(logr_por_bairro[0]), numero_porta()))
unidades.append((10, "CREAS Zona Leste", "CREAS", rng.choice(logr_por_bairro[12]), numero_porta()))
gravar("ass_unidade_atendimento", ["id_unidade", "nome", "tipo", "id_logradouro", "numero"], unidades)
gravar("ass_abrangencia_unidade", ["id_bairro", "id_unidade"], sorted(abrang))
TIPOS_AT = ["Acolhida", "Atualização cadastral", "Orientação sobre benefícios", "Visita domiciliar",
            "Acompanhamento familiar (PAIF)", "Encaminhamento para a rede de serviços", "Concessão de benefício eventual",
            "Atendimento psicossocial"]
gravar("ass_tipo_atendimento", ["id_tipo", "nome"], list(enumerate(TIPOS_AT, 1)))

profissionais, PROF_UNID = [], defaultdict(list)
for u in unidades:
    for _ in range(max(3, round(args.habitantes / 42000))):
        while True:
            p = cand_prof.pop()
            if p not in CAND_CID: break
        idp = len(profissionais) + 1
        cargo = rng.choices(["ASSISTENTE_SOCIAL", "PSICOLOGO", "EDUCADOR_SOCIAL"], weights=[55, 25, 20])[0]
        reg = {"ASSISTENTE_SOCIAL": f"CRESS-MG {rng.randint(10000, 39999)}", "PSICOLOGO": f"CRP-04/{rng.randint(10000, 69999)}", "EDUCADOR_SOCIAL": ""}[cargo]
        profissionais.append((idp, p + 1, cargo, reg, "ATIVO"))
        PROF_UNID[u[0]].append(idp)
gravar("ass_profissional", ["id_profissional", "id_cidadao", "cargo", "registro_profissional", "situacao"], profissionais)

familias, membros, beneficiarios, beneficios, atendimentos = [], [], [], [], []
cods = numeros_unicos(NH, 11)
nis = numeros_unicos(NP // 3, 11)
INICIO_ASS = date(2015, 1, 5)
BEN = {}          # pessoa -> id_beneficiario


def novo_beneficiario(p, desde, pcd):
    idb = len(beneficiarios) + 1
    beneficiarios.append((idb, p + 1, nis[idb - 1], "t" if pcd else "f", desde, "ATIVO"))
    BEN[p] = idb
    return idb


MOTIVOS = ["Superação da condição de renda", "Cadastro desatualizado", "Mudança de município", "Descumprimento de condicionalidade",
           "Solicitação do beneficiário"]
for h in range(NH):
    pc = H_pc[h]
    prob = 0.93 if pc <= 218 else 0.74 if pc <= SM / 2 else 0.04 if pc <= SM else 0.0
    if rng.random() >= prob or any(p in PROF_CID for p in H_membros[h]):
        continue
    mem = H_membros[h]
    adultos = [p for p in mem if P_idade[p] >= 18]
    if not adultos:
        continue
    refs = [p for p in adultos if P_papel[p] == "ref"] or adultos
    resp = next((p for p in refs if P_sexo[p] == "F"), refs[0])
    idf = len(familias) + 1
    cad = data_entre(INICIO_ASS, HOJE - timedelta(days=30))
    atu = data_entre(max(cad, HOJE - timedelta(days=730)), HOJE) if rng.random() < 0.86 else data_entre(cad, max(cad, HOJE - timedelta(days=731)))
    familias.append((idf, cods[h], cad, atu, "ATIVA"))
    for p in mem:
        par = "RESPONSAVEL" if p == resp else "CONJUGE" if P_papel[p] == "ref" else "FILHO" if P_papel[p] == "filho" else "PAI_MAE"
        membros.append((idf, p + 1, max(cad, P_nasc[p]), "", par, f"{P_renda[p]:.2f}"))
    # criterios apurados com a mesma logica de ass.fn_avaliar_elegibilidade
    n = len(mem)
    em_idade = [p for p in mem if 7 <= P_idade[p] <= 14]
    freq_ok = all(p in ALUNO_ATIVO for p in em_idade)
    tem_aluno = any(p in ALUNO_ATIVO for p in mem)
    n06 = sum(1 for p in mem if P_idade[p] <= 6)
    n717 = sum(1 for p in mem if 7 <= P_idade[p] <= 17)
    propostas = []
    for p in mem:
        if P_idade[p] < 16:
            continue
        pcd = rng.random() < 0.075
        eh_resp = p == resp
        quer = eh_resp or P_idade[p] >= 65 or pcd or (p in CAND_CID and rng.random() < 0.7) or rng.random() < 0.12
        if not quer:
            continue
        idb = novo_beneficiario(p, max(cad, date(P_nasc[p].year + 16, P_nasc[p].month, min(P_nasc[p].day, 28))), pcd)
        if eh_resp and pc <= 218 and freq_ok and rng.random() < 0.90:
            propostas.append((idb, 1, 600 + 150 * n06 + 50 * n717))
        if P_idade[p] >= 65 and pc <= SM / 4 and rng.random() < 0.85:
            propostas.append((idb, 2, SM))
        if pcd and pc <= SM / 4 and rng.random() < 0.80:
            propostas.append((idb, 3, SM))
        if pc <= SM / 2 and p in CAND_ATIVO_CID and rng.random() < 0.45:
            propostas.append((idb, 4, 300))
        if eh_resp and pc <= SM / 2 and tem_aluno and rng.random() < 0.75:
            propostas.append((idb, 5, 120))
        if eh_resp and pc <= SM / 2 and rng.random() < 0.50:
            propostas.append((idb, 6, 180))
        # beneficios antigos ja encerrados (historico)
        if eh_resp and rng.random() < 0.16:
            prog = rng.choice([1, 5, 6])
            ini = data_entre(max(cad, PROGRAMAS[prog - 1][6]), HOJE - timedelta(days=200))
            beneficios.append((idb, prog, ini, data_entre(ini + timedelta(days=60), HOJE - timedelta(days=30)), "ENCERRADO",
                               PROGRAMAS[prog - 1][5], rng.choice(MOTIVOS)))
        # atendimentos
        unid = CRAS_B[H_bairro[h]]
        for _ in range(int(rng.expovariate(1 / (3.4 if eh_resp else 1.3)))):
            u = unid if rng.random() < 0.9 else rng.choice([9, 10])
            tp = rng.choices(range(1, 9), weights=[14, 26, 22, 8, 10, 10, 5, 5])[0] if u <= 8 else rng.choices([4, 5, 6, 8], weights=[20, 30, 20, 30])[0]
            d = data_entre(max(cad, date(ANO - 3, 1, 2)), HOJE - timedelta(days=1))
            enc = rng.choice(["Unidade Básica de Saúde", "Secretaria Municipal de Educação", "Posto de atendimento ao trabalhador",
                              "Defensoria Pública", "Agência do INSS", "Secretaria Municipal de Habitação"]) if tp == 6 or rng.random() < 0.05 else ""
            prog = rng.choice([1, 5, 6, 4]) if tp in (2, 3) and rng.random() < 0.6 else ""
            atendimentos.append((idb, rng.choice(PROF_UNID[u]), u, tp, prog, ts(d), f"{TIPOS_AT[tp - 1]} realizada na unidade. Registro sintético.", enc))
    for idb, prog, valor in propostas:
        ini = data_entre(max(cad, PROGRAMAS[prog - 1][6]), HOJE - timedelta(days=5))
        beneficios.append((idb, prog, ini, "", "ATIVO" if rng.random() < 0.97 else "SUSPENSO", f"{valor:.2f}", ""))
gravar("ass_familia", ["id_familia", "codigo_familiar", "data_cadastro", "data_atualizacao", "situacao"], familias)
gravar("ass_familia_membro", ["id_familia", "id_cidadao", "data_entrada", "data_saida", "parentesco", "renda_mensal"], membros)
gravar("ass_beneficiario", ["id_beneficiario", "id_cidadao", "nis", "pcd", "data_cadastro", "situacao"], beneficiarios)
gravar("ass_beneficio_proposto", ["id_beneficiario", "id_programa", "data_concessao", "data_encerramento", "situacao", "valor_mensal", "motivo_encerramento"], beneficios)
atendimentos.sort(key=lambda a: a[5])
gravar("ass_atendimento", ["id_beneficiario", "id_profissional", "id_unidade", "id_tipo", "id_programa", "data_hora", "descricao", "encaminhamento"], atendimentos)

# ------------------------------------------------------------------- resumo
i014 = sum(1 for i in P_idade if i <= 14) / NP
i60 = sum(1 for i in P_idade if i >= 60) / NP
print(f"Resumo: {NP:,} cidadaos em {NH:,} domicilios ({NP / NH:.2f} por domicilio) | 0 a 14 anos {i014:.1%} | 60+ {i60:.1%}")
print(f"        {n_alunos:,} alunos | {len(professores):,} professores | {len(vagas):,} vagas | {len(familias):,} familias na assistencia")
