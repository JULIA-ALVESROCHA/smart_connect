-- =====================================================================
-- SmartCity Connect | 10 - Seguranca: perfis, privilegio minimo, RLS
-- GER-RNF01 (autenticacao), GER-RNF02 (perfil por modulo e operacao),
-- CID-RN05, ASS-RNF01/02, EMP-RNF02, GER-RNF05 (LGPD)
-- =====================================================================
-- Perfis (NOLOGIN). Usuarios reais herdam um perfil.
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['sc_leitura_ref','sc_cadastro_cid','sc_secretaria_edu','sc_professor',
                           'sc_operador_emp','sc_empresa','sc_assistencia','sc_gestor_relatorios','sc_auditor','sc_admin'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END $$;

-- Extensoes (unaccent, pg_trgm) ficam em public: mantem USAGE, retira CREATE.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA ref, cid, edu, emp, ass, aud, rel FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA cid, edu, emp, ass, aud, rel FROM PUBLIC;

-- Referencia publica: leitura para todos os perfis.
GRANT USAGE ON SCHEMA ref TO sc_leitura_ref;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO sc_leitura_ref;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ref TO sc_leitura_ref;
GRANT sc_leitura_ref TO sc_cadastro_cid, sc_secretaria_edu, sc_professor, sc_operador_emp, sc_empresa,
                        sc_assistencia, sc_gestor_relatorios, sc_auditor;

-- Todos os modulos localizam o cidadao pela funcao de dados minimos, nao pela tabela.
GRANT USAGE ON SCHEMA cid TO sc_secretaria_edu, sc_professor, sc_operador_emp, sc_empresa, sc_assistencia, sc_gestor_relatorios;
GRANT EXECUTE ON FUNCTION cid.fn_localizar_cidadao(text) TO sc_secretaria_edu, sc_operador_emp, sc_assistencia;
GRANT SELECT ON cid.vw_cidadao_basico, cid.regiao, cid.bairro TO sc_secretaria_edu, sc_professor, sc_operador_emp, sc_assistencia, sc_gestor_relatorios;

-- CID: operador de cadastro (CID-RN05: somente perfil autorizado altera dados pessoais).
GRANT USAGE ON SCHEMA cid TO sc_cadastro_cid;
GRANT SELECT, INSERT, UPDATE ON cid.cidadao, cid.telefone TO sc_cadastro_cid;
GRANT SELECT, INSERT ON cid.endereco_cidadao TO sc_cadastro_cid;
GRANT UPDATE (data_fim) ON cid.endereco_cidadao TO sc_cadastro_cid;
GRANT DELETE ON cid.telefone TO sc_cadastro_cid;
GRANT SELECT ON cid.logradouro, cid.bairro, cid.regiao, cid.vw_endereco_vigente, cid.vw_cidadao_basico TO sc_cadastro_cid;
GRANT EXECUTE ON FUNCTION cid.fn_cadastrar_cidadao(text,text,date,text,text,integer,text,text,text,text,integer),
                          cid.fn_alterar_endereco(integer,integer,text,text,date),
                          cid.fn_pesquisar_cidadao(text,integer), cid.fn_localizar_cidadao(text) TO sc_cadastro_cid;
-- A assistencia precisa do bairro vigente para ASS-RF08.
GRANT SELECT ON cid.vw_endereco_vigente, cid.logradouro TO sc_assistencia;

-- EDU
GRANT USAGE ON SCHEMA edu TO sc_secretaria_edu, sc_professor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA edu TO sc_secretaria_edu;
GRANT EXECUTE ON FUNCTION edu.fn_matricular(integer,text,integer) TO sc_secretaria_edu;
-- Professor: somente consulta (ator "Professor": acesso de consulta as turmas).
GRANT SELECT ON edu.vw_alunos_disciplina, edu.vw_matriculas_aluno, edu.disciplina, edu.escola, edu.periodo_letivo TO sc_professor;

-- EMP
GRANT USAGE ON SCHEMA emp TO sc_operador_emp, sc_empresa;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA emp TO sc_operador_emp;
REVOKE UPDATE, INSERT ON emp.candidatura_historico FROM sc_operador_emp;
GRANT EXECUTE ON FUNCTION emp.fn_candidatar(integer,integer), emp.fn_atualizar_candidatura(integer,text,text) TO sc_operador_emp;
-- Empresa: publica vagas e acompanha candidatos, sem ver dados de outras empresas (RLS abaixo).
GRANT SELECT ON emp.vw_vagas_abertas, emp.area_profissional, emp.status_vaga, emp.status_candidatura TO sc_empresa;
GRANT SELECT, INSERT ON emp.vaga TO sc_empresa;
GRANT UPDATE (status, descricao, salario) ON emp.vaga TO sc_empresa;
GRANT SELECT ON emp.candidatura, emp.candidato TO sc_empresa;
GRANT UPDATE (status) ON emp.candidatura TO sc_empresa;
GRANT EXECUTE ON FUNCTION emp.fn_atualizar_candidatura(integer,text,text) TO sc_empresa;

-- ASS: dados sensiveis (ASS-RNF01/02). Somente o perfil de assistencia.
GRANT USAGE ON SCHEMA ass TO sc_assistencia;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ass TO sc_assistencia;
REVOKE UPDATE ON ass.atendimento FROM sc_assistencia;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ass TO sc_assistencia;

-- Relatorios: so o esquema rel (agregados, sem dados pessoais identificaveis).
GRANT USAGE ON SCHEMA rel TO sc_gestor_relatorios;
ALTER DEFAULT PRIVILEGES IN SCHEMA rel GRANT SELECT ON TABLES TO sc_gestor_relatorios;

-- Auditor: le a trilha, nada mais.
GRANT USAGE ON SCHEMA aud TO sc_auditor;
GRANT SELECT ON aud.log_auditoria TO sc_auditor;
GRANT EXECUTE ON FUNCTION aud.fn_historico(text,text,text) TO sc_auditor;

-- Sequencias para os perfis que inserem.
GRANT USAGE ON ALL SEQUENCES IN SCHEMA cid TO sc_cadastro_cid;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA edu TO sc_secretaria_edu;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA emp TO sc_operador_emp, sc_empresa;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ass TO sc_assistencia;

-- Admin: dono funcional, sem superusuario.
GRANT ALL ON ALL TABLES IN SCHEMA ref, cid, edu, emp, ass, rel TO sc_admin;
GRANT USAGE ON SCHEMA ref, cid, edu, emp, ass, aud, rel TO sc_admin;
GRANT SELECT ON aud.log_auditoria TO sc_admin;

-- ---------------------------------------------------------------------
-- Row Level Security: a empresa logada so enxerga as proprias vagas e candidaturas.
-- O vinculo usuario -> empresa fica em emp.usuario_empresa.
-- ---------------------------------------------------------------------
CREATE TABLE emp.usuario_empresa (
  usuario    name    PRIMARY KEY,
  id_empresa integer NOT NULL REFERENCES emp.empresa
);
GRANT SELECT ON emp.usuario_empresa TO sc_empresa;

CREATE FUNCTION emp.fn_empresa_do_usuario() RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = emp, pg_temp AS $$
  SELECT id_empresa FROM emp.usuario_empresa WHERE usuario = current_user
$$;
GRANT EXECUTE ON FUNCTION emp.fn_empresa_do_usuario() TO sc_empresa;

ALTER TABLE emp.vaga ENABLE ROW LEVEL SECURITY;
ALTER TABLE emp.candidatura ENABLE ROW LEVEL SECURITY;
CREATE POLICY pl_vaga_interno ON emp.vaga TO sc_operador_emp, sc_admin USING (true) WITH CHECK (true);
CREATE POLICY pl_vaga_empresa ON emp.vaga TO sc_empresa
  USING (id_empresa = emp.fn_empresa_do_usuario()) WITH CHECK (id_empresa = emp.fn_empresa_do_usuario());
CREATE POLICY pl_cand_interno ON emp.candidatura TO sc_operador_emp, sc_admin USING (true) WITH CHECK (true);
CREATE POLICY pl_cand_empresa ON emp.candidatura TO sc_empresa
  USING (id_vaga IN (SELECT id_vaga FROM emp.vaga WHERE id_empresa = emp.fn_empresa_do_usuario()));

-- ---------------------------------------------------------------------
-- Usuarios de demonstracao (senha = nome; troque em producao). SCRAM-SHA-256.
-- ---------------------------------------------------------------------
SET password_encryption = 'scram-sha-256';
DO $$
DECLARE u text[];
BEGIN
  FOREACH u SLICE 1 IN ARRAY ARRAY[['ana_cadastro','sc_cadastro_cid'],['bruno_escola','sc_secretaria_edu'],
      ['carla_professora','sc_professor'],['diego_emprego','sc_operador_emp'],['empresa_demo','sc_empresa'],
      ['elisa_cras','sc_assistencia'],['fabio_gestor','sc_gestor_relatorios'],['gabi_auditora','sc_auditor']] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = u[1]) THEN
      EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L IN ROLE %I CONNECTION LIMIT 5', u[1], u[1], u[2]);
    END IF;
  END LOOP;
END $$;
INSERT INTO emp.usuario_empresa VALUES ('empresa_demo', (SELECT min(id_empresa) FROM emp.vaga WHERE status = 'ABERTA'));
