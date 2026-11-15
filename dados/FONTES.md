# Fontes de dados

## Princípio

Dado real e público sempre que existe. Dado sintético só onde o dado real é individual, sigiloso ou inexistente. Nenhuma API paga, nenhuma chave de acesso, nenhum serviço de IA.

## Dados públicos reais (`dados/referencia/`)

| Tabela | Conteúdo | Fonte oficial | Arquivo usado | Linhas |
|---|---|---|---|---:|
| `ref.uf` | 27 unidades da federação e região | IBGE, API de Localidades | espelho `kelvins/municipios-brasileiros` (CSV) | 27 |
| `ref.municipio` | municípios com código IBGE de 7 dígitos, coordenadas e DDD | IBGE, API de Localidades | idem | 5.571 |
| `ref.cnae_*` | CNAE 2.3: 21 seções, 87 divisões, 285 grupos, 673 classes | IBGE/CONCLA, API CNAE v2 | espelho `pedrounes1/CNAES-IBGE-2_3` (CSV) | 1.066 |
| `ref.cbo_ocupacao` | ocupações da CBO 2002 (código de 6 dígitos e título) | Ministério do Trabalho e Emprego | espelho `cartaproale/cbo-csv` (arquivo oficial "CBO2002 - Ocupacao.csv") | 2.719 |
| `ref.salario_minimo` | salário mínimo 2024 a 2026 | Decretos 11.864/2023, 12.342/2024, 12.797/2025 | digitado no SQL | 3 |
| (gerador) | 700 prenomes mais frequentes por década de nascimento | IBGE, Censo 2010, "Nomes no Brasil" | espelho `datasets-br/prenomes` | 700 |

Como funciona `scripts/01_baixar_dados_publicos.py`:

1. Tenta primeiro a API oficial do IBGE (`servicodados.ibge.gov.br`).
2. Se falhar (rede bloqueada, fora do ar), usa os espelhos em CSV no GitHub.
3. Os dois caminhos geram o mesmo formato em `dados/referencia/`. Ambos foram testados.
4. Arquivos já baixados em `dados/brutos/` não são baixados de novo. Use `--atualizar` para forçar.

Tratamento aplicado: códigos com zeros à esquerda preservados como texto; CBO convertida de Latin-1 para UTF-8; descrições da CNAE convertidas de caixa alta para título; nomes do Censo classificados por sexo com listas do Wikidata do mesmo repositório e correção manual dos nomes frequentes ambíguos (cobertura de 73,7% das ocorrências do Censo).

Os critérios dos programas federais seguem a legislação vigente: Bolsa Família com renda per capita até R$ 218 (Lei 14.601/2023) e BPC com renda per capita até 1/4 do salário mínimo (Lei 8.742/1993). O salário mínimo de 2026 é R$ 1.621.

## Fontes avaliadas e não usadas

| Fonte | Motivo |
|---|---|
| Microdados do Censo Escolar (INEP) | arquivo nacional de vários GB para usar 200 escolas fictícias; o código INEP é reproduzido só no formato (8 dígitos). |
| Cadastro de CNPJ (Receita Federal) | dezenas de GB e dados de empresas reais identificáveis; usamos CNPJs sintéticos com dígito verificador válido. |
| Novo CAGED | microdados de vínculo são agregados ou restritos; serviram de referência para a distribuição de setores. |
| CadÚnico | individual e sigiloso. |

## Dados sintéticos (`dados/gerados/`)

Gerados por `scripts/02_gerar_dados_sinteticos.py` com semente fixa (mesma semente, mesmos dados). Pessoas, CPFs, NIS, CNPJs, endereços, matrículas, vagas, candidaturas, famílias e atendimentos são fictícios. CPFs e CNPJs têm dígito verificador válido para passar nas restrições do banco. Os e-mails usam o domínio reservado `example.com`.

Coerência garantida pelo gerador e conferida pelo banco:

- composição de domicílios (sozinhos, casais, famílias com filhos, famílias estendidas) com idades compatíveis entre mães e filhos;
- renda por bairro, o que concentra a vulnerabilidade em bairros específicos;
- alunos matriculados no ano escolar compatível com a idade, com repetência e histórico de três anos;
- candidaturas com linha do tempo por transições válidas e datas dentro da vigência da vaga;
- benefícios: o gerador só **propõe**; o banco concede apenas os que passam em `ass.fn_elegivel` (ASS-RN04).
