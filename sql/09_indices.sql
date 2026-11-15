-- =====================================================================
-- SmartCity Connect | 09 - Indices secundarios
-- Criados depois da carga (mais rapido que manter o indice linha a linha).
-- PK e UNIQUE ja criaram seus indices. Aqui ficam: chaves estrangeiras usadas
-- em JOIN, filtros frequentes dos requisitos e indices parciais.
-- A justificativa medida de cada um esta em docs/04_consultas_e_desempenho.md
-- =====================================================================

-- CID ------------------------------------------------------------------
-- CID-RF07: busca por trecho do nome, sem acento. Trigramas permitem LIKE '%termo%'.
CREATE INDEX ix_cidadao_nome_trgm ON cid.cidadao USING gin (ref.fn_normalizar(nome) gin_trgm_ops);
CREATE INDEX ix_cidadao_nascimento ON cid.cidadao (data_nascimento);
CREATE INDEX ix_logradouro_bairro ON cid.logradouro (id_bairro);
-- Consultas por regiao: moradores atuais de um logradouro (so enderecos vigentes).
CREATE INDEX ix_endereco_vigente_logradouro ON cid.endereco_cidadao (id_logradouro) INCLUDE (id_cidadao) WHERE data_fim IS NULL;

-- EDU ------------------------------------------------------------------
CREATE INDEX ix_aluno_escola ON edu.aluno (id_escola) WHERE situacao = 'ATIVO';
-- EDU-RF07: alunos de uma disciplina em um periodo (a UNIQUE comeca por id_aluno e nao serve aqui).
CREATE INDEX ix_matricula_disciplina_periodo ON edu.matricula (id_disciplina, id_periodo);
CREATE INDEX ix_atribuicao_professor ON edu.atribuicao_docente (id_professor);

-- EMP ------------------------------------------------------------------
CREATE INDEX ix_empresa_cnae ON emp.empresa (cod_cnae_classe);
CREATE INDEX ix_vaga_empresa ON emp.vaga (id_empresa);
-- EMP-RF07, EMP-RNF03: vagas abertas por area. Parcial: indexa so as abertas (cerca de 10% da tabela).
CREATE INDEX ix_vaga_aberta_area ON emp.vaga (id_area, data_publicacao DESC) WHERE status = 'ABERTA';
-- EMP-RF08: candidatos de uma vaga; candidaturas de um candidato.
CREATE INDEX ix_candidatura_vaga ON emp.candidatura (id_vaga, status);
CREATE INDEX ix_candidatura_candidato ON emp.candidatura (id_candidato);
CREATE INDEX ix_historico_candidatura ON emp.candidatura_historico (id_candidatura, data_hora);

-- ASS ------------------------------------------------------------------
CREATE INDEX ix_beneficio_programa_ativo ON ass.beneficio_concedido (id_programa) INCLUDE (id_beneficiario, valor_mensal) WHERE situacao = 'ATIVO';
CREATE INDEX ix_beneficio_beneficiario ON ass.beneficio_concedido (id_beneficiario);
-- ASS-RF06: historico de um beneficiario, mais recente primeiro.
CREATE INDEX ix_atendimento_beneficiario ON ass.atendimento (id_beneficiario, data_hora DESC);
-- Relatorios por periodo: BRIN ocupa poucos kB porque a tabela cresce em ordem de data.
CREATE INDEX ix_atendimento_data_brin ON ass.atendimento USING brin (data_hora);
CREATE INDEX ix_atendimento_unidade ON ass.atendimento (id_unidade);

-- AUD ------------------------------------------------------------------
CREATE INDEX ix_log_registro ON aud.log_auditoria (esquema, tabela, chave);
CREATE INDEX ix_log_data_brin ON aud.log_auditoria USING brin (data_hora);

ANALYZE;
