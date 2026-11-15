-- =====================================================================
-- SmartCity Connect | Testes automatizados de requisitos e regras de negocio
-- Execucao:  psql -d smartcity -f testes/01_testes_regras_de_negocio.sql
-- Tudo roda dentro de uma transacao desfeita no final (ROLLBACK): a base nao muda.
-- Cada teste positivo executa a operacao do caso de uso; cada teste negativo
-- tenta violar a regra e exige o erro esperado (SQLSTATE).
-- =====================================================================
\set ON_ERROR_STOP on
\pset footer off
BEGIN;
SET LOCAL app.usuario = 'teste_automatizado';
CREATE TEMP TABLE resultado (n serial, codigo text, teste text, esperado text, obtido text, ok boolean);

-- Executa um comando que deve FALHAR com o SQLSTATE indicado (savepoint implicito no bloco EXCEPTION).
CREATE FUNCTION pg_temp.deve_falhar(p_codigo text, p_teste text, p_sql text, p_sqlstate text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_estado text; v_msg text;
BEGIN
  BEGIN
    EXECUTE p_sql;
    INSERT INTO resultado (codigo, teste, esperado, obtido, ok) VALUES (p_codigo, p_teste, 'erro ' || p_sqlstate, 'executou sem erro', false);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_estado = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    INSERT INTO resultado (codigo, teste, esperado, obtido, ok)
    VALUES (p_codigo, p_teste, 'erro ' || p_sqlstate, v_estado || ': ' || left(v_msg, 90), v_estado = p_sqlstate);
  END;
END $$;

-- Verifica uma condicao booleana.
CREATE FUNCTION pg_temp.verificar(p_codigo text, p_teste text, p_condicao boolean, p_obtido text DEFAULT NULL) RETURNS void
LANGUAGE sql AS $$
  INSERT INTO resultado (codigo, teste, esperado, obtido, ok)
  VALUES (p_codigo, p_teste, 'verdadeiro', coalesce(p_obtido, p_condicao::text), coalesce(p_condicao, false))
$$;

-- Observacao: quando mais de uma camada protege a mesma regra, o teste espera o erro
-- da primeira camada que dispara (ex.: gatilho BEFORE roda antes do NOT NULL).
-- ============================================================ CID
DO $$
DECLARE v_id int; v_end int; v_logr int := (SELECT min(id_logradouro) FROM cid.logradouro);
        v_logr2 int := (SELECT max(id_logradouro) FROM cid.logradouro); v_cpf_existente text;
BEGIN
  -- CID-UC01 positivo (CPF valido 529.982.247-25 e exemplo classico de CPF valido)
  v_id := cid.fn_cadastrar_cidadao('52998224725','Teste da Silva','1990-05-10','F','Maria Teste da Silva', v_logr,'100',NULL,'35','999998888',3101607);
  PERFORM pg_temp.verificar('CID-RF01/UC01','Cadastrar cidadão com endereço e telefone', v_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM cid.endereco_cidadao WHERE id_cidadao = v_id AND data_fim IS NULL)
     AND EXISTS (SELECT 1 FROM cid.telefone WHERE id_cidadao = v_id AND principal), 'id ' || v_id);
  SELECT cpf INTO v_cpf_existente FROM cid.cidadao WHERE id_cidadao = 1;
  PERFORM pg_temp.deve_falhar('CID-RN01','CPF duplicado é recusado',
    format($q$INSERT INTO cid.cidadao (cpf,nome,data_nascimento,sexo,nome_mae) VALUES (%L,'Outro Nome','1980-01-01','M','Mae Qualquer')$q$, v_cpf_existente), '23505');
  PERFORM pg_temp.deve_falhar('CID-RN01','CPF com dígito verificador inválido é recusado',
    $q$INSERT INTO cid.cidadao (cpf,nome,data_nascimento,sexo,nome_mae) VALUES ('52998224724','Nome Teste','1980-01-01','M','Mae Qualquer')$q$, '23514');
  PERFORM pg_temp.deve_falhar('CID-RN01','CPF com dígitos repetidos é recusado',
    $q$INSERT INTO cid.cidadao (cpf,nome,data_nascimento,sexo,nome_mae) VALUES ('11111111111','Nome Teste','1980-01-01','M','Mae Qualquer')$q$, '23514');
  PERFORM pg_temp.deve_falhar('CID-RN02','Cadastro sem nome da mãe é recusado',
    $q$INSERT INTO cid.cidadao (cpf,nome,data_nascimento,sexo) VALUES ('11144477735','Nome Teste','1980-01-01','M')$q$, '23502');
  PERFORM pg_temp.deve_falhar('CID-RN02','Data de nascimento futura é recusada',
    $q$INSERT INTO cid.cidadao (cpf,nome,data_nascimento,sexo,nome_mae) VALUES ('11144477735','Nome Teste', CURRENT_DATE + 1,'M','Mae Qualquer')$q$, '23514');
  -- CID-RN03
  INSERT INTO cid.telefone (id_cidadao, ddd, numero, tipo) VALUES (v_id,'35','33221100','FIXO');
  PERFORM pg_temp.verificar('CID-RN03','Cidadão com mais de um telefone', (SELECT count(*) FROM cid.telefone WHERE id_cidadao = v_id) = 2);
  PERFORM pg_temp.deve_falhar('CID-RN03','Dois telefones principais para o mesmo cidadão é recusado',
    format($q$INSERT INTO cid.telefone (id_cidadao, ddd, numero, tipo, principal) VALUES (%s,'35','988887777','CELULAR',true)$q$, v_id), '23505');
  -- CID-UC02, CID-RN04
  v_end := cid.fn_alterar_endereco(v_id, v_logr2, '55', 'Apto 3', CURRENT_DATE);
  PERFORM pg_temp.verificar('CID-RF06/UC02','Alterar endereço preserva o anterior no histórico',
    (SELECT count(*) FROM cid.endereco_cidadao WHERE id_cidadao = v_id) = 2
    AND (SELECT count(*) FROM cid.endereco_cidadao WHERE id_cidadao = v_id AND data_fim IS NULL) = 1
    AND (SELECT id_logradouro FROM cid.endereco_cidadao WHERE id_cidadao = v_id AND data_fim IS NULL) = v_logr2);
  PERFORM pg_temp.deve_falhar('CID-RN04','DELETE de endereço do histórico é bloqueado',
    format('DELETE FROM cid.endereco_cidadao WHERE id_cidadao = %s', v_id), 'SC101');
  PERFORM pg_temp.deve_falhar('CID-RN04','Sobrescrever endereço (UPDATE do logradouro) é bloqueado',
    format('UPDATE cid.endereco_cidadao SET numero = %L WHERE id_endereco = %s', '999', v_end), 'SC101');
  PERFORM pg_temp.deve_falhar('CID-RN04','Alterar endereço já encerrado é bloqueado',
    format('UPDATE cid.endereco_cidadao SET data_fim = CURRENT_DATE + 5 WHERE id_cidadao = %s AND data_fim IS NOT NULL', v_id), 'SC101');
  PERFORM pg_temp.deve_falhar('CID-RN04','Dois endereços vigentes ao mesmo tempo são recusados',
    format($q$INSERT INTO cid.endereco_cidadao (id_cidadao,id_logradouro,numero,data_inicio) VALUES (%s,%s,'1',CURRENT_DATE)$q$, v_id, v_logr), '23P01');
  PERFORM pg_temp.deve_falhar('CID-RN04','Períodos de endereço sobrepostos são recusados',
    format($q$INSERT INTO cid.endereco_cidadao (id_cidadao,id_logradouro,numero,data_inicio,data_fim) VALUES (%s,%s,'1',CURRENT_DATE - 10, CURRENT_DATE + 10)$q$, v_id, v_logr), '23P01');
  -- CID-RF07
  PERFORM pg_temp.verificar('CID-RF07','Pesquisa por CPF formatado', (SELECT count(*) FROM cid.fn_pesquisar_cidadao('529.982.247-25')) = 1);
  PERFORM pg_temp.verificar('CID-RF07','Pesquisa por nome sem acento e sem caixa',
    EXISTS (SELECT 1 FROM cid.fn_pesquisar_cidadao('teste da silva') WHERE id_cidadao = v_id));
  PERFORM pg_temp.verificar('GER-RNF03','Auditoria registrou cadastro e mudança de endereço com usuário da aplicação',
    (SELECT count(*) FROM aud.log_auditoria WHERE esquema = 'cid' AND usuario_app = 'teste_automatizado') >= 5
    AND EXISTS (SELECT 1 FROM aud.log_auditoria WHERE tabela = 'endereco_cidadao' AND operacao = 'U' AND chave = 'id_endereco=' ||
                (SELECT min(id_endereco) FROM cid.endereco_cidadao WHERE id_cidadao = v_id)));
END $$;

-- ============================================================ EDU
DO $$
DECLARE v_aluno int; v_cid int; v_esc int; v_mat int; v_disc int; v_codigo text;
BEGIN
  SELECT a.id_aluno, a.id_escola, a.ano_escolar INTO v_aluno, v_esc FROM edu.aluno a WHERE a.situacao = 'ATIVO' AND a.ano_escolar = 5 LIMIT 1;
  -- uma disciplina do 5o ano em que o aluno ainda nao esta no periodo aberto nao existe (ja esta em todas); usa periodo futuro
  INSERT INTO edu.periodo_letivo VALUES (9, 2027, '2027-02-01', '2027-12-17', 'ABERTO');
  v_mat := edu.fn_matricular(v_aluno, 'EF05-MAT', 2027);
  PERFORM pg_temp.verificar('EDU-RF05/UC03','Matricular aluno em disciplina e período letivo', v_mat IS NOT NULL);
  PERFORM pg_temp.deve_falhar('EDU-RN03','Matrícula duplicada (mesmo aluno, disciplina e período) é recusada',
    format($q$SELECT edu.fn_matricular(%s,'EF05-MAT',2027)$q$, v_aluno), '23505');
  v_mat := edu.fn_matricular(v_aluno, 'EF05-LPO', 2027);
  PERFORM pg_temp.verificar('EDU-RN03','Mesma disciplina em outro período é permitida',
    (SELECT count(*) FROM edu.matricula m JOIN edu.disciplina d USING (id_disciplina) WHERE m.id_aluno = v_aluno AND d.codigo = 'EF05-MAT') >= 2);
  PERFORM pg_temp.deve_falhar('EDU-RN02','Matrícula sem aluno é recusada',
    $q$INSERT INTO edu.matricula (id_aluno, id_disciplina, id_periodo) VALUES (NULL, 1, 3)$q$, 'SC201');
  PERFORM pg_temp.deve_falhar('EDU-RN02','Matrícula com disciplina inexistente é recusada',
    format('INSERT INTO edu.matricula (id_aluno, id_disciplina, id_periodo) VALUES (%s, 99999, 9)', v_aluno), '23503');
  PERFORM pg_temp.deve_falhar('EDU-RNF03','Matrícula em período encerrado é recusada',
    format('INSERT INTO edu.matricula (id_aluno, id_disciplina, id_periodo) VALUES (%s, (SELECT id_disciplina FROM edu.disciplina WHERE codigo = %L), 1)', v_aluno, 'EF05-ART'), 'SC201');
  -- cenario proprio (desfeito no ROLLBACK): escola passa a ofertar so do 1o ao 5o ano
  SELECT a.id_aluno, a.id_escola INTO v_aluno, v_esc FROM edu.aluno a WHERE a.situacao = 'ATIVO' AND a.ano_escolar <= 5 LIMIT 1;
  UPDATE edu.escola SET ano_inicial = 1, ano_final = 5 WHERE id_escola = v_esc;
  PERFORM pg_temp.deve_falhar('EDU-RNF03','Matrícula em ano não ofertado pela escola do aluno é recusada',
    format($q$SELECT edu.fn_matricular(%s,'EF09-MAT',2027)$q$, v_aluno), 'SC201');
  SELECT id_aluno INTO v_aluno FROM edu.aluno WHERE situacao = 'EVADIDO' LIMIT 1;
  PERFORM pg_temp.deve_falhar('EDU-RNF03','Matrícula de aluno evadido é recusada',
    format($q$INSERT INTO edu.matricula (id_aluno,id_disciplina,id_periodo) SELECT %s, id_disciplina, 9 FROM edu.disciplina WHERE ano_escolar = (SELECT ano_escolar FROM edu.aluno WHERE id_aluno = %s) LIMIT 1$q$, v_aluno, v_aluno), 'SC201');
  -- EDU-RN01
  SELECT id_cidadao INTO v_cid FROM cid.cidadao c WHERE NOT EXISTS (SELECT 1 FROM edu.aluno a WHERE a.id_cidadao = c.id_cidadao) LIMIT 1;
  PERFORM pg_temp.deve_falhar('EDU-RN01','Aluno sem escola é recusado',
    format($q$INSERT INTO edu.aluno (id_cidadao, id_escola, ra, ano_escolar, turno, data_ingresso) VALUES (%s, NULL, 'RA00000001', 1, 'MANHA', CURRENT_DATE)$q$, v_cid), '23502');
  PERFORM pg_temp.deve_falhar('EDU-UC01','Aluno que não é cidadão cadastrado é recusado',
    $q$INSERT INTO edu.aluno (id_cidadao, id_escola, ra, ano_escolar, turno, data_ingresso) VALUES (999999999, 1, 'RA00000001', 1, 'MANHA', CURRENT_DATE)$q$, '23503');
  PERFORM pg_temp.deve_falhar('EDU-UC01','Mesmo cidadão cadastrado duas vezes como aluno é recusado',
    $q$INSERT INTO edu.aluno (id_cidadao, id_escola, ra, ano_escolar, turno, data_ingresso) SELECT id_cidadao, id_escola, 'RA00000002', ano_escolar, turno, data_ingresso FROM edu.aluno LIMIT 1$q$, '23505');
  -- EDU-RN04
  PERFORM pg_temp.deve_falhar('EDU-RN04','Código de disciplina repetido é recusado',
    $q$INSERT INTO edu.disciplina (codigo, nome, id_componente, ano_escolar, carga_horaria) VALUES ('EF05-MAT','Duplicada',2,6,10)$q$, '23505');
  -- EDU-RN05
  PERFORM pg_temp.verificar('EDU-RN05','Existem professores com mais de uma disciplina',
    EXISTS (SELECT 1 FROM edu.atribuicao_docente GROUP BY id_professor, id_periodo HAVING count(DISTINCT id_disciplina) > 1));
  -- EDU-RF06, EDU-RF07
  PERFORM pg_temp.verificar('EDU-RF06','Consulta de disciplinas de um aluno', (SELECT count(*) FROM edu.vw_matriculas_aluno WHERE id_aluno = 1) > 0,
    (SELECT count(*) FROM edu.vw_matriculas_aluno WHERE id_aluno = 1)::text || ' matrículas');
  PERFORM pg_temp.verificar('EDU-RF07/RF08','Alunos de uma disciplina com professor atribuído',
    EXISTS (SELECT 1 FROM edu.vw_alunos_disciplina WHERE cod_disciplina = 'EF05-MAT' AND ano_letivo = 2026 AND id_escola = 1 AND professores IS NOT NULL));
END $$;

-- ============================================================ EMP
DO $$
DECLARE v_vaga int; v_cand int; v_k int; v_k2 int; v_emp int; v_fechada int; v_hist int;
BEGIN
  SELECT id_empresa INTO v_emp FROM emp.empresa WHERE situacao = 'ATIVA' LIMIT 1;
  INSERT INTO emp.vaga (id_empresa, id_area, cod_cbo, titulo, tipo_contrato, salario, qtd_posicoes, id_escolaridade_minima)
  VALUES (v_emp, 3, '212405', 'Analista de dados (teste)', 'CLT', 5000, 1, 7) RETURNING id_vaga INTO v_vaga;
  PERFORM pg_temp.verificar('EMP-RF02/UC02','Vaga publicada nasce ABERTA', (SELECT status FROM emp.vaga WHERE id_vaga = v_vaga) = 'ABERTA');
  PERFORM pg_temp.deve_falhar('EMP-RN01','Vaga sem empresa é recusada',
    $q$INSERT INTO emp.vaga (id_empresa,id_area,cod_cbo,titulo,tipo_contrato,id_escolaridade_minima) VALUES (NULL,1,'411010','x','CLT',5)$q$, 'SC301');
  PERFORM pg_temp.deve_falhar('EMP-UC01','Empresa baixada não publica vaga',
    $q$INSERT INTO emp.vaga (id_empresa,id_area,cod_cbo,titulo,tipo_contrato,id_escolaridade_minima) SELECT id_empresa,1,'411010','x','CLT',5 FROM emp.empresa WHERE situacao = 'BAIXADA' LIMIT 1$q$, 'SC301');
  PERFORM pg_temp.deve_falhar('EMP-RF02','Vaga com código CBO inexistente é recusada',
    format($q$INSERT INTO emp.vaga (id_empresa,id_area,cod_cbo,titulo,tipo_contrato,id_escolaridade_minima) VALUES (%s,1,'000000','x','CLT',5)$q$, v_emp), '23503');
  PERFORM pg_temp.deve_falhar('EMP-RF01','Empresa com CNPJ inválido é recusada',
    $q$INSERT INTO emp.empresa (cnpj,razao_social,cod_cnae_classe,porte,id_logradouro,numero,data_abertura) VALUES ('11222333000180','X','47113','ME',1,'1','2020-01-01')$q$, '23514');
  SELECT id_candidato INTO v_cand FROM emp.candidato WHERE situacao = 'ATIVO' LIMIT 1;
  v_k := emp.fn_candidatar(v_cand, v_vaga);
  PERFORM pg_temp.verificar('EMP-RF04/RN05','Candidatura criada com status ENVIADA e registrada no histórico',
    (SELECT status FROM emp.candidatura WHERE id_candidatura = v_k) = 'ENVIADA'
    AND (SELECT count(*) FROM emp.candidatura_historico WHERE id_candidatura = v_k) = 1);
  PERFORM pg_temp.deve_falhar('EMP-RN03','Segunda candidatura ativa à mesma vaga é recusada',
    format('SELECT emp.fn_candidatar(%s, %s)', v_cand, v_vaga), '23505');
  PERFORM pg_temp.deve_falhar('EMP-RN05','Status inexistente é recusado',
    format($q$UPDATE emp.candidatura SET status = 'PERDIDA' WHERE id_candidatura = %s$q$, v_k), 'SC302');
  PERFORM pg_temp.deve_falhar('EMP-RN05','Transição inválida (ENVIADA -> CONTRATADA) é recusada',
    format($q$SELECT emp.fn_atualizar_candidatura(%s, 'CONTRATADA')$q$, v_k), 'SC302');
  PERFORM pg_temp.deve_falhar('EMP-RN02','Trocar a vaga de uma candidatura é recusado',
    format('UPDATE emp.candidatura SET id_vaga = id_vaga + 1 WHERE id_candidatura = %s', v_k), 'SC302');
  PERFORM emp.fn_atualizar_candidatura(v_k, 'EM_ANALISE', 'Currículo aderente');
  PERFORM emp.fn_atualizar_candidatura(v_k, 'RECUSADA');
  PERFORM pg_temp.verificar('EMP-RF06/RNF04','Cada mudança de status gera linha no histórico com observação',
    (SELECT count(*) FROM emp.candidatura_historico WHERE id_candidatura = v_k) = 3
    AND EXISTS (SELECT 1 FROM emp.candidatura_historico WHERE id_candidatura = v_k AND observacao = 'Currículo aderente'));
  v_k2 := emp.fn_candidatar(v_cand, v_vaga);
  PERFORM pg_temp.verificar('EMP-RN03','Após candidatura recusada, nova candidatura à mesma vaga é permitida', v_k2 IS NOT NULL);
  PERFORM pg_temp.deve_falhar('EMP-RNF04','Histórico de candidatura não pode ser apagado',
    format('DELETE FROM emp.candidatura_historico WHERE id_candidatura = %s', v_k), 'SC303');
  PERFORM pg_temp.deve_falhar('EMP-RNF04','Histórico de candidatura não pode ser alterado',
    format($q$UPDATE emp.candidatura_historico SET status_novo = 'CONTRATADA' WHERE id_candidatura = %s$q$, v_k), 'SC303');
  -- fluxo completo ate contratar: preenche a vaga (1 posicao) automaticamente
  PERFORM emp.fn_atualizar_candidatura(v_k2, 'EM_ANALISE');
  PERFORM emp.fn_atualizar_candidatura(v_k2, 'ENTREVISTA');
  PERFORM emp.fn_atualizar_candidatura(v_k2, 'APROVADA');
  PERFORM emp.fn_atualizar_candidatura(v_k2, 'CONTRATADA');
  PERFORM pg_temp.verificar('EMP-RF05','Contratação que completa as posições fecha a vaga como PREENCHIDA',
    (SELECT status FROM emp.vaga WHERE id_vaga = v_vaga) = 'PREENCHIDA' AND (SELECT data_encerramento FROM emp.vaga WHERE id_vaga = v_vaga) IS NOT NULL);
  SELECT id_candidato INTO v_cand FROM emp.candidato WHERE situacao = 'ATIVO' OFFSET 1 LIMIT 1;
  PERFORM pg_temp.deve_falhar('EMP-RN04','Candidatura a vaga não aberta é recusada', format('SELECT emp.fn_candidatar(%s, %s)', v_cand, v_vaga), 'SC301');
  PERFORM pg_temp.deve_falhar('EMP-RF05','Reabrir vaga preenchida (transição inválida) é recusado',
    format($q$UPDATE emp.vaga SET status = 'ABERTA' WHERE id_vaga = %s$q$, v_vaga), 'SC302');
  -- encerrar vaga recusa candidaturas ativas
  SELECT v.id_vaga INTO v_fechada FROM emp.vaga v WHERE v.status = 'ABERTA'
     AND EXISTS (SELECT 1 FROM emp.candidatura c WHERE c.id_vaga = v.id_vaga AND c.status IN ('ENVIADA','EM_ANALISE')) LIMIT 1;
  UPDATE emp.vaga SET status = 'ENCERRADA' WHERE id_vaga = v_fechada;
  PERFORM pg_temp.verificar('EMP-RF05','Encerrar vaga recusa as candidaturas ativas e registra no histórico',
    NOT EXISTS (SELECT 1 FROM emp.candidatura WHERE id_vaga = v_fechada AND status IN ('ENVIADA','EM_ANALISE','ENTREVISTA','APROVADA'))
    AND EXISTS (SELECT 1 FROM emp.candidatura_historico h JOIN emp.candidatura c USING (id_candidatura) WHERE c.id_vaga = v_fechada AND h.observacao = 'Vaga encerrada'));
  PERFORM pg_temp.verificar('EMP-RF07','Consulta de vagas abertas por área', (SELECT count(*) FROM emp.vw_vagas_abertas WHERE area = 'Comércio e Vendas') > 0);
  PERFORM pg_temp.verificar('EMP-RF08','Consulta de candidatos por vaga e empresa', (SELECT count(*) FROM emp.vw_candidatos_por_vaga WHERE id_empresa = v_emp) > 0);
END $$;

-- ============================================================ ASS
DO $$
DECLARE v_ben int; v_ben_rico int; v_fam int; v_cid int; v_at bigint; v_prog int; v_idoso int;
BEGIN
  -- ASS-RN01
  PERFORM pg_temp.deve_falhar('ASS-RN01','Beneficiário sem cidadão cadastrado é recusado',
    $q$INSERT INTO ass.beneficiario (id_cidadao, nis) VALUES (999999999, '12345678901')$q$, '23503');
  PERFORM pg_temp.deve_falhar('ASS-UC01','Integrante de família que não é cidadão é recusado',
    $q$INSERT INTO ass.familia_membro (id_familia, id_cidadao, parentesco) VALUES (1, 999999999, 'FILHO')$q$, '23503');
  PERFORM pg_temp.deve_falhar('ASS-UC01','Cidadão em duas famílias ao mesmo tempo é recusado',
    $q$INSERT INTO ass.familia_membro (id_familia, id_cidadao, parentesco) SELECT 2, id_cidadao, 'OUTRO' FROM ass.familia_membro WHERE id_familia = 1 AND data_saida IS NULL LIMIT 1$q$, '23505');
  -- ASS-RN02
  PERFORM pg_temp.deve_falhar('ASS-RN02','Programa sem critério de elegibilidade é recusado no COMMIT',
    $q$DO $x$ BEGIN INSERT INTO ass.programa (codigo, nome, esfera, data_inicio) VALUES ('SEMCRIT','Programa sem critério','MUNICIPAL',CURRENT_DATE); SET CONSTRAINTS ALL IMMEDIATE; END $x$ $q$, 'SC403');
  INSERT INTO ass.programa (codigo, nome, esfera, data_inicio, valor_referencia) VALUES ('TESTE','Programa de teste','MUNICIPAL',CURRENT_DATE,100) RETURNING id_programa INTO v_prog;
  INSERT INTO ass.criterio_elegibilidade VALUES (v_prog, 'IDADE_MIN', 60);
  SET CONSTRAINTS ALL IMMEDIATE;
  PERFORM pg_temp.verificar('ASS-RF03/RN02','Programa com critério é aceito', EXISTS (SELECT 1 FROM ass.programa WHERE id_programa = v_prog));
  PERFORM pg_temp.deve_falhar('ASS-RN02','Critério numérico sem valor é recusado',
    format($q$INSERT INTO ass.criterio_elegibilidade VALUES (%s, 'RENDA_PER_CAPITA_MAX', NULL)$q$, v_prog), 'SC403');
  SET CONSTRAINTS ALL DEFERRED;
  -- ASS-RN04: um beneficiario elegivel ao PBF ainda sem PBF ativo
  SELECT b.id_beneficiario INTO v_ben
    FROM ass.beneficiario b JOIN ass.familia_membro fm ON fm.id_cidadao = b.id_cidadao AND fm.data_saida IS NULL AND fm.parentesco = 'RESPONSAVEL'
    JOIN ass.vw_familia_resumo r USING (id_familia)
   WHERE r.renda_per_capita <= 218 AND NOT EXISTS (SELECT 1 FROM ass.beneficio_concedido bc WHERE bc.id_beneficiario = b.id_beneficiario AND bc.id_programa = 1 AND bc.situacao <> 'ENCERRADO')
     AND ass.fn_elegivel(b.id_beneficiario, 1) LIMIT 1;
  PERFORM ass.fn_vincular_programa(v_ben, 'PBF', 600);
  PERFORM pg_temp.verificar('ASS-RF04/UC03','Beneficiário elegível é vinculado ao programa',
    EXISTS (SELECT 1 FROM ass.beneficio_concedido WHERE id_beneficiario = v_ben AND id_programa = 1 AND situacao = 'ATIVO'));
  PERFORM pg_temp.deve_falhar('ASS-RNF04','Segundo vínculo em aberto no mesmo programa é recusado', format($q$SELECT ass.fn_vincular_programa(%s,'PBF',600)$q$, v_ben), '23505');
  SELECT b.id_beneficiario INTO v_ben_rico FROM ass.beneficiario b JOIN ass.familia_membro fm ON fm.id_cidadao = b.id_cidadao AND fm.data_saida IS NULL
    JOIN ass.vw_familia_resumo r USING (id_familia) WHERE r.renda_per_capita > 218 LIMIT 1;
  PERFORM pg_temp.deve_falhar('ASS-RN04','Família acima da renda per capita do PBF é recusada', format($q$SELECT ass.fn_vincular_programa(%s,'PBF')$q$, v_ben_rico), 'SC401');
  SELECT b.id_beneficiario INTO v_idoso FROM ass.beneficiario b JOIN cid.cidadao c USING (id_cidadao) WHERE age(c.data_nascimento) < interval '40 years' LIMIT 1;
  PERFORM pg_temp.deve_falhar('ASS-RN04','Menor de 65 anos no BPC Idoso é recusado', format($q$SELECT ass.fn_vincular_programa(%s,'BPC-IDOSO')$q$, v_idoso), 'SC401');
  SELECT b.id_beneficiario INTO v_idoso FROM ass.beneficiario b WHERE NOT b.pcd AND NOT EXISTS (SELECT 1 FROM emp.candidato k WHERE k.id_cidadao = b.id_cidadao) LIMIT 1;
  PERFORM pg_temp.deve_falhar('ASS-RN04','Integração EMP: quem não está no cadastro de emprego não entra no Qualifica', format($q$SELECT ass.fn_vincular_programa(%s,'QUALIFICA')$q$, v_idoso), 'SC401');
  -- integracao EDU: familia com crianca de 7 a 14 fora da rede perde elegibilidade ao PBF
  SELECT b.id_beneficiario INTO v_ben FROM ass.beneficiario b
    JOIN ass.familia_membro fm ON fm.id_cidadao = b.id_cidadao AND fm.data_saida IS NULL
    JOIN ass.vw_familia_resumo r USING (id_familia)
   WHERE r.renda_per_capita <= 218 AND EXISTS (SELECT 1 FROM ass.familia_membro f2 JOIN cid.cidadao c ON c.id_cidadao = f2.id_cidadao
           JOIN edu.aluno a ON a.id_cidadao = c.id_cidadao AND a.situacao = 'ATIVO'
          WHERE f2.id_familia = fm.id_familia AND f2.data_saida IS NULL AND date_part('year', age(c.data_nascimento)) BETWEEN 7 AND 14)
     AND ass.fn_elegivel(b.id_beneficiario, 1) LIMIT 1;
  UPDATE edu.aluno a SET situacao = 'EVADIDO'
   WHERE a.id_cidadao IN (SELECT f2.id_cidadao FROM ass.familia_membro f2 JOIN ass.familia_membro fm USING (id_familia)
                           JOIN ass.beneficiario b ON b.id_cidadao = fm.id_cidadao WHERE b.id_beneficiario = v_ben AND f2.data_saida IS NULL);
  PERFORM pg_temp.verificar('ASS-RN04 x EDU','Evasão escolar de criança da família torna o PBF inelegível (critério de frequência)',
    NOT ass.fn_elegivel(v_ben, 1), (SELECT string_agg(tipo_criterio || '=' || atende, ' ') FROM ass.fn_avaliar_elegibilidade(v_ben, 1)));
  -- ASS-RN03, ASS-RN05
  SELECT id_beneficiario INTO v_ben FROM ass.atendimento GROUP BY id_beneficiario HAVING count(*) >= 2 LIMIT 1;
  v_at := ass.fn_registrar_atendimento(v_ben, 1, 1, 2, 'Atualização cadastral de teste');
  PERFORM pg_temp.verificar('ASS-RF05/RN05','Novo atendimento é somado ao histórico, sem apagar os anteriores',
    (SELECT count(*) FROM ass.vw_historico_atendimentos WHERE id_beneficiario = v_ben) >= 3);
  PERFORM pg_temp.deve_falhar('ASS-RN03','Atendimento sem beneficiário é recusado',
    $q$INSERT INTO ass.atendimento (id_beneficiario,id_profissional,id_unidade,id_tipo,descricao) VALUES (NULL,1,1,1,'x')$q$, '23502');
  PERFORM pg_temp.deve_falhar('ASS-RN03','Atendimento sem data é recusado',
    format($q$INSERT INTO ass.atendimento (id_beneficiario,id_profissional,id_unidade,id_tipo,descricao,data_hora) VALUES (%s,1,1,1,'x',NULL)$q$, v_ben), '23502');
  PERFORM pg_temp.deve_falhar('ASS-RN05','Alterar atendimento é bloqueado', format($q$UPDATE ass.atendimento SET descricao = 'x' WHERE id_atendimento = %s$q$, v_at), 'SC402');
  PERFORM pg_temp.deve_falhar('ASS-RN05','Apagar atendimento é bloqueado', format('DELETE FROM ass.atendimento WHERE id_atendimento = %s', v_at), 'SC402');
  PERFORM pg_temp.verificar('ASS-RF06','Histórico de atendimentos do beneficiário em ordem', (SELECT count(*) FROM ass.vw_historico_atendimentos WHERE id_beneficiario = v_ben) > 0);
  PERFORM pg_temp.verificar('ASS-RF07','Famílias atendidas por programa', (SELECT sum(familias_atendidas) FROM rel.r05_familias_por_programa) > 0);
  PERFORM pg_temp.verificar('ASS-RF08','Atendimentos por região', (SELECT count(DISTINCT regiao) FROM rel.r06_atendimentos_por_regiao WHERE regiao IS NOT NULL) = 5);
END $$;

-- ============================================================ Auditoria
DO $$
BEGIN
  PERFORM pg_temp.deve_falhar('GER-RNF03','Trilha de auditoria não pode ser apagada', 'DELETE FROM aud.log_auditoria', 'SC901');
  PERFORM pg_temp.deve_falhar('GER-RNF03','Trilha de auditoria não pode ser alterada', $q$UPDATE aud.log_auditoria SET usuario_app = 'x'$q$, 'SC901');
  PERFORM pg_temp.verificar('GER-RNF03','Operações dos 4 módulos auditadas neste teste',
    (SELECT count(DISTINCT esquema) FROM aud.log_auditoria WHERE usuario_app = 'teste_automatizado') = 4,
    (SELECT string_agg(DISTINCT esquema::text, ',') FROM aud.log_auditoria WHERE usuario_app = 'teste_automatizado'));
END $$;

SELECT n, codigo, teste, CASE WHEN ok THEN 'PASSOU' ELSE 'FALHOU' END AS resultado, obtido FROM resultado ORDER BY n;
SELECT count(*) AS total, count(*) FILTER (WHERE ok) AS passou, count(*) FILTER (WHERE NOT ok) AS falhou FROM resultado;
ROLLBACK;
