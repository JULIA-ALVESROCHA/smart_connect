# Normalização

Aplicamos a mesma metodologia dos exercícios da disciplina (VENDA_CARRO, Exercício 1 e Exercício 2): partir de uma relação não normalizada, listar a chave e as dependências funcionais (DF), verificar 1FN, 2FN e 3FN e decompor quando uma forma é violada.

Ponto de partida realista: a situação descrita no slide "O Problema". Hoje cada secretaria mantém sua própria planilha, com os dados da pessoa copiados em cada uma. Abaixo, uma planilha por módulo.

Lembrete das formas normais:
- **1FN**: todo atributo é atômico; sem grupos repetitivos nem atributos multivalorados.
- **2FN**: 1FN e nenhum atributo não chave depende de **parte** de uma chave composta (dependência parcial).
- **3FN**: 2FN e nenhum atributo não chave depende de outro atributo não chave (dependência transitiva).

---

## 1. Módulo CID: planilha de cadastro

```
CADASTRO(cpf, nome, data_nascimento, sexo, nome_mae,
         {telefone(ddd, numero, tipo)},
         {endereco(cep, tipo_logradouro, nome_logradouro, numero, bairro, regiao, data_inicio, data_fim)})
```

**1FN: não.** `telefone` e `endereco` são grupos repetitivos (um cidadão tem vários telefones, CID-RN03, e vários endereços ao longo do tempo, CID-RN04). Além disso, cada um é composto.

Passando para 1FN, separa cada grupo e propaga a chave (como no Exercício 1):
- CIDADAO(<u>cpf</u>, nome, data_nascimento, sexo, nome_mae)
- TELEFONE(<u>cpf, ddd, numero</u>, tipo)
- ENDERECO(<u>cpf, data_inicio</u>, cep, tipo_logradouro, nome_logradouro, numero, bairro, regiao, data_fim)

**Dependências funcionais:**
1. cpf → {nome, data_nascimento, sexo, nome_mae}
2. {cpf, ddd, numero} → tipo
3. {cpf, data_inicio} → {cep, numero, data_fim}
4. cep → {tipo_logradouro, nome_logradouro, bairro}
5. bairro → regiao

**2FN.** CIDADAO tem chave simples: está em 2FN. TELEFONE: `tipo` depende da chave inteira (o mesmo número pode ser celular para um cidadão e recado para outro); está em 2FN. ENDERECO: os atributos dependem do par (cpf, data_inicio), não de cpf sozinho, porque a pessoa muda de endereço; está em 2FN.

**3FN: não**, em ENDERECO. Há duas transitivas:
- {cpf, data_inicio} → cep → {tipo_logradouro, nome_logradouro, bairro}
- cep → bairro → regiao

Decomposição em 3FN:
- REGIAO(<u>id_regiao</u>, nome)
- BAIRRO(<u>id_bairro</u>, nome, #id_regiao)
- LOGRADOURO(<u>id_logradouro</u>, cep, tipo, nome, #id_bairro)
- ENDERECO_CIDADAO(<u>id_endereco</u>, #id_cidadao, #id_logradouro, numero, complemento, data_inicio, data_fim)

O número da casa fica no endereço do cidadão: ele não é determinado pelo CEP.

**Chave substituta.** No modelo físico, `id_cidadao` substitui o CPF como chave primária. O CPF continua chave candidata (`UNIQUE`). Motivo: se um CPF fosse digitado errado e corrigido, a chave natural obrigaria a atualizar todas as tabelas de todos os módulos. A dependência funcional cpf ↔ id_cidadao é de mão dupla, então a normalização não muda.

---

## 2. Módulo EDU: planilha da secretaria

```
MATRICULA_PLANILHA(cpf_aluno, nome_aluno, data_nasc_aluno, ra, cod_inep, nome_escola, bairro_escola,
                   cod_disciplina, nome_disciplina, componente, area_conhecimento, ano_escolar, carga_horaria,
                   ano_letivo, situacao_matricula, nota_final, frequencia,
                   registro_professor, nome_professor, formacao_professor)
```

**Chave primária:** {ra, cod_disciplina, ano_letivo}. Um aluno cursa várias disciplinas e pode repetir a mesma disciplina em outro ano (EDU-RN03 só proíbe no mesmo período).

**1FN: sim**, desde que cada disciplina cursada seja uma linha. Se a planilha original tivesse a coluna "disciplinas: MAT, LPO, CIE", seria multivalorada e a regra seria a mesma do Exercício 1.

**Dependências funcionais:**
1. {ra, cod_disciplina, ano_letivo} → {situacao_matricula, nota_final, frequencia}
2. ra → {cpf_aluno, cod_inep}
3. cpf_aluno → {nome_aluno, data_nasc_aluno}
4. cod_inep → {nome_escola, bairro_escola}
5. cod_disciplina → {nome_disciplina, componente, ano_escolar, carga_horaria}
6. componente → area_conhecimento
7. {cod_inep, cod_disciplina, ano_letivo} → registro_professor (na organização da escola)
8. registro_professor → {nome_professor, formacao_professor}

**2FN: não.** Dependências parciais:
- ra (parte da chave) → cpf_aluno, cod_inep, e por transitividade nome, nascimento, escola.
- cod_disciplina (parte da chave) → nome_disciplina, componente, ano_escolar, carga_horaria.

Decompondo as parciais:
- ALUNO(<u>ra</u>, cpf_aluno, cod_inep)
- DISCIPLINA(<u>cod_disciplina</u>, nome_disciplina, componente, area_conhecimento, ano_escolar, carga_horaria)
- MATRICULA(<u>ra, cod_disciplina, ano_letivo</u>, situacao, nota_final, frequencia)

**3FN: não.** Transitivas que sobraram:
- ra → cpf_aluno → {nome_aluno, data_nasc_aluno}: os dados pessoais saem do módulo e vão para o CID. Este é o ponto central do projeto.
- ra → cod_inep → {nome_escola, bairro_escola}: vira ESCOLA.
- cod_disciplina → componente → area_conhecimento: vira COMPONENTE_CURRICULAR e AREA_CONHECIMENTO.
- O professor dependia de {escola, disciplina, ano}, que não é a chave da matrícula: vira ATRIBUICAO_DOCENTE, e os dados do professor vão para PROFESSOR (e os pessoais para o CID).

Resultado final em 3FN:
- CIDADAO(<u>id_cidadao</u>, cpf, nome, data_nascimento, …) (módulo CID)
- ESCOLA(<u>id_escola</u>, cod_inep, nome, #id_logradouro, …)
- AREA_CONHECIMENTO(<u>id_area</u>, nome)
- COMPONENTE_CURRICULAR(<u>id_componente</u>, sigla, nome, #id_area)
- DISCIPLINA(<u>id_disciplina</u>, codigo, nome, #id_componente, ano_escolar, carga_horaria)
- PERIODO_LETIVO(<u>id_periodo</u>, ano, data_inicio, data_fim, situacao)
- ALUNO(<u>id_aluno</u>, #id_cidadao, #id_escola, ra, ano_escolar, turno, …)
- PROFESSOR(<u>id_professor</u>, #id_cidadao, registro_funcional, formacao, titulacao, …)
- ATRIBUICAO_DOCENTE(<u>#id_escola, #id_disciplina, #id_periodo, #id_professor</u>)
- MATRICULA(<u>id_matricula</u>, #id_aluno, #id_disciplina, #id_periodo, situacao, nota_final, frequencia_pct) com {id_aluno, id_disciplina, id_periodo} UNIQUE

MATRICULA e ATRIBUICAO_DOCENTE representam os relacionamentos N:N, como ATENDE no Exercício 1. ATRIBUICAO_DOCENTE é toda chave: está trivialmente em 3FN. Em MATRICULA a chave substituta `id_matricula` não muda nada: a chave natural continua garantida pela UNIQUE.

---

## 3. Módulo EMP: planilha do posto de emprego

```
CANDIDATURA_PLANILHA(cnpj, razao_social, cnae, descricao_cnae, setor,
                     cod_vaga, titulo_vaga, cbo, titulo_cbo, salario, status_vaga,
                     cpf_candidato, nome_candidato, escolaridade,
                     data_candidatura, status_candidatura,
                     {historico(status, data_hora)})
```

**Chave:** {cod_vaga, cpf_candidato, data_candidatura}. Um candidato pode tentar a mesma vaga de novo depois de recusado (EMP-RN03 só proíbe enquanto a anterior estiver ativa), então o par vaga e candidato sozinho não identifica a linha.

**1FN: não.** `historico` é grupo repetitivo. Vira CANDIDATURA_HISTORICO(<u>candidatura, data_hora</u>, status_anterior, status_novo).

**Dependências funcionais:**
1. {cod_vaga, cpf_candidato, data_candidatura} → status_candidatura
2. cod_vaga → {cnpj, titulo_vaga, cbo, salario, status_vaga}
3. cnpj → {razao_social, cnae}
4. cnae → descricao_cnae → (grupo → divisão →) setor
5. cbo → titulo_cbo
6. cpf_candidato → {nome_candidato, escolaridade}

**2FN: não.** Parciais: tudo da vaga depende só de cod_vaga; tudo do candidato depende só de cpf_candidato.

**3FN: não.** Transitivas: cod_vaga → cnpj → razao_social; cnpj → cnae → descrição e setor; cod_vaga → cbo → titulo_cbo; e de novo os dados pessoais do candidato.

Resultado final em 3FN:
- CNAE_SECAO, CNAE_DIVISAO, CNAE_GRUPO, CNAE_CLASSE: cada nível da hierarquia do IBGE na sua tabela (a cadeia classe → grupo → divisão → seção são transitivas em cascata).
- CBO_OCUPACAO(<u>cod_cbo</u>, titulo)
- EMPRESA(<u>id_empresa</u>, cnpj, razao_social, #cod_cnae_classe, …)
- VAGA(<u>id_vaga</u>, #id_empresa, #cod_cbo, #id_area, titulo, salario, #status, …)
- CANDIDATO(<u>id_candidato</u>, #id_cidadao, #id_escolaridade, …)
- CANDIDATURA(<u>id_candidatura</u>, #id_candidato, #id_vaga, data_candidatura, #status, data_status)
- CANDIDATURA_HISTORICO(<u>id_historico</u>, #id_candidatura, #status_anterior, #status_novo, data_hora, usuario, observacao)
- STATUS_CANDIDATURA(<u>codigo</u>, descricao, ativa): a propriedade "ativa" depende do status, não da candidatura. Se ficasse na candidatura seria transitiva.

**Decisão consciente:** CANDIDATURA guarda `status` atual, que também pode ser obtido do último registro do histórico. É redundância controlada: a consulta mais comum (candidaturas em andamento de uma vaga) não precisa varrer o histórico. O risco de divergência é eliminado porque a única forma de mudar o status é pela tabela de candidatura, e o gatilho grava o histórico na mesma transação. A auditoria de conformidade confere que os dois nunca divergem (zero violações).

---

## 4. Módulo ASS: ficha do CRAS

```
FICHA_FAMILIA(codigo_familiar, endereco_familia, bairro, regiao,
              {integrante(cpf, nome, data_nasc, parentesco, renda)},
              nis_beneficiario, pcd,
              {beneficio(cod_programa, nome_programa, criterio_renda, criterio_idade, valor, situacao)},
              {atendimento(data, tipo, unidade, profissional, descricao)})
```

**1FN: não.** Três grupos repetitivos (integrantes, benefícios, atendimentos). E `criterio_renda`, `criterio_idade` são uma lista de critérios espalhada em colunas: se surgir um programa com critério novo, é preciso mudar a estrutura. Tratamos os critérios também como grupo repetitivo.

**Dependências funcionais (após separar os grupos):**
1. codigo_familiar → {situação, data_cadastro}
2. {codigo_familiar, cpf, data_entrada} → {parentesco, renda, data_saida}
3. cpf → {nome, data_nasc} (CID)
4. nis → {cpf, pcd}
5. cod_programa → {nome_programa, esfera, base_legal, valor_referencia}
6. {cod_programa, tipo_criterio} → valor_do_criterio
7. {nis, cod_programa, data_concessao} → {valor, situacao}
8. id_atendimento → {nis, data_hora, tipo, unidade, profissional, descricao}
9. bairro → regiao; bairro → unidade de referência (CRAS)

**2FN: não**, na linha do benefício: `nome_programa` e os critérios dependem só de `cod_programa`, parte da chave do benefício. Vira PROGRAMA e CRITERIO_ELEGIBILIDADE.

**3FN: não.** `endereco_familia → bairro → regiao` é transitiva e, pior, duplica o endereço que já está no CID. Removemos o endereço da família: o território vem do endereço vigente do responsável. `renda_per_capita` não é armazenada: é **derivada** (soma das rendas / integrantes), calculada na visão `ass.vw_familia_resumo`. Guardá-la criaria uma dependência de outros atributos que pode ficar desatualizada.

Resultado final em 3FN: FAMILIA, FAMILIA_MEMBRO, BENEFICIARIO, PROGRAMA, TIPO_CRITERIO, CRITERIO_ELEGIBILIDADE, BENEFICIO_CONCEDIDO, UNIDADE_ATENDIMENTO, ABRANGENCIA_UNIDADE, PROFISSIONAL, TIPO_ATENDIMENTO e ATENDIMENTO (ver `01_modelagem.md`).

---

## 5. Exemplo resolvido da apostila aplicado ao projeto

O padrão do exercício VENDA_CARRO aparece no nosso EMP:

| VENDA_CARRO | SmartCity Connect |
|---|---|
| {Num_carro, Num_vendedor} → Data_venda | {id_candidato, id_vaga, data_candidatura} → status |
| Num_vendedor → Comissão_porc (parcial) | id_vaga → salario, titulo (parcial) |
| Data_venda → Desconto_tempo (transitiva) | status → ativa (transitiva) |
| VENDEDOR(Num_vendedor, Comissão_porc) | VAGA(id_vaga, …) |
| DESCONTO(Data_venda, Desconto_tempo) | STATUS_CANDIDATURA(codigo, ativa) |

O padrão do Exercício 2 (ALUNO com departamento e orientador) aparece em EDU: aluno → escola → dados da escola, igual a nro_aluno → cod_depto → nome_depto.

## 6. Verificação no banco

Toda relação final tem chave primária, e todas as dependências não triviais partem de uma chave candidata (PK ou UNIQUE). Exceções deliberadas, todas documentadas:

| Redundância | Por quê | Como a integridade é garantida |
|---|---|---|
| `emp.candidatura.status` | desempenho da consulta mais frequente | gatilho grava histórico; auditoria confere 0 divergências |
| `rel.mv_painel_territorial` | painel pesado (1,2 s → 0,2 ms) | é cópia de leitura, atualizada por `REFRESH MATERIALIZED VIEW CONCURRENTLY` |

O estado do benefício (`situacao`) e as datas de encerramento são fatos registrados, não derivados, por isso não são redundância.
