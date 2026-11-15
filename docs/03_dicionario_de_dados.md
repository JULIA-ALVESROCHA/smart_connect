# Dicionário de dados

Gerado do catálogo do PostgreSQL por `scripts/03_gerar_documentacao.py`. Legenda: **PK** chave primária, **FK** chave estrangeira, **UK** única, **NN** obrigatória.

## Referência pública (`ref`)

### `ref.cbo_ocupacao`

Ocupacoes da Classificacao Brasileira de Ocupacoes 2002. Fonte: Ministerio do Trabalho e Emprego

Linhas: 2.719

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_cbo` | character(6) | PK | sim |  |  |
| `titulo` | character varying(150) |  | sim |  |  |

Restrições:
- `cbo_ocupacao_cod_cbo_check`: `CHECK ((cod_cbo ~ '^\d{6}$'::text))`

### `ref.cnae_classe`

Classes da CNAE 2.3. Fonte: IBGE/CONCLA

Linhas: 673

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_classe` | character(5) | PK | sim |  |  |
| `descricao` | character varying(200) |  | sim |  |  |
| `cod_grupo` | character(3) | FK | sim |  |  |

Chaves estrangeiras: `cod_grupo` → `ref.cnae_grupo`

### `ref.cnae_divisao`



Linhas: 87

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_divisao` | character(2) | PK | sim |  |  |
| `descricao` | character varying(160) |  | sim |  |  |
| `cod_secao` | character(1) | FK | sim |  |  |

Chaves estrangeiras: `cod_secao` → `ref.cnae_secao`

### `ref.cnae_grupo`



Linhas: 285

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_grupo` | character(3) | PK | sim |  |  |
| `descricao` | character varying(200) |  | sim |  |  |
| `cod_divisao` | character(2) | FK | sim |  |  |

Chaves estrangeiras: `cod_divisao` → `ref.cnae_divisao`

### `ref.cnae_secao`



Linhas: 21

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_secao` | character(1) | PK | sim |  |  |
| `descricao` | character varying(120) |  | sim |  |  |

### `ref.escolaridade`

Niveis de escolaridade ordenados: id maior = nivel mais alto

Linhas: 8

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_escolaridade` | smallint | PK | sim |  |  |
| `descricao` | character varying(40) | UK | sim |  |  |

Restrições:
- `escolaridade_descricao_key`: `UNIQUE (descricao)`

### `ref.municipio`

Municipios brasileiros (codigo IBGE de 7 digitos). Fonte: IBGE Localidades. ficticio = true apenas para Nova Esperanca Digital

Linhas: 5.572

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_ibge` | integer | PK | sim |  |  |
| `nome` | character varying(60) |  | sim |  |  |
| `cod_uf` | smallint | FK | sim |  |  |
| `latitude` | numeric(9,5) |  |  |  |  |
| `longitude` | numeric(9,5) |  |  |  |  |
| `ddd` | character(2) |  |  |  |  |
| `ficticio` | boolean |  | sim | `false` |  |

Chaves estrangeiras: `cod_uf` → `ref.uf`

Restrições:
- `municipio_cod_ibge_check`: `CHECK (((cod_ibge >= 1000000) AND (cod_ibge <= 9999999)))`

### `ref.salario_minimo`

Salario minimo nacional. Fonte: decretos federais

Linhas: 3

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `vigencia_inicio` | date | PK | sim |  |  |
| `valor` | numeric(10,2) |  | sim |  |  |
| `ato_legal` | character varying(60) |  | sim |  |  |

Restrições:
- `salario_minimo_valor_check`: `CHECK ((valor > (0)::numeric))`

### `ref.uf`

Unidades da Federacao. Fonte: IBGE Localidades

Linhas: 27

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `cod_uf` | smallint | PK | sim |  |  |
| `sigla` | character(2) | UK | sim |  |  |
| `nome` | character varying(40) | UK | sim |  |  |
| `regiao` | character varying(15) |  | sim |  |  |

Restrições:
- `uf_nome_key`: `UNIQUE (nome)`
- `uf_regiao_check`: `CHECK (((regiao)::text = ANY ((ARRAY['Norte'::character varying, 'Nordeste'::character varying, 'Sudeste'::character varying, 'Sul'::character varying, 'Centro-`
- `uf_sigla_key`: `UNIQUE (sigla)`

## CID · Cadastro de Cidadãos (`cid`)

### `cid.bairro`

Os 20 bairros do municipio

Linhas: 20

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_bairro` | smallint | PK | sim |  |  |
| `nome` | character varying(60) | UK | sim |  |  |
| `id_regiao` | smallint | FK | sim |  |  |

Chaves estrangeiras: `id_regiao` → `cid.regiao`

Restrições:
- `bairro_nome_key`: `UNIQUE (nome)`

### `cid.cidadao`

Base cadastral unica. Os modulos EDU, EMP e ASS referenciam id_cidadao e nao replicam dados pessoais

Linhas: 500.000

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_cidadao` | integer | PK | sim |  |  |
| `cpf` | ref.cpf | UK | sim |  | CID-RN01: unico e com digitos verificadores validados |
| `nome` | character varying(120) |  | sim |  |  |
| `nome_social` | character varying(120) |  |  |  |  |
| `data_nascimento` | date |  | sim |  |  |
| `sexo` | character(1) |  | sim |  | F, M ou N (nao informado) |
| `nome_mae` | character varying(120) |  | sim |  | CID-RN02: compoe os dados minimos de identificacao (cpf, nome, nascimento, sexo, mae) |
| `cod_municipio_nascimento` | integer | FK |  |  |  |
| `email` | character varying(254) |  |  |  |  |
| `situacao` | character varying(10) |  | sim | `'ATIVO'::character varying` |  |
| `data_cadastro` | timestamp with time zone |  | sim | `now()` |  |
| `data_atualizacao` | timestamp with time zone |  | sim | `now()` |  |

Chaves estrangeiras: `cod_municipio_nascimento` → `ref.municipio`

Restrições:
- `cidadao_data_nascimento_check`: `CHECK (((data_nascimento >= '1900-01-01'::date) AND (data_nascimento <= CURRENT_DATE)))`
- `cidadao_email_check`: `CHECK (((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))`
- `cidadao_nome_check`: `CHECK ((length(btrim((nome)::text)) >= 3))`
- `cidadao_nome_mae_check`: `CHECK ((length(btrim((nome_mae)::text)) >= 3))`
- `cidadao_sexo_check`: `CHECK ((sexo = ANY (ARRAY['F'::bpchar, 'M'::bpchar, 'N'::bpchar])))`
- `cidadao_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'INATIVO'::character varying, 'FALECIDO'::character varying])::text[])))`
- `uq_cidadao_cpf`: `UNIQUE (cpf)`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_cidadao_bu` (tg_cidadao_atualizacao)

### `cid.endereco_cidadao`

Historico de enderecos. Linhas encerradas sao imutaveis (CID-RN04, GER-RNF04)

Linhas: 635.098

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_endereco` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK | sim |  |  |
| `id_logradouro` | integer | FK | sim |  |  |
| `numero` | character varying(10) |  | sim |  |  |
| `complemento` | character varying(40) |  |  |  |  |
| `data_inicio` | date |  | sim |  |  |
| `data_fim` | date |  |  |  |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`; `id_logradouro` → `cid.logradouro`

Restrições:
- `ck_endereco_periodo`: `CHECK (((data_fim IS NULL) OR (data_fim >= data_inicio)))`
- `ex_endereco_sem_sobreposicao`: `EXCLUDE USING gist (id_cidadao WITH =, daterange(data_inicio, COALESCE(data_fim, 'infinity'::date), '[)'::text) WITH &&)`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_endereco_bud` (tg_endereco_protege_historico)

### `cid.logradouro`

Logradouros do municipio, um CEP por logradouro

Linhas: 4.546

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_logradouro` | integer | PK | sim |  |  |
| `cep` | ref.cep | UK | sim |  |  |
| `tipo` | character varying(15) |  | sim |  |  |
| `nome` | character varying(100) |  | sim |  |  |
| `id_bairro` | smallint | FK | sim |  |  |

Chaves estrangeiras: `id_bairro` → `cid.bairro`

Restrições:
- `logradouro_cep_key`: `UNIQUE (cep)`
- `logradouro_tipo_check`: `CHECK (((tipo)::text = ANY ((ARRAY['Rua'::character varying, 'Avenida'::character varying, 'Travessa'::character varying, 'Alameda'::character varying, 'Praça':`

### `cid.regiao`

Regioes administrativas de Nova Esperanca Digital (base de ASS-RF08)

Linhas: 5

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_regiao` | smallint | PK | sim |  |  |
| `nome` | character varying(40) | UK | sim |  |  |

Restrições:
- `regiao_nome_key`: `UNIQUE (nome)`

### `cid.telefone`



Linhas: 422.166

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_telefone` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK | sim |  |  |
| `ddd` | character(2) |  | sim |  |  |
| `numero` | character varying(9) |  | sim |  |  |
| `tipo` | character varying(8) |  | sim |  |  |
| `principal` | boolean |  | sim | `false` |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`

Restrições:
- `telefone_ddd_check`: `CHECK ((ddd ~ '^[1-9]\d$'::text))`
- `telefone_numero_check`: `CHECK (((numero)::text ~ '^\d{8,9}$'::text))`
- `telefone_tipo_check`: `CHECK (((tipo)::text = ANY ((ARRAY['CELULAR'::character varying, 'FIXO'::character varying, 'RECADO'::character varying])::text[])))`
- `uq_telefone`: `UNIQUE (id_cidadao, ddd, numero)`

Gatilhos: `tg_auditoria` (tg_auditar)

## EDU · Gestão da Educação (`edu`)

### `edu.aluno`

Papel de aluno de um cidadao. Dados pessoais ficam em cid.cidadao. EDU-RN01: id_escola obrigatorio

Linhas: 51.922

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_aluno` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK UK | sim |  |  |
| `id_escola` | integer | FK | sim |  |  |
| `ra` | character(10) | UK | sim |  |  |
| `ano_escolar` | smallint |  | sim |  |  |
| `turno` | character varying(8) |  | sim |  |  |
| `data_ingresso` | date |  | sim |  |  |
| `situacao` | character varying(11) |  | sim | `'ATIVO'::character varying` |  |

Chaves estrangeiras: `id_escola` → `edu.escola`; `id_cidadao` → `cid.cidadao`

Restrições:
- `aluno_ano_escolar_check`: `CHECK (((ano_escolar >= 1) AND (ano_escolar <= 9)))`
- `aluno_ra_key`: `UNIQUE (ra)`
- `aluno_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'TRANSFERIDO'::character varying, 'EVADIDO'::character varying, 'CONCLUINTE'::character varyi`
- `aluno_turno_check`: `CHECK (((turno)::text = ANY ((ARRAY['MANHA'::character varying, 'TARDE'::character varying, 'INTEGRAL'::character varying])::text[])))`
- `uq_aluno_cidadao`: `UNIQUE (id_cidadao)`

Gatilhos: `tg_auditoria` (tg_auditar)

### `edu.area_conhecimento`



Linhas: 5

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_area` | smallint | PK | sim |  |  |
| `nome` | character varying(40) | UK | sim |  |  |

Restrições:
- `area_conhecimento_nome_key`: `UNIQUE (nome)`

### `edu.atribuicao_docente`

Vinculo professor x disciplina por escola e periodo letivo (EDU-RN05)

Linhas: 35.988

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_escola` | integer | PK FK | sim |  |  |
| `id_disciplina` | integer | PK FK | sim |  |  |
| `id_periodo` | smallint | PK FK | sim |  |  |
| `id_professor` | integer | PK FK | sim |  |  |

Chaves estrangeiras: `id_escola` → `edu.escola`; `id_disciplina` → `edu.disciplina`; `id_periodo` → `edu.periodo_letivo`; `id_professor` → `edu.professor`

Gatilhos: `tg_auditoria` (tg_auditar)

### `edu.componente_curricular`

Componentes curriculares do Ensino Fundamental conforme a BNCC

Linhas: 9

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_componente` | smallint | PK | sim |  |  |
| `sigla` | character(3) | UK | sim |  |  |
| `nome` | character varying(40) | UK | sim |  |  |
| `id_area` | smallint | FK | sim |  |  |

Chaves estrangeiras: `id_area` → `edu.area_conhecimento`

Restrições:
- `componente_curricular_nome_key`: `UNIQUE (nome)`
- `componente_curricular_sigla_key`: `UNIQUE (sigla)`

### `edu.disciplina`

Disciplina = componente curricular em um ano escolar. EDU-RN04: codigo unico

Linhas: 76

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_disciplina` | integer | PK | sim |  |  |
| `codigo` | character varying(10) | UK | sim |  |  |
| `nome` | character varying(60) |  | sim |  |  |
| `id_componente` | smallint | FK | sim |  |  |
| `ano_escolar` | smallint |  | sim |  |  |
| `carga_horaria` | smallint |  | sim |  |  |

Chaves estrangeiras: `id_componente` → `edu.componente_curricular`

Restrições:
- `disciplina_ano_escolar_check`: `CHECK (((ano_escolar >= 1) AND (ano_escolar <= 9)))`
- `disciplina_carga_horaria_check`: `CHECK ((carga_horaria > 0))`
- `uq_disciplina_codigo`: `UNIQUE (codigo)`
- `uq_disciplina_componente_ano`: `UNIQUE (id_componente, ano_escolar)`

Gatilhos: `tg_auditoria` (tg_auditar)

### `edu.escola`

Escolas da rede municipal (EDU-RF01). cod_inep segue o formato do codigo INEP de 8 digitos

Linhas: 200

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_escola` | integer | PK | sim |  |  |
| `cod_inep` | character(8) | UK | sim |  |  |
| `nome` | character varying(120) | UK | sim |  |  |
| `id_logradouro` | integer | FK | sim |  |  |
| `numero` | character varying(10) |  | sim |  |  |
| `ano_inicial` | smallint |  | sim |  | Primeiro ano escolar ofertado (1 a 9) |
| `ano_final` | smallint |  | sim |  |  |
| `telefone` | character varying(11) |  |  |  |  |
| `situacao` | character varying(10) |  | sim | `'ATIVA'::character varying` |  |

Chaves estrangeiras: `id_logradouro` → `cid.logradouro`

Restrições:
- `ck_escola_anos`: `CHECK ((ano_final >= ano_inicial))`
- `escola_ano_final_check`: `CHECK (((ano_final >= 1) AND (ano_final <= 9)))`
- `escola_ano_inicial_check`: `CHECK (((ano_inicial >= 1) AND (ano_inicial <= 9)))`
- `escola_cod_inep_check`: `CHECK ((cod_inep ~ '^\d{8}$'::text))`
- `escola_cod_inep_key`: `UNIQUE (cod_inep)`
- `escola_nome_key`: `UNIQUE (nome)`
- `escola_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVA'::character varying, 'PARALISADA'::character varying, 'EXTINTA'::character varying])::text[])))`

Gatilhos: `tg_auditoria` (tg_auditar)

### `edu.matricula`

Matricula do aluno em disciplina por periodo letivo. EDU-RN03 via uq_matricula

Linhas: 1.054.359

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_matricula` | integer | PK | sim |  |  |
| `id_aluno` | integer | FK | sim |  |  |
| `id_disciplina` | integer | FK | sim |  |  |
| `id_periodo` | smallint | FK | sim |  |  |
| `data_matricula` | date |  | sim | `CURRENT_DATE` |  |
| `situacao` | character varying(10) |  | sim | `'CURSANDO'::character varying` |  |
| `nota_final` | numeric(4,2) |  |  |  |  |
| `frequencia_pct` | numeric(5,2) |  |  |  |  |

Chaves estrangeiras: `id_aluno` → `edu.aluno`; `id_disciplina` → `edu.disciplina`; `id_periodo` → `edu.periodo_letivo`

Restrições:
- `ck_matricula_resultado`: `CHECK ((((situacao)::text <> ALL ((ARRAY['APROVADO'::character varying, 'REPROVADO'::character varying])::text[])) OR (nota_final IS NOT NULL)))`
- `matricula_frequencia_pct_check`: `CHECK (((frequencia_pct >= (0)::numeric) AND (frequencia_pct <= (100)::numeric)))`
- `matricula_nota_final_check`: `CHECK (((nota_final >= (0)::numeric) AND (nota_final <= (10)::numeric)))`
- `matricula_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['CURSANDO'::character varying, 'APROVADO'::character varying, 'REPROVADO'::character varying, 'CANCELADA'::character vary`
- `uq_matricula`: `UNIQUE (id_aluno, id_disciplina, id_periodo)`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_matricula_bi` (tg_matricula_valida)

### `edu.periodo_letivo`



Linhas: 3

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_periodo` | smallint | PK | sim |  |  |
| `ano` | smallint | UK | sim |  |  |
| `data_inicio` | date |  | sim |  |  |
| `data_fim` | date |  | sim |  |  |
| `situacao` | character varying(10) |  | sim |  |  |

Restrições:
- `ck_periodo_datas`: `CHECK ((data_fim > data_inicio))`
- `periodo_letivo_ano_check`: `CHECK (((ano >= 2000) AND (ano <= 2100)))`
- `periodo_letivo_ano_key`: `UNIQUE (ano)`
- `periodo_letivo_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['PLANEJADO'::character varying, 'ABERTO'::character varying, 'ENCERRADO'::character varying])::text[])))`

### `edu.professor`

Papel de professor de um cidadao (EDU-RF03)

Linhas: 3.741

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_professor` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK UK | sim |  |  |
| `registro_funcional` | character(8) | UK | sim |  |  |
| `formacao` | character varying(80) |  | sim |  |  |
| `titulacao` | character varying(15) |  | sim |  |  |
| `data_admissao` | date |  | sim |  |  |
| `situacao` | character varying(10) |  | sim | `'ATIVO'::character varying` |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`

Restrições:
- `professor_registro_funcional_key`: `UNIQUE (registro_funcional)`
- `professor_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'AFASTADO'::character varying, 'DESLIGADO'::character varying])::text[])))`
- `professor_titulacao_check`: `CHECK (((titulacao)::text = ANY ((ARRAY['GRADUACAO'::character varying, 'ESPECIALIZACAO'::character varying, 'MESTRADO'::character varying, 'DOUTORADO'::charact`
- `uq_professor_cidadao`: `UNIQUE (id_cidadao)`

Gatilhos: `tg_auditoria` (tg_auditar)

## EMP · Emprego e Desenvolvimento Econômico (`emp`)

### `emp.area_profissional`

Areas do portal de vagas (EMP-RF07: vagas abertas por area)

Linhas: 12

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_area` | smallint | PK | sim |  |  |
| `nome` | character varying(50) | UK | sim |  |  |

Restrições:
- `area_profissional_nome_key`: `UNIQUE (nome)`

### `emp.candidato`

Papel de candidato de um cidadao (EMP-RF03). Dados pessoais ficam em cid.cidadao

Linhas: 48.000

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_candidato` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK UK | sim |  |  |
| `id_escolaridade` | smallint | FK | sim |  |  |
| `id_area_interesse` | smallint | FK |  |  |  |
| `pretensao_salarial` | numeric(10,2) |  |  |  |  |
| `resumo_profissional` | text |  |  |  |  |
| `data_cadastro` | date |  | sim | `CURRENT_DATE` |  |
| `situacao` | character varying(8) |  | sim | `'ATIVO'::character varying` |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`; `id_escolaridade` → `ref.escolaridade`; `id_area_interesse` → `emp.area_profissional`

Restrições:
- `candidato_pretensao_salarial_check`: `CHECK ((pretensao_salarial > (0)::numeric))`
- `candidato_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'INATIVO'::character varying])::text[])))`
- `uq_candidato_cidadao`: `UNIQUE (id_cidadao)`

Gatilhos: `tg_auditoria` (tg_auditar)

### `emp.candidatura`

Candidaturas (EMP-RF04). EMP-RN03 via indice unico parcial uq_candidatura_ativa

Linhas: 256.307

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_candidatura` | integer | PK | sim |  |  |
| `id_candidato` | integer | FK | sim |  |  |
| `id_vaga` | integer | FK | sim |  |  |
| `data_candidatura` | timestamp with time zone |  | sim | `now()` |  |
| `status` | character varying(10) | FK | sim | `'ENVIADA'::character varying` |  |
| `data_status` | timestamp with time zone |  | sim | `now()` |  |

Chaves estrangeiras: `id_vaga` → `emp.vaga`; `status` → `emp.status_candidatura`; `id_candidato` → `emp.candidato`

Restrições:
- `ck_candidatura_datas`: `CHECK ((data_status >= data_candidatura))`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_candidatura_aiu` (tg_candidatura_historico), `tg_candidatura_bi` (tg_candidatura_bi), `tg_candidatura_bu` (tg_candidatura_bu)

### `emp.candidatura_historico`

Linha do tempo de cada candidatura (EMP-UC04 passo 4). Somente insercao

Linhas: 787.786

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_historico` | bigint | PK | sim |  |  |
| `id_candidatura` | integer | FK | sim |  |  |
| `status_anterior` | character varying(10) | FK |  |  |  |
| `status_novo` | character varying(10) | FK | sim |  |  |
| `data_hora` | timestamp with time zone |  | sim | `now()` |  |
| `usuario` | character varying(63) |  | sim | `aud.fn_usuario()` |  |
| `observacao` | character varying(200) |  |  |  |  |

Chaves estrangeiras: `id_candidatura` → `emp.candidatura`; `status_anterior` → `emp.status_candidatura`; `status_novo` → `emp.status_candidatura`

Gatilhos: `tg_candidatura_historico_bud` (tg_historico_imutavel)

### `emp.empresa`

Empresas do municipio (EMP-RF01). Setor economico pela CNAE 2.3 do IBGE

Linhas: 15.000

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_empresa` | integer | PK | sim |  |  |
| `cnpj` | ref.cnpj | UK | sim |  |  |
| `razao_social` | character varying(150) |  | sim |  |  |
| `nome_fantasia` | character varying(100) |  |  |  |  |
| `cod_cnae_classe` | character(5) | FK | sim |  |  |
| `porte` | character varying(6) |  | sim |  |  |
| `id_logradouro` | integer | FK | sim |  |  |
| `numero` | character varying(10) |  | sim |  |  |
| `email` | character varying(254) |  |  |  |  |
| `telefone` | character varying(11) |  |  |  |  |
| `data_abertura` | date |  | sim |  |  |
| `situacao` | character varying(10) |  | sim | `'ATIVA'::character varying` |  |
| `data_cadastro` | timestamp with time zone |  | sim | `now()` |  |

Chaves estrangeiras: `cod_cnae_classe` → `ref.cnae_classe`; `id_logradouro` → `cid.logradouro`

Restrições:
- `empresa_cnpj_key`: `UNIQUE (cnpj)`
- `empresa_data_abertura_check`: `CHECK ((data_abertura <= CURRENT_DATE))`
- `empresa_email_check`: `CHECK (((email)::text ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'::text))`
- `empresa_porte_check`: `CHECK (((porte)::text = ANY ((ARRAY['MEI'::character varying, 'ME'::character varying, 'EPP'::character varying, 'MEDIA'::character varying, 'GRANDE'::character`
- `empresa_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVA'::character varying, 'SUSPENSA'::character varying, 'BAIXADA'::character varying])::text[])))`

Gatilhos: `tg_auditoria` (tg_auditar)

### `emp.status_candidatura`



Linhas: 7

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `codigo` | character varying(10) | PK | sim |  |  |
| `descricao` | character varying(80) |  | sim |  |  |
| `ativa` | boolean |  | sim |  |  |

### `emp.status_vaga`



Linhas: 5

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `codigo` | character varying(10) | PK | sim |  |  |
| `descricao` | character varying(80) |  | sim |  |  |
| `aceita_candidatura` | boolean |  | sim |  |  |

### `emp.transicao_candidatura`



Linhas: 12

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `de` | character varying(10) | PK FK | sim |  |  |
| `para` | character varying(10) | PK FK | sim |  |  |

Chaves estrangeiras: `de` → `emp.status_candidatura`; `para` → `emp.status_candidatura`

Restrições:
- `transicao_candidatura_check`: `CHECK (((de)::text <> (para)::text))`

### `emp.transicao_vaga`



Linhas: 7

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `de` | character varying(10) | PK FK | sim |  |  |
| `para` | character varying(10) | PK FK | sim |  |  |

Chaves estrangeiras: `de` → `emp.status_vaga`; `para` → `emp.status_vaga`

Restrições:
- `transicao_vaga_check`: `CHECK (((de)::text <> (para)::text))`

### `emp.usuario_empresa`



Linhas: 0

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `usuario` | name | PK | sim |  |  |
| `id_empresa` | integer | FK | sim |  |  |

Chaves estrangeiras: `id_empresa` → `emp.empresa`

### `emp.vaga`

Vagas de emprego (EMP-RF02). EMP-RN01: id_empresa obrigatorio. Ocupacao pela CBO 2002

Linhas: 38.301

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_vaga` | integer | PK | sim |  |  |
| `id_empresa` | integer | FK | sim |  |  |
| `id_area` | smallint | FK | sim |  |  |
| `cod_cbo` | character(6) | FK | sim |  |  |
| `titulo` | character varying(150) |  | sim |  |  |
| `descricao` | text |  |  |  |  |
| `tipo_contrato` | character varying(10) |  | sim |  |  |
| `salario` | numeric(10,2) |  |  |  |  |
| `qtd_posicoes` | smallint |  | sim | `1` |  |
| `id_escolaridade_minima` | smallint | FK | sim |  |  |
| `data_publicacao` | date |  | sim | `CURRENT_DATE` |  |
| `data_encerramento` | date |  |  |  |  |
| `status` | character varying(10) | FK | sim | `'ABERTA'::character varying` |  |

Chaves estrangeiras: `id_empresa` → `emp.empresa`; `id_area` → `emp.area_profissional`; `cod_cbo` → `ref.cbo_ocupacao`; `id_escolaridade_minima` → `ref.escolaridade`; `status` → `emp.status_vaga`

Restrições:
- `ck_vaga_datas`: `CHECK (((data_encerramento IS NULL) OR (data_encerramento >= data_publicacao)))`
- `ck_vaga_encerramento`: `CHECK ((((status)::text = ANY ((ARRAY['ABERTA'::character varying, 'SUSPENSA'::character varying])::text[])) = (data_encerramento IS NULL)))`
- `vaga_qtd_posicoes_check`: `CHECK ((qtd_posicoes > 0))`
- `vaga_salario_check`: `CHECK ((salario > (0)::numeric))`
- `vaga_tipo_contrato_check`: `CHECK (((tipo_contrato)::text = ANY ((ARRAY['CLT'::character varying, 'ESTAGIO'::character varying, 'APRENDIZ'::character varying, 'TEMPORARIO'::character varyi`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_vaga_au` (tg_vaga_au), `tg_vaga_bi` (tg_vaga_bi), `tg_vaga_bu` (tg_vaga_bu)

## ASS · Assistência Social (`ass`)

### `ass.abrangencia_unidade`



Linhas: 20

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_bairro` | smallint | PK FK | sim |  |  |
| `id_unidade` | smallint | FK | sim |  |  |

Chaves estrangeiras: `id_bairro` → `cid.bairro`; `id_unidade` → `ass.unidade_atendimento`

### `ass.atendimento`

Historico de atendimentos. ASS-RN05: linhas nunca sao alteradas ou apagadas

Linhas: 185.834

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_atendimento` | bigint | PK | sim |  |  |
| `id_beneficiario` | integer | FK | sim |  |  |
| `id_profissional` | integer | FK | sim |  |  |
| `id_unidade` | smallint | FK | sim |  |  |
| `id_tipo` | smallint | FK | sim |  |  |
| `id_programa` | smallint | FK |  |  |  |
| `data_hora` | timestamp with time zone |  | sim | `now()` |  |
| `descricao` | text |  | sim |  |  |
| `encaminhamento` | character varying(120) |  |  |  |  |

Chaves estrangeiras: `id_beneficiario` → `ass.beneficiario`; `id_profissional` → `ass.profissional`; `id_unidade` → `ass.unidade_atendimento`; `id_tipo` → `ass.tipo_atendimento`; `id_programa` → `ass.programa`

Restrições:
- `ck_atendimento_data`: `CHECK ((data_hora <= (now() + '1 day'::interval)))`

Gatilhos: `tg_atendimento_bud` (tg_atendimento_imutavel), `tg_auditoria` (tg_auditar)

### `ass.beneficiario`

Papel de beneficiario de um cidadao (ASS-RF02). ASS-RN01: FK obrigatoria para cid.cidadao

Linhas: 79.180

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_beneficiario` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK UK | sim |  |  |
| `nis` | character(11) | UK | sim |  |  |
| `pcd` | boolean |  | sim | `false` | Pessoa com deficiencia. Dado pessoal sensivel (LGPD art. 5, II): acesso restrito ao perfil de assistencia |
| `data_cadastro` | date |  | sim | `CURRENT_DATE` |  |
| `situacao` | character varying(8) |  | sim | `'ATIVO'::character varying` |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`

Restrições:
- `beneficiario_nis_check`: `CHECK ((nis ~ '^\d{11}$'::text))`
- `beneficiario_nis_key`: `UNIQUE (nis)`
- `beneficiario_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'INATIVO'::character varying])::text[])))`
- `uq_beneficiario_cidadao`: `UNIQUE (id_cidadao)`

Gatilhos: `tg_auditoria` (tg_auditar)

### `ass.beneficio_concedido`



Linhas: 83.219

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_beneficio` | integer | PK | sim |  |  |
| `id_beneficiario` | integer | FK | sim |  |  |
| `id_programa` | smallint | FK | sim |  |  |
| `data_concessao` | date |  | sim | `CURRENT_DATE` |  |
| `data_encerramento` | date |  |  |  |  |
| `situacao` | character varying(9) |  | sim | `'ATIVO'::character varying` |  |
| `valor_mensal` | numeric(10,2) |  | sim |  |  |
| `motivo_encerramento` | character varying(120) |  |  |  |  |

Chaves estrangeiras: `id_beneficiario` → `ass.beneficiario`; `id_programa` → `ass.programa`

Restrições:
- `beneficio_concedido_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'SUSPENSO'::character varying, 'ENCERRADO'::character varying])::text[])))`
- `beneficio_concedido_valor_mensal_check`: `CHECK ((valor_mensal >= (0)::numeric))`
- `ck_beneficio_datas`: `CHECK (((data_encerramento IS NULL) OR (data_encerramento >= data_concessao)))`
- `ck_beneficio_encerramento`: `CHECK ((((situacao)::text = 'ENCERRADO'::text) = (data_encerramento IS NOT NULL)))`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_beneficio_bi` (tg_beneficio_bi)

### `ass.criterio_elegibilidade`

Criterios de cada programa (ASS-RN02). Todos precisam ser atendidos (conjuncao)

Linhas: 12

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_programa` | smallint | PK FK | sim |  |  |
| `tipo_criterio` | character varying(24) | PK FK | sim |  |  |
| `valor` | numeric(10,2) |  |  |  |  |

Chaves estrangeiras: `id_programa` → `ass.programa`; `tipo_criterio` → `ass.tipo_criterio`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_criterio_biu` (tg_criterio_valor), `tg_criterio_minimo` (tg_programa_exige_criterio)

### `ass.familia`

Nucleo familiar (ASS-RF01). O endereco da familia e o endereco vigente do responsavel em cid

Linhas: 57.342

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_familia` | integer | PK | sim |  |  |
| `codigo_familiar` | character(11) | UK | sim |  |  |
| `data_cadastro` | date |  | sim | `CURRENT_DATE` |  |
| `data_atualizacao` | date |  | sim | `CURRENT_DATE` |  |
| `situacao` | character varying(8) |  | sim | `'ATIVA'::character varying` |  |

Restrições:
- `ck_familia_datas`: `CHECK ((data_atualizacao >= data_cadastro))`
- `familia_codigo_familiar_check`: `CHECK ((codigo_familiar ~ '^\d{11}$'::text))`
- `familia_codigo_familiar_key`: `UNIQUE (codigo_familiar)`
- `familia_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVA'::character varying, 'INATIVA'::character varying])::text[])))`

Gatilhos: `tg_auditoria` (tg_auditar)

### `ass.familia_membro`

Composicao familiar com vigencia. renda_mensal = renda declarada do integrante neste cadastro familiar

Linhas: 163.189

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_familia` | integer | PK FK | sim |  |  |
| `id_cidadao` | integer | PK FK | sim |  |  |
| `data_entrada` | date | PK | sim | `CURRENT_DATE` |  |
| `data_saida` | date |  |  |  |  |
| `parentesco` | character varying(12) |  | sim |  |  |
| `renda_mensal` | numeric(10,2) |  | sim | `0` |  |

Chaves estrangeiras: `id_familia` → `ass.familia`; `id_cidadao` → `cid.cidadao`

Restrições:
- `ck_membro_datas`: `CHECK (((data_saida IS NULL) OR (data_saida >= data_entrada)))`
- `familia_membro_parentesco_check`: `CHECK (((parentesco)::text = ANY ((ARRAY['RESPONSAVEL'::character varying, 'CONJUGE'::character varying, 'FILHO'::character varying, 'PAI_MAE'::character varyin`
- `familia_membro_renda_mensal_check`: `CHECK ((renda_mensal >= (0)::numeric))`

Gatilhos: `tg_auditoria` (tg_auditar)

### `ass.profissional`



Linhas: 120

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_profissional` | integer | PK | sim |  |  |
| `id_cidadao` | integer | FK UK | sim |  |  |
| `cargo` | character varying(20) |  | sim |  |  |
| `registro_profissional` | character varying(20) |  |  |  |  |
| `situacao` | character varying(8) |  | sim | `'ATIVO'::character varying` |  |

Chaves estrangeiras: `id_cidadao` → `cid.cidadao`

Restrições:
- `profissional_cargo_check`: `CHECK (((cargo)::text = ANY ((ARRAY['ASSISTENTE_SOCIAL'::character varying, 'PSICOLOGO'::character varying, 'EDUCADOR_SOCIAL'::character varying])::text[])))`
- `profissional_situacao_check`: `CHECK (((situacao)::text = ANY ((ARRAY['ATIVO'::character varying, 'INATIVO'::character varying])::text[])))`
- `uq_profissional_cidadao`: `UNIQUE (id_cidadao)`

### `ass.programa`



Linhas: 6

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_programa` | smallint | PK | sim |  |  |
| `codigo` | character varying(12) | UK | sim |  |  |
| `nome` | character varying(80) | UK | sim |  |  |
| `esfera` | character varying(9) |  | sim |  |  |
| `base_legal` | character varying(120) |  |  |  |  |
| `valor_referencia` | numeric(10,2) |  |  |  |  |
| `data_inicio` | date |  | sim |  |  |
| `data_fim` | date |  |  |  |  |
| `ativo` | boolean |  | sim | `true` |  |

Restrições:
- `ck_programa_datas`: `CHECK (((data_fim IS NULL) OR (data_fim >= data_inicio)))`
- `programa_codigo_key`: `UNIQUE (codigo)`
- `programa_esfera_check`: `CHECK (((esfera)::text = ANY ((ARRAY['FEDERAL'::character varying, 'ESTADUAL'::character varying, 'MUNICIPAL'::character varying])::text[])))`
- `programa_nome_key`: `UNIQUE (nome)`
- `programa_valor_referencia_check`: `CHECK ((valor_referencia >= (0)::numeric))`

Gatilhos: `tg_auditoria` (tg_auditar), `tg_programa_criterio` (tg_programa_exige_criterio)

### `ass.tipo_atendimento`



Linhas: 8

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_tipo` | smallint | PK | sim |  |  |
| `nome` | character varying(50) | UK | sim |  |  |

Restrições:
- `tipo_atendimento_nome_key`: `UNIQUE (nome)`

### `ass.tipo_criterio`



Linhas: 7

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `codigo` | character varying(24) | PK | sim |  |  |
| `descricao` | character varying(160) |  | sim |  |  |
| `usa_valor` | boolean |  | sim |  |  |

### `ass.unidade_atendimento`



Linhas: 10

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_unidade` | smallint | PK | sim |  |  |
| `nome` | character varying(80) | UK | sim |  |  |
| `tipo` | character varying(5) |  | sim |  |  |
| `id_logradouro` | integer | FK | sim |  |  |
| `numero` | character varying(10) |  | sim |  |  |

Chaves estrangeiras: `id_logradouro` → `cid.logradouro`

Restrições:
- `unidade_atendimento_nome_key`: `UNIQUE (nome)`
- `unidade_atendimento_tipo_check`: `CHECK (((tipo)::text = ANY ((ARRAY['CRAS'::character varying, 'CREAS'::character varying])::text[])))`

## AUD · Auditoria (`aud`)

### `aud.log_auditoria`

Trilha de auditoria. Somente insercao: UPDATE e DELETE sao bloqueados por gatilho

Linhas: 0

| Coluna | Tipo | Chave | NN | Padrão | Descrição |
|---|---|---|---|---|---|
| `id_log` | bigint | PK | sim |  |  |
| `data_hora` | timestamp with time zone |  | sim | `clock_timestamp()` |  |
| `usuario_bd` | name |  | sim | `SESSION_USER` |  |
| `usuario_app` | text |  | sim | `aud.fn_usuario()` |  |
| `transacao` | bigint |  | sim | `txid_current()` |  |
| `operacao` | character(1) |  | sim |  |  |
| `esquema` | name |  | sim |  |  |
| `tabela` | name |  | sim |  |  |
| `chave` | text |  | sim |  |  |
| `dados_antes` | jsonb |  |  |  |  |
| `dados_depois` | jsonb |  |  |  |  |

Restrições:
- `log_auditoria_operacao_check`: `CHECK ((operacao = ANY (ARRAY['I'::bpchar, 'U'::bpchar, 'D'::bpchar])))`

Gatilhos: `tg_log_bud` (tg_log_imutavel), `tg_log_truncate` (tg_log_imutavel)
