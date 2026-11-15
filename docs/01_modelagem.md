# Modelagem de dados

Três níveis, do mais abstrato ao mais concreto: conceitual (o que existe no domínio), lógico (relações, chaves) e físico (PostgreSQL: tipos, restrições, índices). A fonte é o nosso Levantamento de Requisitos v1.0. Nada foi inventado fora dele: onde o documento deixava um ponto em aberto, a decisão está registrada aqui.

## 1. Princípio de arquitetura

O cidadão existe **uma vez**, no módulo CID. Aluno, professor, candidato, beneficiário, integrante de família e profissional da assistência são **papéis** de um cidadão. Cada papel é uma tabela do seu módulo que guarda só a chave `id_cidadao` e os dados próprios do papel.

```
                    ┌──────────────────────────┐
                    │  CID · cid.cidadao        │  CPF, nome, nascimento, sexo, mãe
                    │  (base cadastral única)   │  endereços com histórico, telefones
                    └────────────┬─────────────┘
            id_cidadao (FK)      │      id_cidadao (FK)
   ┌───────────────┬─────────────┼───────────────┬─────────────────┐
edu.aluno     edu.professor  emp.candidato  ass.beneficiario  ass.familia_membro
```

Consequência direta: uma mudança de endereço feita no CID aparece no mesmo instante nos relatórios de assistência por região, e um mesmo CPF não pode virar dois alunos. Isso atende ao objetivo do documento (seção 3.2): eliminar duplicidade e inconsistência entre setores.

## 2. Modelo conceitual

Diagrama geral: `diagramas/er_00_visao_geral.png`. Diagramas por módulo, com atributos: `er_01_cid` a `er_05_ref`.

### Entidades e relacionamentos

| Relacionamento | Cardinalidade | Regra de origem |
|---|---|---|
| Cidadão possui Telefone | 1 : N | CID-RN03 |
| Cidadão reside em Endereço (com vigência) | 1 : N ao longo do tempo, 1 : 1 vigente | CID-RF05, CID-RF06, CID-RN04 |
| Logradouro pertence a Bairro; Bairro pertence a Região | N : 1; N : 1 | Ponto em aberto 04 |
| Cidadão atua como Aluno | 1 : 0..1 | EDU-UC01 |
| Aluno vinculado a Escola | N : 1 (obrigatório) | EDU-RN01 |
| Aluno matricula-se em Disciplina, por Período letivo | N : N (entidade associativa Matrícula) | EDU-RF05, EDU-RN02, EDU-RN03 |
| Professor leciona Disciplina, por Escola e Período | N : N (Atribuição docente) | EDU-RF08, EDU-RN05 |
| Empresa publica Vaga | 1 : N (obrigatório) | EMP-RN01 |
| Candidato candidata-se a Vaga | N : N (Candidatura) | EMP-RF04, EMP-RN02 |
| Candidatura passa por Status | 1 : N (Histórico) | EMP-RN05, EMP-RNF04 |
| Família composta por Cidadãos | N : N com vigência (Integrante) | ASS-UC01 |
| Beneficiário vinculado a Programa | N : N (Benefício concedido) | ASS-RF04, ASS-RN04 |
| Programa possui Critério | 1 : N (mínimo 1) | ASS-RN02 |
| Beneficiário recebe Atendimento | 1 : N | ASS-RF05, ASS-RN03 |

### Por que essas escolhas

**Matrícula por período letivo.** A pergunta do slide de Educação ("como representar o relacionamento entre alunos e disciplinas?") tem resposta clássica: N:N vira entidade associativa. O período entra na chave porque a EDU-RN03 proíbe duplicidade "no mesmo período letivo", e não para sempre. Um aluno reprovado pode cursar a disciplina de novo no ano seguinte.

**Disciplina = componente curricular em um ano escolar.** "Matemática do 5º ano" (EF05-MAT) é uma disciplina com código único (EDU-RN04). O componente (Matemática) e a área do conhecimento (BNCC) ficam em tabelas próprias.

**Histórico de candidatura em tabela separada.** A candidatura guarda o status atual, o que deixa a consulta do dia a dia simples. O histórico guarda cada transição, somente inserção (EMP-RNF04). O gatilho mantém os dois sempre coerentes.

**Status como dados, não como código.** O ponto em aberto 03 pedia os valores e as transições. Eles estão em `emp.status_*` e `emp.transicao_*`. A Secretaria de Trabalho pode criar um status novo sem mudar código.

**Critérios de programa como dados.** Mesma lógica para a ASS-RN02. `ass.criterio_elegibilidade` liga cada programa a tipos de critério (renda per capita máxima, idade, PcD, frequência escolar, cadastro no emprego). A função `ass.fn_avaliar_elegibilidade` lê esses critérios e apura cada um. Dois critérios cruzam módulos: frequência escolar consulta EDU e cadastro no emprego consulta EMP.

**Endereço da família.** Não existe coluna de endereço em `ass.familia`. O território da família é o endereço vigente do responsável no CID. Guardar outra cópia criaria exatamente a inconsistência que o projeto quer eliminar.

## 3. Modelo lógico (esquema relacional)

Notação: <u>sublinhado</u> = chave primária, `#` = chave estrangeira, `{…}` = chave candidata (UNIQUE).

**CID**
- REGIAO(<u>id_regiao</u>, nome) {nome}
- BAIRRO(<u>id_bairro</u>, nome, #id_regiao) {nome}
- LOGRADOURO(<u>id_logradouro</u>, cep, tipo, nome, #id_bairro) {cep}
- CIDADAO(<u>id_cidadao</u>, cpf, nome, nome_social, data_nascimento, sexo, nome_mae, #cod_municipio_nascimento, email, situacao, data_cadastro, data_atualizacao) {cpf}
- TELEFONE(<u>id_telefone</u>, #id_cidadao, ddd, numero, tipo, principal) {id_cidadao, ddd, numero}
- ENDERECO_CIDADAO(<u>id_endereco</u>, #id_cidadao, #id_logradouro, numero, complemento, data_inicio, data_fim)

**EDU**
- AREA_CONHECIMENTO(<u>id_area</u>, nome)
- COMPONENTE_CURRICULAR(<u>id_componente</u>, sigla, nome, #id_area)
- DISCIPLINA(<u>id_disciplina</u>, codigo, nome, #id_componente, ano_escolar, carga_horaria) {codigo} {id_componente, ano_escolar}
- PERIODO_LETIVO(<u>id_periodo</u>, ano, data_inicio, data_fim, situacao) {ano}
- ESCOLA(<u>id_escola</u>, cod_inep, nome, #id_logradouro, numero, ano_inicial, ano_final, telefone, situacao) {cod_inep}
- ALUNO(<u>id_aluno</u>, #id_cidadao, #id_escola, ra, ano_escolar, turno, data_ingresso, situacao) {id_cidadao} {ra}
- PROFESSOR(<u>id_professor</u>, #id_cidadao, registro_funcional, formacao, titulacao, data_admissao, situacao) {id_cidadao}
- ATRIBUICAO_DOCENTE(<u>#id_escola, #id_disciplina, #id_periodo, #id_professor</u>)
- MATRICULA(<u>id_matricula</u>, #id_aluno, #id_disciplina, #id_periodo, data_matricula, situacao, nota_final, frequencia_pct) {id_aluno, id_disciplina, id_periodo}

**EMP**
- EMPRESA(<u>id_empresa</u>, cnpj, razao_social, nome_fantasia, #cod_cnae_classe, porte, #id_logradouro, numero, email, telefone, data_abertura, situacao, data_cadastro) {cnpj}
- AREA_PROFISSIONAL(<u>id_area</u>, nome)
- STATUS_VAGA(<u>codigo</u>, descricao, aceita_candidatura); TRANSICAO_VAGA(<u>#de, #para</u>)
- STATUS_CANDIDATURA(<u>codigo</u>, descricao, ativa); TRANSICAO_CANDIDATURA(<u>#de, #para</u>)
- VAGA(<u>id_vaga</u>, #id_empresa, #id_area, #cod_cbo, titulo, descricao, tipo_contrato, salario, qtd_posicoes, #id_escolaridade_minima, data_publicacao, data_encerramento, #status)
- CANDIDATO(<u>id_candidato</u>, #id_cidadao, #id_escolaridade, #id_area_interesse, pretensao_salarial, resumo_profissional, data_cadastro, situacao) {id_cidadao}
- CANDIDATURA(<u>id_candidatura</u>, #id_candidato, #id_vaga, data_candidatura, #status, data_status)
- CANDIDATURA_HISTORICO(<u>id_historico</u>, #id_candidatura, #status_anterior, #status_novo, data_hora, usuario, observacao)

**ASS**
- FAMILIA(<u>id_familia</u>, codigo_familiar, data_cadastro, data_atualizacao, situacao) {codigo_familiar}
- FAMILIA_MEMBRO(<u>#id_familia, #id_cidadao, data_entrada</u>, data_saida, parentesco, renda_mensal)
- BENEFICIARIO(<u>id_beneficiario</u>, #id_cidadao, nis, pcd, data_cadastro, situacao) {id_cidadao} {nis}
- PROGRAMA(<u>id_programa</u>, codigo, nome, esfera, base_legal, valor_referencia, data_inicio, data_fim, ativo) {codigo}
- TIPO_CRITERIO(<u>codigo</u>, descricao, usa_valor)
- CRITERIO_ELEGIBILIDADE(<u>#id_programa, #tipo_criterio</u>, valor)
- BENEFICIO_CONCEDIDO(<u>id_beneficio</u>, #id_beneficiario, #id_programa, data_concessao, data_encerramento, situacao, valor_mensal, motivo_encerramento)
- UNIDADE_ATENDIMENTO(<u>id_unidade</u>, nome, tipo, #id_logradouro, numero); ABRANGENCIA_UNIDADE(<u>#id_bairro</u>, #id_unidade)
- PROFISSIONAL(<u>id_profissional</u>, #id_cidadao, cargo, registro_profissional, situacao) {id_cidadao}
- TIPO_ATENDIMENTO(<u>id_tipo</u>, nome)
- ATENDIMENTO(<u>id_atendimento</u>, #id_beneficiario, #id_profissional, #id_unidade, #id_tipo, #id_programa, data_hora, descricao, encaminhamento)

**REF** (dados públicos): UF, MUNICIPIO, CNAE_SECAO, CNAE_DIVISAO, CNAE_GRUPO, CNAE_CLASSE, CBO_OCUPACAO, ESCOLARIDADE, SALARIO_MINIMO.

## 4. Modelo físico (PostgreSQL 16)

### Tipos

| Uso | Tipo | Motivo |
|---|---|---|
| Chave substituta | `integer GENERATED BY DEFAULT AS IDENTITY` | padrão SQL; `bigint` nas tabelas que crescem sem limite (histórico, atendimento, auditoria) |
| CPF, CNPJ, CEP | domínios `ref.cpf`, `ref.cnpj`, `ref.cep` | a validação de dígito verificador vive em um lugar só |
| Códigos com zero à esquerda (CNAE, CBO, INEP, NIS) | `char(n)` | não são números: não se soma CBO |
| Valores em reais | `numeric(10,2)` | exato; `float` erraria centavos |
| Datas de evento | `date`; momentos de operação `timestamptz` | fuso horário explícito |
| Domínios fechados (situação, turno) | `varchar` + `CHECK` | legível nas consultas; os estados com regra de transição usam tabela |

### Restrições que implementam regras

| Regra | Mecanismo físico |
|---|---|
| CID-RN01 | `UNIQUE (cpf)` + domínio com dígito verificador |
| CID-RN04 | índice único parcial (um endereço vigente) + `EXCLUDE USING gist` (sem sobreposição de períodos) + gatilho que bloqueia DELETE e UPDATE de histórico |
| EDU-RN03 | `UNIQUE (id_aluno, id_disciplina, id_periodo)` |
| EMP-RN03 | índice único **parcial**: só candidaturas ativas. Permite nova candidatura depois de recusada |
| EMP-RN04, EMP-RN05 | gatilhos consultando `status_vaga.aceita_candidatura` e `transicao_candidatura` |
| ASS-RN02 | gatilho de restrição **adiado** para o COMMIT: programa e critérios entram na mesma transação |
| ASS-RN04 | gatilho chama `ass.fn_elegivel` e informa qual critério falhou |
| ASS-RN05, EMP-RNF04, GER-RNF03 | gatilhos que tornam histórico e auditoria somente de inserção |

Códigos de erro próprios (`SC101` CID, `SC2xx` EDU, `SC3xx` EMP, `SC4xx` ASS, `SC901` auditoria) deixam a aplicação distinguir uma violação de regra de um erro técnico.

### Escala e volume

Ver `04_consultas_e_desempenho.md`. Um ponto da pergunta do slide de sensores ("um banco relacional é sempre a melhor solução?"): para os nossos quatro módulos, sim. São dados transacionais, com integridade forte entre cadastros. Para séries temporais de sensores, a resposta mudaria (particionamento por tempo ou banco de séries temporais).
