-- =====================================================================
-- SmartCity Connect | 12 - Coleção de consultas práticas
-- Cada consulta indica o requisito atendido e a técnica SQL usada.
-- Execução: psql -d smartcity -f sql/12_consultas.sql
-- =====================================================================
\pset footer off
\echo '== Q01 CID-RF07 | Busca por nome aproximado (função + trigramas)'
SELECT * FROM cid.fn_pesquisar_cidadao('maria aparecida silva', 5);

\echo '== Q02 CID-UC03 | Cidadão com endereço vigente e histórico completo (JOIN + LEFT JOIN + ORDER BY)'
SELECT c.nome, l.tipo || ' ' || l.nome || ', ' || e.numero AS endereco, b.nome AS bairro, e.data_inicio, e.data_fim,
       CASE WHEN e.data_fim IS NULL THEN 'vigente' ELSE 'histórico' END AS situacao
  FROM cid.cidadao c
  JOIN cid.endereco_cidadao e USING (id_cidadao)
  JOIN cid.logradouro l USING (id_logradouro)
  JOIN cid.bairro b USING (id_bairro)
 WHERE c.id_cidadao = (SELECT id_cidadao FROM cid.endereco_cidadao GROUP BY id_cidadao HAVING count(*) = 3 ORDER BY id_cidadao LIMIT 1)
 ORDER BY e.data_inicio;

\echo '== Q03 CID-RF06 | Fluxo migratório entre regiões: de onde vieram os moradores atuais (LAG em janela)'
WITH mudancas AS (
  SELECT e.id_cidadao, b.id_regiao,
         lag(b.id_regiao) OVER (PARTITION BY e.id_cidadao ORDER BY e.data_inicio) AS regiao_anterior, e.data_fim
    FROM cid.endereco_cidadao e JOIN cid.logradouro l USING (id_logradouro) JOIN cid.bairro b USING (id_bairro))
SELECT ra.nome AS veio_de, rn.nome AS mora_em, count(*) AS cidadaos
  FROM mudancas m JOIN cid.regiao ra ON ra.id_regiao = m.regiao_anterior JOIN cid.regiao rn ON rn.id_regiao = m.id_regiao
 WHERE m.data_fim IS NULL AND m.regiao_anterior <> m.id_regiao
 GROUP BY ra.nome, rn.nome ORDER BY cidadaos DESC LIMIT 8;

\echo '== Q04 CID-RN03 | Distribuição da quantidade de telefones por cidadão (subconsulta no FROM)'
SELECT qtd_telefones, count(*) AS cidadaos
  FROM (SELECT c.id_cidadao, count(t.id_telefone) AS qtd_telefones
          FROM cid.cidadao c LEFT JOIN cid.telefone t USING (id_cidadao) GROUP BY c.id_cidadao) x
 GROUP BY qtd_telefones ORDER BY qtd_telefones;

\echo '== Q05 EDU-RF06 | Disciplinas de um aluno por período (visão do módulo)'
SELECT ano_letivo, cod_disciplina, disciplina, situacao, nota_final
  FROM edu.vw_matriculas_aluno WHERE id_aluno = 1000 ORDER BY ano_letivo, cod_disciplina;

\echo '== Q06 EDU-RF07/RF08 | Turma de Matemática do 5º ano de uma escola com professor (visão + filtro)'
SELECT ra, aluno, situacao, professores FROM edu.vw_alunos_disciplina
 WHERE cod_disciplina = 'EF05-MAT' AND ano_letivo = 2026 AND id_escola = 1 ORDER BY aluno LIMIT 10;

\echo '== Q07 EDU | Taxa de aprovação por componente e ano letivo (GROUP BY + FILTER)'
SELECT p.ano, cc.nome AS componente, count(*) AS matriculas,
       round(100.0 * count(*) FILTER (WHERE m.situacao = 'APROVADO') / count(*), 1) AS pct_aprovacao,
       round(avg(m.nota_final), 2) AS nota_media
  FROM edu.matricula m JOIN edu.periodo_letivo p USING (id_periodo)
  JOIN edu.disciplina d USING (id_disciplina) JOIN edu.componente_curricular cc USING (id_componente)
 WHERE m.situacao IN ('APROVADO','REPROVADO')
 GROUP BY p.ano, cc.nome ORDER BY p.ano, pct_aprovacao;

\echo '== Q08 EDU | Escolas com mais alunos por professor no ano corrente (RANK)'
SELECT escola, bairro, alunos_ativos, professores, round(alunos_ativos::numeric / nullif(professores, 0), 1) AS alunos_por_professor,
       rank() OVER (ORDER BY alunos_ativos::numeric / nullif(professores, 0) DESC) AS posicao
  FROM rel.r11_indicadores_escola ORDER BY posicao LIMIT 8;

\echo '== Q09 EDU-RN05 | Professores que lecionam em mais de uma escola (HAVING)'
SELECT pr.registro_funcional, cb.nome, count(DISTINCT ad.id_escola) AS escolas, count(DISTINCT ad.id_disciplina) AS disciplinas
  FROM edu.atribuicao_docente ad JOIN edu.professor pr USING (id_professor) JOIN cid.vw_cidadao_basico cb USING (id_cidadao)
 GROUP BY pr.id_professor, cb.nome HAVING count(DISTINCT ad.id_escola) > 1 ORDER BY escolas DESC LIMIT 5;

\echo '== Q10 EMP-RF07 | Slide do professor: vagas abertas por área'
SELECT * FROM rel.r01_vagas_abertas_por_area;

\echo '== Q11 EMP | Slide do professor: empresas que mais contratam (top 10)'
SELECT posicao, empresa, porte, setor_cnae, contratacoes FROM rel.r02_empresas_que_mais_contratam WHERE posicao <= 10 ORDER BY posicao;

\echo '== Q12 EMP-RF08 | Slide do professor: candidatos por empresa (top 10 por candidaturas)'
SELECT empresa, vagas, candidatos_distintos, candidaturas, em_andamento, candidaturas_por_vaga
  FROM rel.r03_candidatos_por_empresa ORDER BY candidaturas DESC LIMIT 10;

\echo '== Q13 EMP | Vagas abertas sem nenhum candidato há mais de 30 dias (NOT EXISTS)'
SELECT v.id_vaga, v.titulo, coalesce(e.nome_fantasia, e.razao_social) AS empresa, v.data_publicacao
  FROM emp.vaga v JOIN emp.empresa e USING (id_empresa)
 WHERE v.status = 'ABERTA' AND v.data_publicacao < CURRENT_DATE - 30
   AND NOT EXISTS (SELECT 1 FROM emp.candidatura c WHERE c.id_vaga = v.id_vaga)
 ORDER BY v.data_publicacao LIMIT 10;

\echo '== Q14 EMP-RNF04 | Tempo médio entre etapas do processo seletivo (historico + LEAD)'
SELECT status_novo AS etapa, proxima_etapa, count(*) AS transicoes,
       round(avg(EXTRACT(epoch FROM proxima_data - data_hora) / 86400)::numeric, 1) AS dias_medios
  FROM (SELECT status_novo, data_hora, lead(status_novo) OVER w AS proxima_etapa, lead(data_hora) OVER w AS proxima_data
          FROM emp.candidatura_historico WINDOW w AS (PARTITION BY id_candidatura ORDER BY data_hora, id_historico)) x
 WHERE proxima_etapa IS NOT NULL GROUP BY 1, 2 ORDER BY transicoes DESC;

\echo '== Q15 EMP | Salário médio contratado x salário médio ofertado por escolaridade mínima'
SELECT es.descricao AS escolaridade_minima, count(DISTINCT v.id_vaga) AS vagas, round(avg(v.salario), 2) AS salario_medio_ofertado,
       round(avg(v.salario) FILTER (WHERE c.status = 'CONTRATADA'), 2) AS salario_medio_contratado
  FROM emp.vaga v JOIN ref.escolaridade es ON es.id_escolaridade = v.id_escolaridade_minima
  LEFT JOIN emp.candidatura c USING (id_vaga)
 GROUP BY es.id_escolaridade ORDER BY es.id_escolaridade;

\echo '== Q16 ASS | Slide do professor: benefícios concedidos'
SELECT * FROM rel.r04_beneficios_concedidos;

\echo '== Q17 ASS-RF07 | Slide do professor: famílias atendidas por programa'
SELECT * FROM rel.r05_familias_por_programa;

\echo '== Q18 ASS-RF08 | Slide do professor: atendimentos por região no ano (GROUPING SETS)'
SELECT coalesce(regiao, 'TOTAL') AS regiao, atendimentos, pessoas_atendidas
  FROM rel.r06_atendimentos_por_regiao WHERE ano = 2026 AND bairro IS NULL ORDER BY regiao NULLS LAST;

\echo '== Q19 ASS-RF06 | Histórico de atendimentos de um beneficiário (mais recente primeiro)'
SELECT data_hora::date, tipo, unidade, profissional, encaminhamento
  FROM ass.vw_historico_atendimentos
 WHERE id_beneficiario = (SELECT id_beneficiario FROM ass.atendimento GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
 ORDER BY data_hora DESC LIMIT 10;

\echo '== Q20 ASS-RN04 | Busca ativa: famílias elegíveis ao Bolsa Família que ainda não recebem (integração CID x EDU x ASS)'
SELECT t.bairro, count(*) AS familias_elegiveis_sem_pbf
  FROM ass.vw_familia_resumo f
  JOIN ass.beneficiario b ON b.id_cidadao = f.id_cidadao_responsavel
  JOIN rel.vw_cidadao_territorio t ON t.id_cidadao = f.id_cidadao_responsavel
 WHERE f.renda_per_capita <= 218
   AND NOT EXISTS (SELECT 1 FROM ass.beneficio_concedido bc WHERE bc.id_beneficiario = b.id_beneficiario AND bc.id_programa = 1 AND bc.situacao <> 'ENCERRADO')
   AND ass.fn_elegivel(b.id_beneficiario, 1)
 GROUP BY t.bairro ORDER BY 2 DESC LIMIT 10;

\echo '== Q21 ASS x EDU | Crianças de 7 a 14 anos de famílias atendidas fora da rede municipal (risco de perder o PBF)'
SELECT t.regiao, count(*) AS criancas_fora_da_rede
  FROM ass.familia_membro fm JOIN cid.cidadao c USING (id_cidadao) JOIN rel.vw_cidadao_territorio t USING (id_cidadao)
 WHERE fm.data_saida IS NULL AND date_part('year', age(c.data_nascimento)) BETWEEN 7 AND 14
   AND NOT EXISTS (SELECT 1 FROM edu.aluno a WHERE a.id_cidadao = c.id_cidadao AND a.situacao = 'ATIVO')
 GROUP BY t.regiao ORDER BY 2 DESC;

\echo '== Q22 ASS x EMP | Beneficiários que conseguiram emprego, por programa'
SELECT * FROM rel.r09_beneficiarios_contratados;

\echo '== Q23 ASS x EMP | Vagas abertas compatíveis com beneficiários do Qualifica (LATERAL: top 3 por pessoa)'
SELECT cb.nome AS beneficiario, es.descricao AS escolaridade, x.titulo, x.salario
  FROM ass.beneficio_concedido bc JOIN ass.beneficiario b USING (id_beneficiario)
  JOIN emp.candidato k ON k.id_cidadao = b.id_cidadao JOIN cid.vw_cidadao_basico cb ON cb.id_cidadao = b.id_cidadao
  JOIN ref.escolaridade es ON es.id_escolaridade = k.id_escolaridade
  CROSS JOIN LATERAL (SELECT v.titulo, v.salario FROM emp.vaga v
                       WHERE v.status = 'ABERTA' AND v.id_area = k.id_area_interesse AND v.id_escolaridade_minima <= k.id_escolaridade
                       ORDER BY v.salario DESC LIMIT 3) x
 WHERE bc.id_programa = 4 AND bc.situacao = 'ATIVO' AND NOT EXISTS (SELECT 1 FROM emp.candidatura c WHERE c.id_candidato = k.id_candidato AND c.status = 'CONTRATADA')
 ORDER BY bc.id_beneficio LIMIT 9;

\echo '== Q24 Integração | Painel territorial dos 4 módulos (visão materializada)'
SELECT * FROM rel.mv_painel_territorial ORDER BY pbf_por_mil_hab DESC;

\echo '== Q25 GER-RNF03 | Trilha de auditoria por tabela e operação'
SELECT esquema, tabela, operacao, count(*) AS registros, max(data_hora) AS ultima FROM aud.log_auditoria GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
