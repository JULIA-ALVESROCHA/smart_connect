-- =====================================================================
-- SmartCity Connect | 07 - Trilha de auditoria (GER-RNF03)
-- Registra quem, quando, o que e os valores antes e depois de cada
-- INSERT, UPDATE e DELETE nas tabelas transacionais dos quatro modulos.
-- =====================================================================
CREATE TABLE aud.log_auditoria (
  id_log       bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  data_hora    timestamptz NOT NULL DEFAULT clock_timestamp(),
  usuario_bd   name        NOT NULL DEFAULT session_user,
  usuario_app  text        NOT NULL DEFAULT aud.fn_usuario(),
  transacao    bigint      NOT NULL DEFAULT txid_current(),
  operacao     char(1)     NOT NULL CHECK (operacao IN ('I','U','D')),
  esquema      name        NOT NULL,
  tabela       name        NOT NULL,
  chave        text        NOT NULL,
  dados_antes  jsonb,
  dados_depois jsonb
);
COMMENT ON TABLE aud.log_auditoria IS 'Trilha de auditoria. Somente insercao: UPDATE e DELETE sao bloqueados por gatilho';

-- Funcao generica. Os argumentos do gatilho sao as colunas da chave primaria.
CREATE FUNCTION aud.tg_auditar() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = aud, pg_temp AS $$
DECLARE
  v_antes  jsonb := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END;
  v_depois jsonb := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END;
  v_chave  text  := '';
  v_col    text;
BEGIN
  IF TG_OP = 'UPDATE' AND v_antes = v_depois THEN
    RETURN NULL;  -- UPDATE sem mudanca efetiva nao polui a trilha
  END IF;
  FOREACH v_col IN ARRAY TG_ARGV LOOP
    v_chave := v_chave || CASE WHEN v_chave = '' THEN '' ELSE ';' END
               || v_col || '=' || coalesce(coalesce(v_depois, v_antes) ->> v_col, '');
  END LOOP;
  INSERT INTO aud.log_auditoria (operacao, esquema, tabela, chave, dados_antes, dados_depois)
  VALUES (left(TG_OP, 1), TG_TABLE_SCHEMA, TG_TABLE_NAME, v_chave, v_antes, v_depois);
  RETURN NULL;
END $$;

CREATE FUNCTION aud.tg_log_imutavel() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'GER-RNF03: a trilha de auditoria nao pode ser alterada nem apagada' USING ERRCODE = 'SC901';
END $$;
CREATE TRIGGER tg_log_bud BEFORE UPDATE OR DELETE ON aud.log_auditoria
  FOR EACH ROW EXECUTE FUNCTION aud.tg_log_imutavel();
CREATE TRIGGER tg_log_truncate BEFORE TRUNCATE ON aud.log_auditoria
  FOR EACH STATEMENT EXECUTE FUNCTION aud.tg_log_imutavel();

-- Liga a auditoria em cada tabela transacional.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('cid','cidadao','id_cidadao'), ('cid','telefone','id_telefone'), ('cid','endereco_cidadao','id_endereco'),
    ('edu','escola','id_escola'), ('edu','disciplina','id_disciplina'), ('edu','aluno','id_aluno'),
    ('edu','professor','id_professor'), ('edu','matricula','id_matricula'),
    ('edu','atribuicao_docente','id_escola,id_disciplina,id_periodo,id_professor'),
    ('emp','empresa','id_empresa'), ('emp','vaga','id_vaga'), ('emp','candidato','id_candidato'),
    ('emp','candidatura','id_candidatura'),
    ('ass','familia','id_familia'), ('ass','familia_membro','id_familia,id_cidadao,data_entrada'),
    ('ass','beneficiario','id_beneficiario'), ('ass','programa','id_programa'),
    ('ass','criterio_elegibilidade','id_programa,tipo_criterio'),
    ('ass','beneficio_concedido','id_beneficio'), ('ass','atendimento','id_atendimento')
  ) AS t(esquema, tabela, chave)
  LOOP
    EXECUTE format(
      'CREATE TRIGGER tg_auditoria AFTER INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION aud.tg_auditar(%s)',
      r.esquema, r.tabela,
      (SELECT string_agg(quote_literal(c), ',') FROM unnest(string_to_array(r.chave, ',')) c));
  END LOOP;
END $$;

-- Consulta de apoio: historico de alteracoes de um registro.
CREATE FUNCTION aud.fn_historico(p_esquema text, p_tabela text, p_chave text)
RETURNS TABLE (data_hora timestamptz, usuario text, operacao char, campos_alterados jsonb)
LANGUAGE sql STABLE AS $$
  SELECT l.data_hora, l.usuario_app, l.operacao,
         CASE l.operacao
           WHEN 'U' THEN (SELECT jsonb_object_agg(d.key, jsonb_build_object('de', l.dados_antes -> d.key, 'para', d.value))
                            FROM jsonb_each(l.dados_depois) d
                           WHERE l.dados_antes -> d.key IS DISTINCT FROM d.value)
           WHEN 'I' THEN l.dados_depois
           ELSE l.dados_antes
         END
    FROM aud.log_auditoria l
   WHERE l.esquema = p_esquema AND l.tabela = p_tabela AND l.chave = p_chave
   ORDER BY l.id_log
$$;
