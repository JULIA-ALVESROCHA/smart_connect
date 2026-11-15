-- =====================================================================
-- SmartCity Connect | 08 - Carga de dados
-- Execute a partir da raiz do projeto:  psql -d smartcity -f sql/08_carga.sql
-- Ordem: referencia publica -> CID -> EDU -> EMP -> ASS
--
-- As restricoes (PK, FK, UNIQUE, CHECK, EXCLUDE) ficam LIGADAS durante a carga:
-- qualquer linha invalida aborta o script. Somente os gatilhos de usuario sao
-- desligados, porque validam operacoes do dia a dia (ex.: "a vaga esta aberta agora?")
-- e nao fazem sentido para dados historicos. O script 10 audita as regras depois.
-- =====================================================================
\set ON_ERROR_STOP on
\timing off
BEGIN;

-- ------------------------------------------------- dados publicos (ref)
\copy ref.uf (cod_uf, sigla, nome, regiao) FROM 'dados/referencia/uf.csv' CSV HEADER
\copy ref.municipio (cod_ibge, nome, cod_uf, latitude, longitude, ddd) FROM 'dados/referencia/municipio.csv' CSV HEADER
INSERT INTO ref.municipio (cod_ibge, nome, cod_uf, ddd, ficticio)
VALUES (3199901, 'Nova Esperança Digital', 31, '35', true);
\copy ref.cnae_secao FROM 'dados/referencia/cnae_secao.csv' CSV HEADER
\copy ref.cnae_divisao FROM 'dados/referencia/cnae_divisao.csv' CSV HEADER
\copy ref.cnae_grupo FROM 'dados/referencia/cnae_grupo.csv' CSV HEADER
\copy ref.cnae_classe FROM 'dados/referencia/cnae_classe.csv' CSV HEADER
\copy ref.cbo_ocupacao FROM 'dados/referencia/cbo_ocupacao.csv' CSV HEADER

-- ------------------------------------------------- desliga gatilhos de usuario
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT c.oid::regclass AS t FROM pg_trigger g JOIN pg_class c ON c.oid = g.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE NOT g.tgisinternal AND n.nspname IN ('cid','edu','emp','ass') LOOP
    EXECUTE format('ALTER TABLE %s DISABLE TRIGGER USER', r.t);
  END LOOP;
END $$;

-- ------------------------------------------------- CID
\copy cid.regiao FROM 'dados/gerados/cid_regiao.csv' CSV HEADER
\copy cid.bairro FROM 'dados/gerados/cid_bairro.csv' CSV HEADER
\copy cid.logradouro (id_logradouro, cep, tipo, nome, id_bairro) FROM 'dados/gerados/cid_logradouro.csv' CSV HEADER
\copy cid.cidadao (id_cidadao, cpf, nome, data_nascimento, sexo, nome_mae, cod_municipio_nascimento, email, situacao, data_cadastro, data_atualizacao) FROM 'dados/gerados/cid_cidadao.csv' CSV HEADER
\copy cid.telefone (id_cidadao, ddd, numero, tipo, principal) FROM 'dados/gerados/cid_telefone.csv' CSV HEADER
\copy cid.endereco_cidadao (id_cidadao, id_logradouro, numero, complemento, data_inicio, data_fim) FROM 'dados/gerados/cid_endereco_cidadao.csv' CSV HEADER

-- ------------------------------------------------- EDU
\copy edu.area_conhecimento FROM 'dados/gerados/edu_area_conhecimento.csv' CSV HEADER
\copy edu.componente_curricular FROM 'dados/gerados/edu_componente_curricular.csv' CSV HEADER
\copy edu.disciplina (id_disciplina, codigo, nome, id_componente, ano_escolar, carga_horaria) FROM 'dados/gerados/edu_disciplina.csv' CSV HEADER
\copy edu.periodo_letivo (id_periodo, ano, data_inicio, data_fim, situacao) FROM 'dados/gerados/edu_periodo_letivo.csv' CSV HEADER
\copy edu.escola (id_escola, cod_inep, nome, id_logradouro, numero, ano_inicial, ano_final, telefone, situacao) FROM 'dados/gerados/edu_escola.csv' CSV HEADER
\copy edu.aluno (id_aluno, id_cidadao, id_escola, ra, ano_escolar, turno, data_ingresso, situacao) FROM 'dados/gerados/edu_aluno.csv' CSV HEADER
\copy edu.professor (id_professor, id_cidadao, registro_funcional, formacao, titulacao, data_admissao, situacao) FROM 'dados/gerados/edu_professor.csv' CSV HEADER
\copy edu.atribuicao_docente (id_escola, id_disciplina, id_periodo, id_professor) FROM 'dados/gerados/edu_atribuicao_docente.csv' CSV HEADER
\copy edu.matricula (id_aluno, id_disciplina, id_periodo, data_matricula, situacao, nota_final, frequencia_pct) FROM 'dados/gerados/edu_matricula.csv' CSV HEADER

-- ------------------------------------------------- EMP
\copy emp.area_profissional FROM 'dados/gerados/emp_area_profissional.csv' CSV HEADER
\copy emp.empresa (id_empresa, cnpj, razao_social, nome_fantasia, cod_cnae_classe, porte, id_logradouro, numero, email, telefone, data_abertura, situacao, data_cadastro) FROM 'dados/gerados/emp_empresa.csv' CSV HEADER
\copy emp.candidato (id_candidato, id_cidadao, id_escolaridade, id_area_interesse, pretensao_salarial, resumo_profissional, data_cadastro, situacao) FROM 'dados/gerados/emp_candidato.csv' CSV HEADER
\copy emp.vaga (id_vaga, id_empresa, id_area, cod_cbo, titulo, descricao, tipo_contrato, salario, qtd_posicoes, id_escolaridade_minima, data_publicacao, data_encerramento, status) FROM 'dados/gerados/emp_vaga.csv' CSV HEADER
\copy emp.candidatura (id_candidatura, id_candidato, id_vaga, data_candidatura, status, data_status) FROM 'dados/gerados/emp_candidatura.csv' CSV HEADER
\copy emp.candidatura_historico (id_candidatura, status_anterior, status_novo, data_hora, usuario, observacao) FROM 'dados/gerados/emp_candidatura_historico.csv' CSV HEADER

-- ------------------------------------------------- ASS
\copy ass.programa (id_programa, codigo, nome, esfera, base_legal, valor_referencia, data_inicio, ativo) FROM 'dados/gerados/ass_programa.csv' CSV HEADER
\copy ass.criterio_elegibilidade (id_programa, tipo_criterio, valor) FROM 'dados/gerados/ass_criterio_elegibilidade.csv' CSV HEADER
\copy ass.unidade_atendimento FROM 'dados/gerados/ass_unidade_atendimento.csv' CSV HEADER
\copy ass.abrangencia_unidade FROM 'dados/gerados/ass_abrangencia_unidade.csv' CSV HEADER
\copy ass.tipo_atendimento FROM 'dados/gerados/ass_tipo_atendimento.csv' CSV HEADER
\copy ass.profissional (id_profissional, id_cidadao, cargo, registro_profissional, situacao) FROM 'dados/gerados/ass_profissional.csv' CSV HEADER
\copy ass.familia (id_familia, codigo_familiar, data_cadastro, data_atualizacao, situacao) FROM 'dados/gerados/ass_familia.csv' CSV HEADER
\copy ass.familia_membro (id_familia, id_cidadao, data_entrada, data_saida, parentesco, renda_mensal) FROM 'dados/gerados/ass_familia_membro.csv' CSV HEADER
\copy ass.beneficiario (id_beneficiario, id_cidadao, nis, pcd, data_cadastro, situacao) FROM 'dados/gerados/ass_beneficiario.csv' CSV HEADER
\copy ass.atendimento (id_beneficiario, id_profissional, id_unidade, id_tipo, id_programa, data_hora, descricao, encaminhamento) FROM 'dados/gerados/ass_atendimento.csv' CSV HEADER

-- Beneficios: o gerador apenas PROPOE. Quem decide a concessao e o banco, com a mesma
-- funcao de elegibilidade usada no dia a dia (ASS-RN04). Beneficios ja encerrados sao historico.
ANALYZE ass.familia_membro, ass.beneficiario, edu.aluno, emp.candidato, cid.cidadao;
CREATE TEMP TABLE beneficio_proposto (LIKE ass.beneficio_concedido INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE beneficio_proposto DROP COLUMN id_beneficio;
\copy beneficio_proposto (id_beneficiario, id_programa, data_concessao, data_encerramento, situacao, valor_mensal, motivo_encerramento) FROM 'dados/gerados/ass_beneficio_proposto.csv' CSV HEADER

INSERT INTO ass.beneficio_concedido (id_beneficiario, id_programa, data_concessao, data_encerramento, situacao, valor_mensal, motivo_encerramento)
SELECT id_beneficiario, id_programa, data_concessao, data_encerramento, situacao, valor_mensal, motivo_encerramento
  FROM beneficio_proposto p
 WHERE p.situacao = 'ENCERRADO' OR ass.fn_elegivel(p.id_beneficiario, p.id_programa)
 ORDER BY data_concessao;

SELECT (SELECT count(*) FROM beneficio_proposto WHERE situacao <> 'ENCERRADO') AS propostos_em_aberto,
       (SELECT count(*) FROM ass.beneficio_concedido WHERE situacao <> 'ENCERRADO') AS concedidos,
       (SELECT count(*) FROM beneficio_proposto WHERE situacao <> 'ENCERRADO')
     - (SELECT count(*) FROM ass.beneficio_concedido WHERE situacao <> 'ENCERRADO') AS negados_por_inelegibilidade;

-- ------------------------------------------------- religa gatilhos e ajusta sequencias
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT DISTINCT c.oid::regclass AS t FROM pg_trigger g JOIN pg_class c ON c.oid = g.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE NOT g.tgisinternal AND n.nspname IN ('cid','edu','emp','ass') LOOP
    EXECUTE format('ALTER TABLE %s ENABLE TRIGGER USER', r.t);
  END LOOP;
  FOR r IN SELECT format('%I.%I', table_schema, table_name) AS t, column_name AS c
             FROM information_schema.columns
            WHERE is_identity = 'YES' AND table_schema IN ('cid','edu','emp','ass') LOOP
    EXECUTE format('SELECT setval(pg_get_serial_sequence(%L, %L), coalesce((SELECT max(%I) FROM %s), 0) + 1, false)',
                   r.t, r.c, r.c, r.t);
  END LOOP;
END $$;
COMMIT;
