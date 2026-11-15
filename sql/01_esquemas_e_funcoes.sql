-- =====================================================================
-- SmartCity Connect | 01 - Extensoes, esquemas e funcoes utilitarias
-- PostgreSQL 16
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- restricao de exclusao no historico de enderecos
CREATE EXTENSION IF NOT EXISTS pg_trgm;     -- busca de cidadao por nome aproximado
CREATE EXTENSION IF NOT EXISTS unaccent;    -- busca sem acento

-- Um esquema por modulo: fronteira clara de responsabilidade e de permissao.
CREATE SCHEMA ref;  -- tabelas de referencia vindas de dados publicos (IBGE, CNAE, CBO)
CREATE SCHEMA cid;  -- Cadastro de Cidadaos (base cadastral unica)
CREATE SCHEMA edu;  -- Gestao da Educacao
CREATE SCHEMA emp;  -- Emprego e Desenvolvimento Economico
CREATE SCHEMA ass;  -- Assistencia Social
CREATE SCHEMA aud;  -- Trilha de auditoria
CREATE SCHEMA rel;  -- Visoes integradas, relatorios e indicadores do dashboard

COMMENT ON SCHEMA ref IS 'Tabelas de referencia carregadas de dados publicos oficiais';
COMMENT ON SCHEMA cid IS 'Modulo CID: base cadastral unica de cidadaos';
COMMENT ON SCHEMA edu IS 'Modulo EDU: escolas, alunos, professores, disciplinas e matriculas';
COMMENT ON SCHEMA emp IS 'Modulo EMP: empresas, vagas, candidatos e candidaturas';
COMMENT ON SCHEMA ass IS 'Modulo ASS: familias, beneficiarios, programas e atendimentos';
COMMENT ON SCHEMA aud IS 'Trilha de auditoria (GER-RNF03)';
COMMENT ON SCHEMA rel IS 'Visoes integradas e indicadores';

-- ---------------------------------------------------------------------
-- Validacao de CPF (digitos verificadores, modulo 11)
-- ---------------------------------------------------------------------
CREATE FUNCTION ref.fn_cpf_valido(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE s1 int := 0; s2 int := 0; d int; i int;
BEGIN
  IF p !~ '^\d{11}$' OR p ~ '^(\d)\1{10}$' THEN RETURN false; END IF;
  FOR i IN 1..9 LOOP
    d := substr(p, i, 1)::int;
    s1 := s1 + d * (11 - i);
    s2 := s2 + d * (12 - i);
  END LOOP;
  d := (s1 * 10) % 11; IF d = 10 THEN d := 0; END IF;
  IF d <> substr(p, 10, 1)::int THEN RETURN false; END IF;
  s2 := s2 + d * 2;
  d := (s2 * 10) % 11; IF d = 10 THEN d := 0; END IF;
  RETURN d = substr(p, 11, 1)::int;
END $$;

-- ---------------------------------------------------------------------
-- Validacao de CNPJ numerico (14 digitos, modulo 11)
-- ---------------------------------------------------------------------
CREATE FUNCTION ref.fn_cnpj_valido(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE AS $$
DECLARE
  w1 int[] := ARRAY[5,4,3,2,9,8,7,6,5,4,3,2];
  w2 int[] := ARRAY[6,5,4,3,2,9,8,7,6,5,4,3,2];
  s int := 0; d1 int; d2 int; i int;
BEGIN
  IF p !~ '^\d{14}$' OR p ~ '^(\d)\1{13}$' THEN RETURN false; END IF;
  FOR i IN 1..12 LOOP s := s + substr(p, i, 1)::int * w1[i]; END LOOP;
  d1 := 11 - (s % 11); IF d1 >= 10 THEN d1 := 0; END IF;
  IF d1 <> substr(p, 13, 1)::int THEN RETURN false; END IF;
  s := 0;
  FOR i IN 1..13 LOOP s := s + substr(p, i, 1)::int * w2[i]; END LOOP;
  d2 := 11 - (s % 11); IF d2 >= 10 THEN d2 := 0; END IF;
  RETURN d2 = substr(p, 14, 1)::int;
END $$;

-- Dominios: a regra de formato vive em um unico lugar e vale para toda coluna que a usa.
CREATE DOMAIN ref.cpf  AS char(11) CHECK (ref.fn_cpf_valido(VALUE));
CREATE DOMAIN ref.cnpj AS char(14) CHECK (ref.fn_cnpj_valido(VALUE));
CREATE DOMAIN ref.cep  AS char(8)  CHECK (VALUE ~ '^\d{8}$');

-- Normalizacao de texto para busca: minusculas e sem acento. IMMUTABLE para poder ser indexada.
CREATE FUNCTION ref.fn_normalizar(p text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT lower(public.unaccent('public.unaccent'::regdictionary, p))
$$;

-- Usuario da aplicacao (quando informado via SET app.usuario) ou usuario do banco.
CREATE FUNCTION aud.fn_usuario() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('app.usuario', true), ''), session_user::text)
$$;

-- Mascara de CPF para perfis que nao precisam do numero completo (LGPD, minimizacao).
CREATE FUNCTION ref.fn_mascarar_cpf(p text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT '***.' || substr(p, 4, 3) || '.' || substr(p, 7, 3) || '-**'
$$;
