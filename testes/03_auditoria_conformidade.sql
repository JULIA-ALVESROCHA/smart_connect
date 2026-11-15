-- =====================================================================
-- SmartCity Connect | Auditoria de conformidade da carga
-- A carga desliga os gatilhos de operacao (as restricoes declarativas seguem ligadas).
-- Este script prova que os dados historicos carregados respeitam as mesmas regras.
-- Cada linha conta as VIOLACOES; o esperado e zero.
-- =====================================================================
\pset footer off
WITH v(codigo, regra, violacoes) AS (VALUES
 ('CID-RN01','CPF duplicado ou inválido', (SELECT count(*) - count(DISTINCT cpf) + count(*) FILTER (WHERE NOT ref.fn_cpf_valido(cpf)) FROM cid.cidadao)),
 ('CID-RN02','Cidadão sem dados mínimos', (SELECT count(*) FROM cid.cidadao WHERE nome IS NULL OR nome_mae IS NULL OR data_nascimento IS NULL)),
 ('CID-RF05','Cidadão ativo sem endereço vigente', (SELECT count(*) FROM cid.cidadao c WHERE situacao = 'ATIVO' AND NOT EXISTS (SELECT 1 FROM cid.endereco_cidadao e WHERE e.id_cidadao = c.id_cidadao AND e.data_fim IS NULL))),
 ('CID-RN04','Endereço iniciado antes do nascimento', (SELECT count(*) FROM cid.endereco_cidadao e JOIN cid.cidadao c USING (id_cidadao) WHERE e.data_inicio < c.data_nascimento)),
 ('CID-RN04','Histórico com lacuna entre endereços consecutivos', (SELECT count(*) FROM (SELECT data_inicio, lag(data_fim) OVER (PARTITION BY id_cidadao ORDER BY data_inicio) AS fim_ant FROM cid.endereco_cidadao) x WHERE fim_ant IS NOT NULL AND fim_ant <> data_inicio)),
 ('EDU-RN01','Aluno sem escola', (SELECT count(*) FROM edu.aluno WHERE id_escola IS NULL)),
 ('EDU-RN03','Matrícula duplicada por aluno, disciplina e período', (SELECT count(*) FROM (SELECT 1 FROM edu.matricula GROUP BY id_aluno, id_disciplina, id_periodo HAVING count(*) > 1) x)),
 ('EDU-RNF03','Matrícula em ano não ofertado pela escola', (SELECT count(*) FROM edu.matricula m JOIN edu.aluno a USING (id_aluno) JOIN edu.escola e USING (id_escola) JOIN edu.disciplina d USING (id_disciplina) WHERE d.ano_escolar NOT BETWEEN e.ano_inicial AND e.ano_final)),
 ('EDU-RNF03','Matrícula CURSANDO de aluno não ativo', (SELECT count(*) FROM edu.matricula m JOIN edu.aluno a USING (id_aluno) WHERE m.situacao = 'CURSANDO' AND a.situacao <> 'ATIVO')),
 ('EDU-RNF03','Matrícula CURSANDO em período encerrado', (SELECT count(*) FROM edu.matricula m JOIN edu.periodo_letivo p USING (id_periodo) WHERE m.situacao = 'CURSANDO' AND p.situacao <> 'ABERTO')),
 ('EDU-RNF03','Matrícula antes do nascimento + 5 anos', (SELECT count(*) FROM edu.matricula m JOIN edu.aluno a USING (id_aluno) JOIN cid.cidadao c USING (id_cidadao) WHERE m.data_matricula < c.data_nascimento + interval '5 years')),
 ('EDU-RF08','Disciplina do ano corrente sem professor na escola', (SELECT count(*) FROM (SELECT DISTINCT a.id_escola, m.id_disciplina FROM edu.matricula m JOIN edu.aluno a USING (id_aluno) WHERE m.id_periodo = 3) x WHERE NOT EXISTS (SELECT 1 FROM edu.atribuicao_docente ad WHERE ad.id_escola = x.id_escola AND ad.id_disciplina = x.id_disciplina AND ad.id_periodo = 3))),
 ('EDU','Cidadão aluno e professor ao mesmo tempo', (SELECT count(*) FROM edu.aluno a JOIN edu.professor p USING (id_cidadao))),
 ('EMP-RN01','Vaga publicada antes da abertura da empresa', (SELECT count(*) FROM emp.vaga v JOIN emp.empresa e USING (id_empresa) WHERE v.data_publicacao < e.data_abertura)),
 ('EMP-RN03','Duas candidaturas ativas do mesmo candidato na mesma vaga', (SELECT count(*) FROM (SELECT 1 FROM emp.candidatura c JOIN emp.status_candidatura s ON s.codigo = c.status WHERE s.ativa GROUP BY id_candidato, id_vaga HAVING count(*) > 1) x)),
 ('EMP-RN04','Candidatura ativa em vaga que não aceita candidaturas', (SELECT count(*) FROM emp.candidatura c JOIN emp.vaga v USING (id_vaga) WHERE c.status IN ('ENVIADA','EM_ANALISE','ENTREVISTA','APROVADA') AND v.status NOT IN ('ABERTA','SUSPENSA'))),
 ('EMP-RN04','Candidatura feita antes da publicação ou depois do encerramento', (SELECT count(*) FROM emp.candidatura c JOIN emp.vaga v USING (id_vaga) WHERE c.data_candidatura::date < v.data_publicacao OR (v.data_encerramento IS NOT NULL AND c.data_candidatura::date > v.data_encerramento))),
 ('EMP-RN05','Candidatura cujo status atual difere do último registro do histórico', (SELECT count(*) FROM emp.candidatura c WHERE c.status <> (SELECT h.status_novo FROM emp.candidatura_historico h WHERE h.id_candidatura = c.id_candidatura ORDER BY h.data_hora DESC, h.id_historico DESC LIMIT 1))),
 ('EMP-RN05','Transição inválida registrada no histórico', (SELECT count(*) FROM emp.candidatura_historico h WHERE h.status_anterior IS NOT NULL AND NOT EXISTS (SELECT 1 FROM emp.transicao_candidatura t WHERE t.de = h.status_anterior AND t.para = h.status_novo))),
 ('EMP-RNF04','Candidatura sem registro inicial (ENVIADA) no histórico', (SELECT count(*) FROM emp.candidatura c WHERE NOT EXISTS (SELECT 1 FROM emp.candidatura_historico h WHERE h.id_candidatura = c.id_candidatura AND h.status_anterior IS NULL AND h.status_novo = 'ENVIADA'))),
 ('EMP-RF05','Vaga com mais contratados que posições', (SELECT count(*) FROM (SELECT v.id_vaga FROM emp.vaga v JOIN emp.candidatura c USING (id_vaga) WHERE c.status = 'CONTRATADA' GROUP BY v.id_vaga, v.qtd_posicoes HAVING count(*) > v.qtd_posicoes) x)),
 ('EMP-RF05','Vaga PREENCHIDA sem contratação', (SELECT count(*) FROM emp.vaga v WHERE status = 'PREENCHIDA' AND NOT EXISTS (SELECT 1 FROM emp.candidatura c WHERE c.id_vaga = v.id_vaga AND c.status = 'CONTRATADA'))),
 ('EMP','Candidato abaixo da escolaridade mínima contratado', (SELECT count(*) FROM emp.candidatura c JOIN emp.vaga v USING (id_vaga) JOIN emp.candidato k USING (id_candidato) WHERE c.status = 'CONTRATADA' AND k.id_escolaridade < v.id_escolaridade_minima)),
 ('ASS-RN01','Beneficiário sem cidadão válido', (SELECT count(*) FROM ass.beneficiario b LEFT JOIN cid.cidadao c USING (id_cidadao) WHERE c.id_cidadao IS NULL)),
 ('ASS-RN02','Programa sem critério', (SELECT count(*) FROM ass.programa p WHERE NOT EXISTS (SELECT 1 FROM ass.criterio_elegibilidade c WHERE c.id_programa = p.id_programa))),
 ('ASS-RN04','Benefício ativo de beneficiário hoje inelegível', (SELECT count(*) FROM ass.beneficio_concedido bc WHERE bc.situacao = 'ATIVO' AND NOT ass.fn_elegivel(bc.id_beneficiario, bc.id_programa))),
 ('ASS-RN03','Atendimento sem data de realização', (SELECT count(*) FROM ass.atendimento a WHERE a.data_hora IS NULL)),
 ('ASS','Família ativa sem responsável', (SELECT count(*) FROM ass.familia f WHERE NOT EXISTS (SELECT 1 FROM ass.familia_membro m WHERE m.id_familia = f.id_familia AND m.parentesco = 'RESPONSAVEL' AND m.data_saida IS NULL))),
 ('ASS','Atendimento feito em unidade de outro território (CRAS)', (SELECT count(*) FROM ass.atendimento a JOIN ass.unidade_atendimento u USING (id_unidade) JOIN ass.beneficiario b USING (id_beneficiario) JOIN rel.vw_cidadao_territorio t USING (id_cidadao) JOIN ass.abrangencia_unidade ab ON ab.id_bairro = t.id_bairro WHERE u.tipo = 'CRAS' AND ab.id_unidade <> a.id_unidade))
)
SELECT codigo, regra, violacoes, CASE WHEN violacoes = 0 THEN 'OK' ELSE 'VIOLAÇÃO' END AS status FROM v;
