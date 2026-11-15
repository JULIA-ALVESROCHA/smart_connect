# Consultas, relatórios e desempenho

## 1. Relatórios que respondem aos exemplos do professor

Os slides de Emprego e de Assistência Social trazem exemplos de consulta. Cada um virou uma visão no esquema `rel`:

| Exemplo do slide | Visão | Técnica |
|---|---|---|
| Vagas abertas por área | `rel.r01_vagas_abertas_por_area` | GROUP BY, função de janela para % do total |
| Empresas que mais contratam | `rel.r02_empresas_que_mais_contratam` | JOIN com a hierarquia CNAE do IBGE, `dense_rank()` |
| Candidatos por empresa | `rel.r03_candidatos_por_empresa` | LEFT JOIN, `count(DISTINCT)`, `FILTER` |
| Benefícios concedidos | `rel.r04_beneficios_concedidos` | agregação condicional com `FILTER` |
| Famílias atendidas por programa | `rel.r05_familias_por_programa` | JOIN com visão derivada de renda |
| Atendimentos por região | `rel.r06_atendimentos_por_regiao` | `GROUPING SETS` (bairro, região e total em uma consulta) |

Também respondemos às perguntas dos slides de módulo:
- "Como lidar com o registro de milhares de cidadãos?" CPF único validado, busca por índice (0,5 ms) e por nome com trigramas (6 ms) em 500 mil registros.
- "Como representar o relacionamento entre alunos e disciplinas?" Entidade associativa MATRICULA com período letivo na chave (ver `02_normalizacao.md`).

## 2. Relatórios que só existem por causa da integração

| Visão | Módulos cruzados | O que mostra |
|---|---|---|
| `r07_populacao_por_bairro` | CID | pirâmide etária por bairro |
| `r08_painel_territorial` (e `mv_painel_territorial`) | CID, EDU, EMP, ASS | por bairro: habitantes, beneficiários, Bolsa Família por mil habitantes, alunos, candidatos, vagas abertas |
| `r09_beneficiarios_contratados` | ASS, EMP | beneficiários de cada programa que foram contratados |
| `r10_desempenho_por_vulnerabilidade` | ASS, EDU | nota, frequência e reprovação de alunos de famílias no Bolsa Família |
| `r11_indicadores_escola` | EDU | alunos por professor em cada escola |
| `r12_funil_candidaturas` | EMP | etapas do processo seletivo, a partir do histórico |
| `kpi_geral` | todos | indicadores de uma linha para o painel |

Sem a base única, cruzar "beneficiário" com "contratado" exigiria comparar nomes entre planilhas. Aqui é um JOIN por `id_cidadao`.

## 3. Coleção de consultas práticas

`sql/12_consultas.sql` tem 25 consultas comentadas com o requisito e a técnica. Saída real em `evidencias/05_consultas.txt`.

| Técnica | Consultas |
|---|---|
| JOIN interno e externo | Q02, Q05, Q06, Q12, Q15 |
| GROUP BY, HAVING, agregação condicional | Q04, Q07, Q09, Q16, Q17 |
| Subconsulta (escalar, no FROM, correlacionada) | Q02, Q04, Q19 |
| EXISTS e NOT EXISTS | Q13, Q20, Q21, Q23 |
| Funções de janela (`lag`, `lead`, `rank`) | Q03, Q08, Q14 |
| CTE (`WITH`) | Q03, R08, R10 |
| `LATERAL` (top N por linha) | Q23 |
| `GROUPING SETS` | Q18 |
| Visões e visão materializada | Q10, Q11, Q16 a Q18, Q22, Q24 |
| Funções do banco | Q01, Q20 |

Destaques:
- **Q20 Busca ativa.** Famílias elegíveis ao Bolsa Família que ainda não recebem, por bairro. Usa a mesma função de elegibilidade que bloqueia concessões indevidas.
- **Q21 Risco de perder o benefício.** Crianças de 7 a 14 anos de famílias atendidas que não estão na rede municipal (condicionalidade de frequência escolar).
- **Q23 Encaminhamento.** Para cada beneficiário do Qualifica ainda sem emprego, as três vagas abertas mais bem pagas compatíveis com área e escolaridade.

## 4. Desempenho

### Método

`testes/04_desempenho.py` mede cada consulta de requisito com `EXPLAIN ANALYZE` em dois cenários: **sem** o índice (removido dentro de uma transação desfeita, sem afetar a base) e **com** o índice. Mediana de 5 execuções com cache aquecido. Base completa (500 mil cidadãos, 698 MB). Resultado integral: `evidencias/04_desempenho.md`.

### Resultado

| Requisito | Consulta | Sem índice | Com índice | Ganho |
|---|---|---:|---:|---:|
| CID-RF07 | busca por trecho do nome, sem acento | 323 ms | 6,5 ms | 50x |
| CID-RF07 | busca por CPF | n/a | 0,5 ms | (índice da UNIQUE) |
| EMP-RF07 | vagas abertas de uma área | 4,0 ms | 0,6 ms | 7x |
| EMP-RF08 | candidatos de uma vaga | 10,3 ms | 0,4 ms | 27x |
| EMP-UC04 | linha do tempo de uma candidatura | 27,1 ms | 0,3 ms | 81x |
| EDU-RF07 | alunos de uma disciplina no período | 29,7 ms | 0,9 ms | 32x |
| ASS-RF06 | histórico de atendimentos de um beneficiário | 11,4 ms | 0,4 ms | 28x |
| ASS-RF07 | beneficiários ativos de um programa | 5,6 ms | 0,7 ms | 8x |
| Painel | visão territorial normal → materializada | 1.209 ms | 0,2 ms | 6.700x |

**Proposta para o ponto em aberto 05** (RNF verificáveis): "consultas operacionais de um registro (cidadão, vaga, aluno, beneficiário) em até 50 ms no percentil 95, com base de 500 mil cidadãos". Todas as consultas medidas ficam abaixo de 7 ms.

### Decisões de indexação

| Índice | Tipo | Por quê |
|---|---|---|
| `ix_cidadao_nome_trgm` | GIN com trigramas sobre `fn_normalizar(nome)` | `LIKE '%termo%'` não usa B-tree. Trigramas aceitam termo no meio do nome. A função de normalização é `IMMUTABLE` para poder ser indexada, e retira acento e caixa. |
| `ix_vaga_aberta_area` | B-tree **parcial** `WHERE status = 'ABERTA'` | só 7% das vagas estão abertas. Índice de 64 kB contra 6,6 MB da tabela. Já devolve em ordem de data, sem ordenação extra. |
| `uq_candidatura_ativa` | único **parcial** | implementa a EMP-RN03 e ainda serve de índice. |
| `ix_beneficio_programa_ativo` | B-tree parcial com `INCLUDE` | consulta resolvida só pelo índice (Index Only Scan). |
| `ix_matricula_disciplina_periodo` | B-tree composto | a UNIQUE (aluno, disciplina, período) começa por aluno e não serve para "alunos de uma disciplina" (EDU-RF07). |
| `ix_atendimento_data_brin` | BRIN | atendimentos chegam em ordem de data. 24 kB para 26 MB de tabela. Com 6 meses de dados o ganho é pequeno (1x); ele cresce com o volume, enquanto um B-tree ocuparia uns 4 MB. |
| Chaves estrangeiras | B-tree | PostgreSQL não cria índice em FK sozinho. Criamos onde a FK é usada em JOIN ou filtro frequente. |

Índices **não** criados: em colunas de baixa seletividade sem filtro parcial (sexo, situação do cidadão) e em FKs para tabelas minúsculas usadas só para validar (status, escolaridade).

### Outras otimizações

- **Carga com `\copy`** em uma única transação, índices secundários criados **depois** da carga. Carga completa (cerca de 5,5 milhões de linhas) em cerca de 2,5 minutos, incluindo a apuração de elegibilidade de 74 mil benefícios.
- **Visão materializada** no painel territorial, com índice único para permitir `REFRESH ... CONCURRENTLY` sem bloquear leitores.
- **`ANALYZE`** após a carga para o planejador ter estatísticas reais.
- Funções de consulta marcadas `STABLE`/`IMMUTABLE` e `PARALLEL SAFE` quando cabe.

### Escalabilidade (CID-RNF04, EDU-RNF04)

As tabelas que crescem sem limite são `candidatura_historico`, `atendimento` e `log_auditoria`. Todas usam `bigint`, são somente inserção e têm data. O próximo passo natural, quando passarem de dezenas de milhões de linhas, é particionar por ano (`PARTITION BY RANGE (data_hora)`), o que torna o arquivamento de anos antigos uma operação instantânea (`DETACH PARTITION`).
