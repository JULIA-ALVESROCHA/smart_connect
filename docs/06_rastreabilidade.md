# Matriz de rastreabilidade: requisito → banco → teste

Continua a seção 8 do Levantamento de Requisitos. Para cada requisito: onde está implementado e qual evidência prova que funciona.

Evidências: **T** = `testes/01` (regras, 75 testes) · **S** = `testes/02` (segurança, 30) · **A** = `testes/03` (conformidade da carga, 29) · **D** = `testes/04` (desempenho) · **Q** = `sql/12_consultas.sql` · **O** = `sql/13_operacoes_exemplo.sql`.

## CID · Cadastro de Cidadãos

| Código | Implementação | Evidência |
|---|---|---|
| CID-RF01 | `cid.cidadao`; `cid.fn_cadastrar_cidadao` (UC01) | T, O passo 1 |
| CID-RF02 | `cid.cidadao`, `cid.vw_cidadao_basico`, `cid.fn_localizar_cidadao` | S, Q02 |
| CID-RF03 | UPDATE com privilégio do perfil `sc_cadastro_cid`; `data_atualizacao` por gatilho | S |
| CID-RF04 | `cid.telefone` (1:N) | T, Q04 |
| CID-RF05 | `cid.endereco_cidadao`, `cid.vw_endereco_vigente` | T, A |
| CID-RF06 | `cid.fn_alterar_endereco` (UC02); vigência `data_inicio`/`data_fim` | T, O passo 2, Q03 |
| CID-RF07 | `cid.fn_pesquisar_cidadao` (CPF ou nome sem acento); índice GIN trigramas | T, D, Q01 |
| CID-RN01 | `UNIQUE (cpf)` + domínio `ref.cpf` com dígito verificador | T (3 testes), A |
| CID-RN02 | `NOT NULL` + `CHECK` em nome, nascimento, sexo, nome da mãe | T (2 testes), A |
| CID-RN03 | `cid.telefone`; índice único parcial de telefone principal | T (2 testes) |
| CID-RN04 | gatilho `tg_endereco_bud`; índice único parcial de vigente; `EXCLUDE` de sobreposição | T (5 testes), A |
| CID-RN05 | grants por perfil; privilégio por coluna | S |
| CID-RNF01/02 | login SCRAM; perfis; visão com CPF mascarado | S |
| CID-RNF03 | PK, FK, CHECK; transações; backup verificado | A, `evidencias/07` |
| CID-RNF04 | 500 mil cidadãos; índices | D |

## EDU · Gestão da Educação

| Código | Implementação | Evidência |
|---|---|---|
| EDU-RF01 | `edu.escola` | A |
| EDU-RF02 | `edu.aluno` (papel do cidadão) | T, O passo 3 |
| EDU-RF03 | `edu.professor` | A |
| EDU-RF04 | `edu.disciplina`, `edu.componente_curricular` | T |
| EDU-RF05 | `edu.matricula`, `edu.fn_matricular` (UC03) | T, O passo 3 |
| EDU-RF06 | `edu.vw_matriculas_aluno` (UC04) | T, Q05 |
| EDU-RF07 | `edu.vw_alunos_disciplina`; índice `ix_matricula_disciplina_periodo` | T, D, Q06 |
| EDU-RF08 | `edu.atribuicao_docente` | T, A, Q06 |
| EDU-RN01 | `edu.aluno.id_escola NOT NULL` + FK | T, A |
| EDU-RN02 | FKs obrigatórias em `edu.matricula` | T (2 testes) |
| EDU-RN03 | `UNIQUE (id_aluno, id_disciplina, id_periodo)` | T (2 testes), A |
| EDU-RN04 | `UNIQUE (codigo)` | T |
| EDU-RN05 | N:N em `atribuicao_docente` | T, Q09 |
| EDU-RNF01/02 | perfis secretaria e professor (só consulta) | S |
| EDU-RNF03 | gatilho `tg_matricula_bi`: aluno ativo, período aberto, ano ofertado | T (3 testes), A (4 regras) |
| EDU-RNF04 | 200 escolas, 1 milhão de matrículas | D |

## EMP · Emprego e Desenvolvimento Econômico

| Código | Implementação | Evidência |
|---|---|---|
| EMP-RF01 | `emp.empresa` com CNPJ validado e CNAE do IBGE | T |
| EMP-RF02 | `emp.vaga` com CBO 2002; gatilho `tg_vaga_bi` | T |
| EMP-RF03 | `emp.candidato` (papel do cidadão) | O passo 7 |
| EMP-RF04 | `emp.candidatura`, `emp.fn_candidatar` (UC03) | T, O passo 7 |
| EMP-RF05 | `emp.transicao_vaga`; gatilhos `tg_vaga_bu`/`tg_vaga_au` | T (3 testes), A |
| EMP-RF06 | `emp.fn_atualizar_candidatura` (UC04) | T, O passo 7 |
| EMP-RF07 | `emp.vw_vagas_abertas`; `rel.r01`; índice parcial | T, D, Q10 |
| EMP-RF08 | `emp.vw_candidatos_por_vaga`; `rel.r03` | T, D, Q12 |
| EMP-RN01 | `id_empresa NOT NULL` + FK; gatilho impede troca de empresa | T (2 testes), A |
| EMP-RN02 | FKs obrigatórias; gatilho impede troca de vaga/candidato | T |
| EMP-RN03 | índice único parcial `uq_candidatura_ativa` | T (2 testes), A |
| EMP-RN04 | gatilho `tg_candidatura_bi` com `status_vaga.aceita_candidatura` | T, A (2 regras) |
| EMP-RN05 | FK para `status_candidatura`; `transicao_candidatura` | T (2 testes), A (2 regras) |
| EMP-RNF01/02 | perfis operador e empresa; RLS por empresa | S (6 testes) |
| EMP-RNF03 | índices; consultas abaixo de 1 ms | D |
| EMP-RNF04 | `emp.candidatura_historico` somente inserção | T (3 testes), A, Q14 |

## ASS · Assistência Social

| Código | Implementação | Evidência |
|---|---|---|
| ASS-RF01 | `ass.familia`, `ass.familia_membro` | O passo 4, A |
| ASS-RF02 | `ass.beneficiario` (papel do cidadão) | O passo 4 |
| ASS-RF03 | `ass.programa`, `ass.criterio_elegibilidade` | T |
| ASS-RF04 | `ass.beneficio_concedido`, `ass.fn_vincular_programa` (UC03) | T, O passo 5 |
| ASS-RF05 | `ass.atendimento`, `ass.fn_registrar_atendimento` (UC04) | T, O passo 6 |
| ASS-RF06 | `ass.vw_historico_atendimentos` | T, D, Q19 |
| ASS-RF07 | `rel.r05_familias_por_programa` | T, Q17 |
| ASS-RF08 | `rel.r06_atendimentos_por_regiao` | T, Q18 |
| ASS-RN01 | FK obrigatória para `cid.cidadao` | T (3 testes), A |
| ASS-RN02 | gatilho de restrição adiado; critério com valor obrigatório | T (3 testes), A |
| ASS-RN03 | `id_beneficiario` e `data_hora NOT NULL` | T (2 testes), A |
| ASS-RN04 | `ass.fn_avaliar_elegibilidade`; gatilho `tg_beneficio_bi`; cruza EDU e EMP | T (5 testes), A, O passo 5, Q20 |
| ASS-RN05 | gatilho `tg_atendimento_bud` | T (3 testes) |
| ASS-RNF01/02 | perfil exclusivo; PcD só na assistência | S (5 testes) |
| ASS-RNF03 | atendimento somente inserção | T |
| ASS-RNF04 | índice único de vínculo em aberto; programa ativo exigido | T |

## Requisitos transversais

| Código | Implementação | Evidência |
|---|---|---|
| GER-RNF01 | usuários com SCRAM-SHA-256 | S |
| GER-RNF02 | 9 perfis, grants por esquema, operação e coluna; RLS | S (30 testes) |
| GER-RNF03 | `aud.log_auditoria` em 20 tabelas; imutável | T (4 testes), O passo 9 |
| GER-RNF04 | históricos somente inserção (ver doc 05, seção 5) | T, A |
| GER-RNF05 | minimização, mascaramento, dados sintéticos | S, doc 05 |

## Exemplos de consulta dos slides do professor

| Slide | Exemplo | Onde |
|---|---|---|
| Emprego | Vagas abertas por área | `rel.r01`, Q10, dashboard |
| Emprego | Empresas que mais contratam | `rel.r02`, Q11, dashboard |
| Emprego | Candidatos por empresa | `rel.r03`, Q12, dashboard |
| Assistência | Benefícios concedidos | `rel.r04`, Q16, dashboard |
| Assistência | Famílias atendidas por programa | `rel.r05`, Q17, dashboard |
| Assistência | Atendimentos por região | `rel.r06`, Q18, dashboard |
| Cidadãos | Registro de milhares de cidadãos | 500 mil, D |
| Educação | Relacionamento aluno x disciplina | `edu.matricula`, doc 02 |
