-- =====================================================================
-- SmartCity Connect | 13 - Operações de exemplo (casos de uso ponta a ponta)
-- Um cidadão novo passa pelos quatro módulos. Tudo é DESFEITO no final.
-- Mostra o fluxo integrado: CID é a base; EDU, EMP e ASS só referenciam.
-- =====================================================================
\set ON_ERROR_STOP on
\pset footer off
BEGIN;
SET LOCAL app.usuario = 'demo_operador';

\echo '1) CID-UC01: cadastrar Joana e a filha (endereço e telefone na mesma transação)'
SELECT cid.fn_cadastrar_cidadao('39053344705','Joana Ribeiro Matos','1992-03-14','F','Lucia Ribeiro Matos',
       (SELECT min(id_logradouro) FROM cid.logradouro WHERE id_bairro = 15),'42',NULL,'35','991234567',3199901) AS id_joana \gset
SELECT cid.fn_cadastrar_cidadao('66882746630','Ana Ribeiro Matos','2017-06-02','F','Joana Ribeiro Matos',
       (SELECT min(id_logradouro) FROM cid.logradouro WHERE id_bairro = 15),'42') AS id_ana \gset
SELECT * FROM cid.fn_pesquisar_cidadao('390.533.447-05');

\echo '2) CID-UC02: Joana muda de endereço; o anterior fica no histórico'
SELECT cid.fn_alterar_endereco(:id_joana, (SELECT max(id_logradouro) FROM cid.logradouro WHERE id_bairro = 15), '108', 'Casa 2');
SELECT id_endereco, id_logradouro, numero, data_inicio, data_fim FROM cid.endereco_cidadao WHERE id_cidadao = :id_joana ORDER BY id_endereco;

\echo '3) EDU-UC01 e UC03: Ana vira aluna do 4º ano e é matriculada nas disciplinas do ano'
INSERT INTO edu.aluno (id_cidadao, id_escola, ra, ano_escolar, turno, data_ingresso)
VALUES (:id_ana, (SELECT min(id_escola) FROM edu.escola e JOIN cid.logradouro l USING (id_logradouro) WHERE l.id_bairro = 15 AND e.ano_inicial = 1),
        'RA99990001', 4, 'MANHA', CURRENT_DATE) RETURNING id_aluno AS id_aluno_ana \gset
SELECT edu.fn_matricular(:id_aluno_ana, codigo, 2026) FROM edu.disciplina WHERE ano_escolar = 4 ORDER BY codigo;
SELECT cod_disciplina, disciplina, situacao FROM edu.vw_matriculas_aluno WHERE id_aluno = :id_aluno_ana;

\echo '4) ASS-UC01 e UC02: família cadastrada a partir da base única; Joana vira beneficiária'
INSERT INTO ass.familia (codigo_familiar) VALUES ('99990000001') RETURNING id_familia AS id_fam \gset
INSERT INTO ass.familia_membro (id_familia, id_cidadao, parentesco, renda_mensal) VALUES
  (:id_fam, :id_joana, 'RESPONSAVEL', 350.00), (:id_fam, :id_ana, 'FILHO', 0);
INSERT INTO ass.beneficiario (id_cidadao, nis) VALUES (:id_joana, '99990000011') RETURNING id_beneficiario AS id_ben \gset
SELECT * FROM ass.vw_familia_resumo WHERE id_familia = :id_fam;

\echo '5) ASS-UC03: elegibilidade apurada pelo banco, critério a critério'
SELECT p.codigo, e.* FROM ass.programa p CROSS JOIN LATERAL ass.fn_avaliar_elegibilidade(:id_ben, p.id_programa) e ORDER BY p.id_programa;
SELECT ass.fn_vincular_programa(:id_ben, 'PBF', 650) AS beneficio_pbf;
SELECT ass.fn_vincular_programa(:id_ben, 'MATERIAL') AS beneficio_material;

\echo '6) ASS-UC04: atendimento registrado no CRAS do território'
SELECT ass.fn_registrar_atendimento(:id_ben, (SELECT min(id_profissional) FROM ass.profissional), au.id_unidade, 6,
       'Orientação sobre qualificação profissional', 'Posto de atendimento ao trabalhador')
  FROM ass.abrangencia_unidade au WHERE au.id_bairro = 15;

\echo '7) EMP-UC03 e UC04: Joana se candidata, avança no processo e é contratada'
INSERT INTO emp.candidato (id_cidadao, id_escolaridade, id_area_interesse) VALUES (:id_joana, 5, 2) RETURNING id_candidato AS id_cand \gset
SELECT min(id_vaga) AS id_vaga FROM emp.vaga WHERE status = 'ABERTA' AND id_area = 2 AND id_escolaridade_minima <= 5 AND qtd_posicoes = 1 \gset
SELECT emp.fn_candidatar(:id_cand, :id_vaga) AS id_candidatura \gset
SELECT emp.fn_atualizar_candidatura(:id_candidatura, 'EM_ANALISE');
SELECT emp.fn_atualizar_candidatura(:id_candidatura, 'ENTREVISTA', 'Entrevista marcada');
SELECT emp.fn_atualizar_candidatura(:id_candidatura, 'APROVADA');
SELECT emp.fn_atualizar_candidatura(:id_candidatura, 'CONTRATADA');
SELECT status_anterior, status_novo, usuario, observacao FROM emp.candidatura_historico WHERE id_candidatura = :id_candidatura ORDER BY id_historico;
SELECT id_vaga, status, data_encerramento FROM emp.vaga WHERE id_vaga = :id_vaga;

\echo '8) Agora o Qualifica passa a ser possível (exige cadastro no emprego)'
SELECT tipo_criterio, apurado, atende FROM ass.fn_avaliar_elegibilidade(:id_ben, 4);

\echo '9) GER-RNF03: tudo o que foi feito, na trilha de auditoria'
SELECT esquema || '.' || tabela AS tabela, operacao, count(*) FROM aud.log_auditoria WHERE usuario_app = 'demo_operador' GROUP BY 1, 2 ORDER BY 1, 2;
SELECT * FROM aud.fn_historico('cid', 'endereco_cidadao', 'id_endereco=' || (SELECT min(id_endereco) FROM cid.endereco_cidadao WHERE id_cidadao = :id_joana));

ROLLBACK;
\echo 'Operações desfeitas (ROLLBACK). A base continua igual.'
