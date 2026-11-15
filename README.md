# SmartCity Connect · Banco de Dados Integrado

Projeto da disciplina de Banco de Dados (UNIFAL-MG). Equipe: Aurelio Junior, Gustavo Orlando e Julia Rocha.

Implementação completa, em PostgreSQL 16, dos quatro módulos do nosso Levantamento de Requisitos v1.0 para a cidade fictícia de Nova Esperança Digital:

| Módulo | Esquema | Papel |
|---|---|---|
| CID · Cadastro de Cidadãos | `cid` | Base cadastral única. Os outros módulos só guardam a chave `id_cidadao`. |
| EDU · Gestão da Educação | `edu` | Escolas, alunos, professores, disciplinas e matrículas. |
| EMP · Emprego e Desenvolvimento Econômico | `emp` | Empresas, vagas, candidatos, candidaturas e histórico de status. |
| ASS · Assistência Social | `ass` | Famílias, beneficiários, programas, critérios e atendimentos. |

Apoio: `ref` (dados públicos do IBGE e do MTE), `aud` (trilha de auditoria) e `rel` (relatórios e indicadores).

## Resultado em números

Base populada na escala dos slides do professor:

| Item | Quantidade |
|---|---:|
| Cidadãos | 500.000 |
| Bairros / regiões | 20 / 5 |
| Escolas municipais | 200 |
| Empresas | 15.000 |
| Matrículas (3 anos letivos) | 1.054.359 |
| Candidaturas / linhas de histórico | 256.307 / 787.786 |
| Famílias assistidas / atendimentos | 57.342 / 185.834 |
| Tabelas / FKs / gatilhos / índices | 48 / 60 / 37 / 107 |
| Tamanho do banco | 698 MB |

Verificação automática (pasta `docs/evidencias`):

| Verificação | Resultado |
|---|---|
| Testes de requisitos e regras de negócio | **75 de 75** passaram |
| Testes de segurança por perfil (login real) | **30 de 30** passaram |
| Auditoria de conformidade da carga | **29 de 29** regras sem violação |
| Backup e restauração | contagens idênticas após restaurar |

## Como executar

Pré-requisitos: PostgreSQL 16 (servidor e `psql`), Python 3.10 ou superior. Nenhuma biblioteca Python extra. Para os diagramas em SVG/PNG, opcionalmente `mermaid-cli` (`npm i -g @mermaid-js/mermaid-cli`).

```bash
# 1. conexão (exemplo local)
export PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres

# 2. tudo de uma vez: dados públicos, dados sintéticos, esquema, carga,
#    índices, segurança, relatórios, testes, evidências, dashboard e documentação
bash scripts/construir.sh             # escala completa, cerca de 5 minutos
bash scripts/construir.sh --pequeno   # 50 mil habitantes, cerca de 1 minuto
```

O script para no primeiro erro e falha se algum teste falhar. Depois:

```bash
psql -d smartcity -f sql/12_consultas.sql           # 25 consultas práticas
psql -d smartcity -f sql/13_operacoes_exemplo.sql   # casos de uso ponta a ponta (desfeitos no final)
xdg-open dashboard/index.html                       # painel (abre offline)
bash scripts/backup.sh --verificar                  # backup + teste de restauração
```

Execução manual, passo a passo: rode os scripts `scripts/01` e `scripts/02` e depois os arquivos de `sql/` em ordem numérica (01 a 11), sempre a partir da raiz do projeto.

## Estrutura

```
smartcity-connect/
├── README.md
├── scripts/
│   ├── 01_baixar_dados_publicos.py   aquisição e limpeza de dados públicos (IBGE, CNAE, CBO, nomes do Censo)
│   ├── 02_gerar_dados_sinteticos.py  população sintética coerente com as regras (semente fixa)
│   ├── 03_gerar_documentacao.py      diagramas ER e dicionário gerados do catálogo do banco
│   ├── construir.sh                  construção completa e reproduzível
│   └── backup.sh                     backup lógico com verificação de restauração
├── sql/
│   ├── 01_esquemas_e_funcoes.sql     extensões, esquemas, domínios CPF/CNPJ/CEP
│   ├── 02_ref.sql                    tabelas de referência pública
│   ├── 03_cid.sql … 06_ass.sql       um arquivo por módulo: tabelas, restrições, gatilhos, funções, visões
│   ├── 07_auditoria.sql              trilha de auditoria (GER-RNF03)
│   ├── 08_carga.sql                  carga com \copy
│   ├── 09_indices.sql                índices secundários justificados
│   ├── 10_seguranca.sql              perfis, privilégio mínimo, RLS
│   ├── 11_relatorios.sql             visões integradas e indicadores
│   ├── 12_consultas.sql              coleção de consultas práticas
│   └── 13_operacoes_exemplo.sql      operações de exemplo
├── testes/
│   ├── 01_testes_regras_de_negocio.sql
│   ├── 02_testes_seguranca.sh
│   ├── 03_auditoria_conformidade.sql
│   └── 04_desempenho.py
├── dados/
│   ├── FONTES.md                     origem, licença e tratamento de cada dado
│   ├── brutos/                       arquivos públicos como baixados
│   ├── referencia/                   dados públicos limpos
│   └── gerados/                      dados sintéticos (CSV, recriados pelo script 02; fora do zip por tamanho)
├── dashboard/
│   ├── gerar_dashboard.py
│   └── index.html
└── docs/
    ├── 01_modelagem.md               modelo conceitual, lógico e físico
    ├── 02_normalizacao.md            dependências funcionais, 1FN, 2FN, 3FN
    ├── 03_dicionario_de_dados.md     gerado do catálogo
    ├── 04_consultas_e_desempenho.md
    ├── 05_seguranca_auditoria_backup.md
    ├── 06_rastreabilidade.md         requisito → objeto do banco → teste
    ├── diagramas/                    ER em Mermaid, SVG e PNG
    └── evidencias/                   saídas reais dos testes e consultas
```

## Decisões que resolvem os pontos em aberto do documento de requisitos

| Nº | Ponto em aberto | Decisão implementada |
|---|---|---|
| 01 | Dados mínimos de identificação (CID-RN02) | CPF, nome, data de nascimento, sexo e nome da mãe, todos `NOT NULL`. |
| 02 | Critério de unicidade (CID-RN01) | CPF com dígitos verificadores validados e restrição `UNIQUE`. |
| 03 | Status de vaga e candidatura (EMP-RN05) | Tabelas de status e de transições permitidas, validadas por gatilho. |
| 04 | Conceito de "região" (ASS-RF08) | Região administrativa que agrupa bairros, pelo endereço vigente do cidadão. |
| 05 | Quantificar desempenho | Medido: buscas dos requisitos abaixo de 7 ms com 500 mil cidadãos. Ver `docs/04`. |

## Limitações conhecidas

Os dados de pessoas são sintéticos. Dados individuais reais (CPF, renda, matrícula) são protegidos pela LGPD e não existem em base aberta. As tabelas de referência são reais. O gerador não modela efeitos causais: por exemplo, o desempenho escolar sai parecido entre alunos de famílias atendidas e os demais (relatório R10), o que não deve ser lido como achado sobre a realidade.
