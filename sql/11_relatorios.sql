-- =====================================================================
-- SmartCity Connect | 11 - Visoes integradas, relatorios e indicadores
-- Os exemplos do professor (slides EMP e ASS) aparecem como R01..R06.
-- R07..R12 mostram o valor de integrar os quatro modulos sobre o CID.
-- Visoes do esquema rel so expoem agregados (sem dado pessoal identificavel).
-- =====================================================================

-- Base: cidadao + bairro e regiao vigentes. Reutilizada por varias visoes.
CREATE VIEW rel.vw_cidadao_territorio AS
SELECT c.id_cidadao, date_part('year', age(c.data_nascimento))::int AS idade, c.sexo,
       b.id_bairro, b.nome AS bairro, r.id_regiao, r.nome AS regiao
  FROM cid.cidadao c
  JOIN cid.endereco_cidadao e ON e.id_cidadao = c.id_cidadao AND e.data_fim IS NULL
  JOIN cid.logradouro l ON l.id_logradouro = e.id_logradouro
  JOIN cid.bairro b ON b.id_bairro = l.id_bairro
  JOIN cid.regiao r ON r.id_regiao = b.id_regiao
 WHERE c.situacao = 'ATIVO';

-- R01 (slide EMP) Vagas abertas por area -----------------------------------
CREATE VIEW rel.r01_vagas_abertas_por_area AS
SELECT a.nome AS area, count(*) AS vagas_abertas, sum(v.qtd_posicoes) AS posicoes,
       round(avg(v.salario), 2) AS salario_medio,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_do_total
  FROM emp.vaga v JOIN emp.area_profissional a USING (id_area)
 WHERE v.status = 'ABERTA'
 GROUP BY a.nome
 ORDER BY vagas_abertas DESC;

-- R02 (slide EMP) Empresas que mais contratam --------------------------------
CREATE VIEW rel.r02_empresas_que_mais_contratam AS
SELECT e.id_empresa, coalesce(e.nome_fantasia, e.razao_social) AS empresa, e.porte, s.descricao AS setor_cnae,
       count(*) AS contratacoes,
       count(DISTINCT ca.id_vaga) AS vagas_com_contratacao,
       dense_rank() OVER (ORDER BY count(*) DESC) AS posicao
  FROM emp.candidatura ca
  JOIN emp.vaga v USING (id_vaga)
  JOIN emp.empresa e USING (id_empresa)
  JOIN ref.cnae_classe cl ON cl.cod_classe = e.cod_cnae_classe
  JOIN ref.cnae_grupo g USING (cod_grupo)
  JOIN ref.cnae_divisao d USING (cod_divisao)
  JOIN ref.cnae_secao s USING (cod_secao)
 WHERE ca.status = 'CONTRATADA'
 GROUP BY e.id_empresa, s.descricao;

-- Contratacoes por setor economico (secao CNAE do IBGE)
CREATE VIEW rel.r02b_contratacoes_por_setor AS
SELECT s.cod_secao, s.descricao AS setor, count(DISTINCT e.id_empresa) AS empresas_ativas,
       count(ca.id_candidatura) FILTER (WHERE ca.status = 'CONTRATADA') AS contratacoes
  FROM emp.empresa e
  JOIN ref.cnae_classe cl ON cl.cod_classe = e.cod_cnae_classe
  JOIN ref.cnae_grupo g USING (cod_grupo) JOIN ref.cnae_divisao d USING (cod_divisao) JOIN ref.cnae_secao s USING (cod_secao)
  LEFT JOIN emp.vaga v ON v.id_empresa = e.id_empresa
  LEFT JOIN emp.candidatura ca ON ca.id_vaga = v.id_vaga
 WHERE e.situacao = 'ATIVA'
 GROUP BY s.cod_secao, s.descricao
 ORDER BY contratacoes DESC;

-- R03 (slide EMP) Candidatos por empresa -------------------------------------
CREATE VIEW rel.r03_candidatos_por_empresa AS
SELECT e.id_empresa, coalesce(e.nome_fantasia, e.razao_social) AS empresa,
       count(DISTINCT v.id_vaga) AS vagas,
       count(DISTINCT ca.id_candidato) AS candidatos_distintos,
       count(ca.id_candidatura) AS candidaturas,
       count(*) FILTER (WHERE ca.status IN ('ENVIADA','EM_ANALISE','ENTREVISTA','APROVADA')) AS em_andamento,
       round(count(ca.id_candidatura)::numeric / nullif(count(DISTINCT v.id_vaga), 0), 1) AS candidaturas_por_vaga
  FROM emp.empresa e
  JOIN emp.vaga v USING (id_empresa)
  LEFT JOIN emp.candidatura ca USING (id_vaga)
 GROUP BY e.id_empresa;

-- R04 (slide ASS) Beneficios concedidos -------------------------------------
CREATE VIEW rel.r04_beneficios_concedidos AS
SELECT p.codigo, p.nome AS programa, p.esfera,
       count(*) FILTER (WHERE bc.situacao = 'ATIVO') AS ativos,
       count(*) FILTER (WHERE bc.situacao = 'SUSPENSO') AS suspensos,
       count(*) FILTER (WHERE bc.situacao = 'ENCERRADO') AS encerrados,
       sum(bc.valor_mensal) FILTER (WHERE bc.situacao = 'ATIVO') AS valor_mensal_total,
       round(avg(bc.valor_mensal) FILTER (WHERE bc.situacao = 'ATIVO'), 2) AS valor_medio
  FROM ass.programa p LEFT JOIN ass.beneficio_concedido bc USING (id_programa)
 GROUP BY p.id_programa
 ORDER BY ativos DESC;

-- R05 (slide ASS) Familias atendidas por programa (ASS-RF07) ----------------
CREATE VIEW rel.r05_familias_por_programa AS
SELECT p.codigo, p.nome AS programa,
       count(DISTINCT fm.id_familia) AS familias_atendidas,
       count(DISTINCT bc.id_beneficiario) AS beneficiarios,
       round(avg(fr.renda_per_capita), 2) AS renda_per_capita_media
  FROM ass.beneficio_concedido bc
  JOIN ass.programa p USING (id_programa)
  JOIN ass.beneficiario b USING (id_beneficiario)
  JOIN ass.familia_membro fm ON fm.id_cidadao = b.id_cidadao AND fm.data_saida IS NULL
  JOIN ass.vw_familia_resumo fr ON fr.id_familia = fm.id_familia
 WHERE bc.situacao = 'ATIVO'
 GROUP BY p.id_programa
 ORDER BY familias_atendidas DESC;

-- R06 (slide ASS) Atendimentos por regiao (ASS-RF08) ------------------------
-- Regiao = regiao administrativa do endereco VIGENTE do beneficiario (ponto em aberto 04).
CREATE VIEW rel.r06_atendimentos_por_regiao AS
SELECT t.regiao, t.bairro, date_part('year', a.data_hora)::int AS ano,
       count(*) AS atendimentos, count(DISTINCT a.id_beneficiario) AS pessoas_atendidas
  FROM ass.atendimento a
  JOIN ass.beneficiario b USING (id_beneficiario)
  JOIN rel.vw_cidadao_territorio t ON t.id_cidadao = b.id_cidadao
 GROUP BY GROUPING SETS ((t.regiao, t.bairro, ano), (t.regiao, ano), (ano));

-- R07 Integracao CID: perfil populacional por bairro --------------------------
CREATE VIEW rel.r07_populacao_por_bairro AS
SELECT regiao, bairro, count(*) AS habitantes,
       count(*) FILTER (WHERE idade < 15) AS de_0_a_14,
       count(*) FILTER (WHERE idade BETWEEN 15 AND 64) AS de_15_a_64,
       count(*) FILTER (WHERE idade >= 65) AS de_65_mais,
       round(100.0 * count(*) FILTER (WHERE sexo = 'F') / count(*), 1) AS pct_mulheres
  FROM rel.vw_cidadao_territorio
 GROUP BY regiao, bairro;

-- R08 Integracao CID x ASS x EDU x EMP: vulnerabilidade por bairro -----------
CREATE VIEW rel.r08_painel_territorial AS
WITH pop AS (SELECT id_bairro, count(*) habitantes FROM rel.vw_cidadao_territorio GROUP BY id_bairro),
ben AS (SELECT t.id_bairro, count(DISTINCT b.id_beneficiario) beneficiarios,
               count(DISTINCT b.id_beneficiario) FILTER (WHERE bc.id_programa = 1) beneficiarios_pbf
          FROM ass.beneficiario b JOIN rel.vw_cidadao_territorio t USING (id_cidadao)
          LEFT JOIN ass.beneficio_concedido bc ON bc.id_beneficiario = b.id_beneficiario AND bc.situacao = 'ATIVO'
         GROUP BY t.id_bairro),
alu AS (SELECT t.id_bairro, count(*) alunos FROM edu.aluno a JOIN rel.vw_cidadao_territorio t USING (id_cidadao)
         WHERE a.situacao = 'ATIVO' GROUP BY t.id_bairro),
cand AS (SELECT t.id_bairro, count(*) candidatos FROM emp.candidato k JOIN rel.vw_cidadao_territorio t USING (id_cidadao)
          WHERE k.situacao = 'ATIVO' GROUP BY t.id_bairro),
vag AS (SELECT l.id_bairro, count(*) vagas_abertas FROM emp.vaga v JOIN emp.empresa e USING (id_empresa)
          JOIN cid.logradouro l ON l.id_logradouro = e.id_logradouro WHERE v.status = 'ABERTA' GROUP BY l.id_bairro)
SELECT r.nome AS regiao, b.nome AS bairro, pop.habitantes,
       coalesce(ben.beneficiarios, 0) AS beneficiarios,
       round(1000.0 * coalesce(ben.beneficiarios_pbf, 0) / pop.habitantes, 1) AS pbf_por_mil_hab,
       coalesce(alu.alunos, 0) AS alunos_rede_municipal,
       coalesce(cand.candidatos, 0) AS candidatos_emprego,
       coalesce(vag.vagas_abertas, 0) AS vagas_abertas_no_bairro
  FROM cid.bairro b JOIN cid.regiao r USING (id_regiao)
  JOIN pop USING (id_bairro) LEFT JOIN ben USING (id_bairro) LEFT JOIN alu USING (id_bairro)
  LEFT JOIN cand USING (id_bairro) LEFT JOIN vag USING (id_bairro);

-- R09 Integracao EMP x ASS: beneficiarios que conseguiram emprego -------------
CREATE VIEW rel.r09_beneficiarios_contratados AS
SELECT p.nome AS programa,
       count(DISTINCT b.id_beneficiario) AS beneficiarios_ativos,
       count(DISTINCT b.id_beneficiario) FILTER (WHERE k.id_candidato IS NOT NULL) AS no_cadastro_de_emprego,
       count(DISTINCT b.id_beneficiario) FILTER (WHERE ca.status = 'CONTRATADA') AS contratados,
       round(100.0 * count(DISTINCT b.id_beneficiario) FILTER (WHERE ca.status = 'CONTRATADA')
             / nullif(count(DISTINCT b.id_beneficiario) FILTER (WHERE k.id_candidato IS NOT NULL), 0), 1) AS taxa_contratacao_pct
  FROM ass.beneficio_concedido bc
  JOIN ass.programa p USING (id_programa)
  JOIN ass.beneficiario b USING (id_beneficiario)
  LEFT JOIN emp.candidato k ON k.id_cidadao = b.id_cidadao
  LEFT JOIN emp.candidatura ca ON ca.id_candidato = k.id_candidato
 WHERE bc.situacao = 'ATIVO'
 GROUP BY p.id_programa;

-- R10 Integracao EDU x ASS: desempenho escolar de alunos de familias atendidas --
CREATE VIEW rel.r10_desempenho_por_vulnerabilidade AS
WITH familia_pbf AS (
  SELECT DISTINCT fm2.id_cidadao
    FROM ass.beneficio_concedido bc
    JOIN ass.beneficiario b USING (id_beneficiario)
    JOIN ass.familia_membro fm ON fm.id_cidadao = b.id_cidadao AND fm.data_saida IS NULL
    JOIN ass.familia_membro fm2 ON fm2.id_familia = fm.id_familia AND fm2.data_saida IS NULL
   WHERE bc.id_programa = 1 AND bc.situacao = 'ATIVO')
SELECT p.ano AS ano_letivo,
       CASE WHEN f.id_cidadao IS NULL THEN 'Demais alunos' ELSE 'Família no Bolsa Família' END AS grupo,
       count(DISTINCT m.id_aluno) AS alunos,
       round(avg(m.nota_final), 2) AS nota_media,
       round(avg(m.frequencia_pct), 1) AS frequencia_media,
       round(100.0 * count(*) FILTER (WHERE m.situacao = 'REPROVADO') / count(*), 1) AS pct_reprovacao
  FROM edu.matricula m
  JOIN edu.periodo_letivo p USING (id_periodo)
  JOIN edu.aluno a USING (id_aluno)
  LEFT JOIN familia_pbf f ON f.id_cidadao = a.id_cidadao
 WHERE m.situacao IN ('APROVADO','REPROVADO')
 GROUP BY p.ano, grupo;

-- R11 EDU: escolas, alunos por professor e ocupacao -----------------------------
CREATE VIEW rel.r11_indicadores_escola AS
SELECT e.id_escola, e.nome AS escola, b.nome AS bairro, e.ano_inicial || 'º ao ' || e.ano_final || 'º' AS anos_ofertados,
       (SELECT count(*) FROM edu.aluno a WHERE a.id_escola = e.id_escola AND a.situacao = 'ATIVO') AS alunos_ativos,
       (SELECT count(DISTINCT id_professor) FROM edu.atribuicao_docente ad
         WHERE ad.id_escola = e.id_escola AND ad.id_periodo = (SELECT id_periodo FROM edu.periodo_letivo WHERE situacao = 'ABERTO')) AS professores
  FROM edu.escola e JOIN cid.logradouro l USING (id_logradouro) JOIN cid.bairro b USING (id_bairro);

-- R12 EMP: funil de candidaturas (EMP-RNF04, usa o historico) -------------------
CREATE VIEW rel.r12_funil_candidaturas AS
SELECT h.status_novo AS etapa, s.ativa,
       count(DISTINCT h.id_candidatura) AS candidaturas_que_passaram,
       round(avg(EXTRACT(epoch FROM h.data_hora - c.data_candidatura) / 86400) FILTER (WHERE h.status_anterior IS NOT NULL), 1) AS dias_medios_desde_envio
  FROM emp.candidatura_historico h
  JOIN emp.candidatura c USING (id_candidatura)
  JOIN emp.status_candidatura s ON s.codigo = h.status_novo
 GROUP BY h.status_novo, s.ativa;

-- Painel de KPIs (uma linha) -------------------------------------------------
CREATE VIEW rel.kpi_geral AS
SELECT (SELECT count(*) FROM cid.cidadao WHERE situacao = 'ATIVO') AS cidadaos,
       (SELECT count(*) FROM cid.bairro) AS bairros,
       (SELECT count(*) FROM edu.escola WHERE situacao = 'ATIVA') AS escolas,
       (SELECT count(*) FROM edu.aluno WHERE situacao = 'ATIVO') AS alunos_ativos,
       (SELECT count(*) FROM edu.professor WHERE situacao = 'ATIVO') AS professores,
       (SELECT count(*) FROM emp.empresa WHERE situacao = 'ATIVA') AS empresas_ativas,
       (SELECT count(*) FROM emp.vaga WHERE status = 'ABERTA') AS vagas_abertas,
       (SELECT count(*) FROM emp.candidatura WHERE status = 'CONTRATADA') AS contratacoes,
       (SELECT count(*) FROM ass.familia WHERE situacao = 'ATIVA') AS familias_assistidas,
       (SELECT count(*) FROM ass.beneficio_concedido WHERE situacao = 'ATIVO') AS beneficios_ativos,
       (SELECT sum(valor_mensal) FROM ass.beneficio_concedido WHERE situacao = 'ATIVO') AS valor_mensal_beneficios,
       (SELECT count(*) FROM ass.atendimento WHERE data_hora >= date_trunc('year', now())) AS atendimentos_no_ano;

-- Visao materializada para o painel territorial (consulta pesada, dado muda pouco).
CREATE MATERIALIZED VIEW rel.mv_painel_territorial AS SELECT * FROM rel.r08_painel_territorial;
CREATE UNIQUE INDEX ON rel.mv_painel_territorial (bairro);  -- permite REFRESH ... CONCURRENTLY

GRANT SELECT ON ALL TABLES IN SCHEMA rel TO sc_gestor_relatorios, sc_admin;
-- O gestor le agregados; as visoes rodam com o privilegio do dono (padrao das views).
