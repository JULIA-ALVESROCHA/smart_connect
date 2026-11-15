# Estudo de desempenho

Mediana de 5 execuções, tempo de planejamento + execução, cache aquecido. Base com 500 mil cidadãos. "Sem índice" = índice removido dentro de uma transação desfeita.

| Req. | Consulta | Sem índice (ms) | Com índice (ms) | Ganho | Plano com índice |
|---|---|---:|---:|---:|---|
| CID-RF07 | Busca de cidadão por trecho do nome (sem acento) | 323.10 | 6.48 | 50x | Bitmap Heap Scan (cidadao); Bitmap Index Scan (ix_cidadao_nome_trgm) |
| CID-RF07 | Busca por CPF (índice da UNIQUE, sempre presente) | - | 0.49 | - | Index Scan (uq_cidadao_cpf); Index Scan (cidadao_pkey) |
| EMP-RF07 | Vagas abertas de uma área, mais recentes primeiro | 4.01 | 0.56 | 7x | Index Scan (ix_vaga_aberta_area) |
| EMP-RF08 | Candidatos de uma vaga | 10.27 | 0.38 | 27x | Index Scan (ix_candidatura_vaga) |
| EMP-RF08 | Candidatos de uma empresa (vaga + candidatura) | 4.12 | 0.77 | 5x | Index Scan (ix_vaga_empresa); Index Only Scan (ix_candidatura_vaga) |
| EMP-UC04 | Linha do tempo de uma candidatura | 27.09 | 0.33 | 81x | Index Scan (ix_historico_candidatura) |
| EDU-RF07 | Alunos de uma disciplina no período | 29.74 | 0.92 | 32x | Index Only Scan (ix_matricula_disciplina_periodo) |
| ASS-RF06 | Histórico de atendimentos de um beneficiário | 11.36 | 0.41 | 28x | Bitmap Heap Scan (atendimento); Bitmap Index Scan (ix_atendimento_beneficiario) |
| ASS-RF07 | Beneficiários ativos de um programa | 5.58 | 0.66 | 8x | Index Only Scan (ix_beneficio_programa_ativo) |
| ASS | Atendimentos do último mês (BRIN) | 4.57 | 3.54 | 1x | Bitmap Heap Scan (atendimento); Bitmap Index Scan (ix_atendimento_data_brin) |
| ASS-RF08 | Atendimentos por região (relatório R06, agregação completa) | - | 397.54 | - | Subquery Scan (); Seq Scan (atendimento); Seq Scan (cidadao); Seq Scan (endereco_cidadao); Seq Scan (beneficiario); Seq  |
| DASH | Painel territorial: visão normal x materializada | - | 1,209.15 | - | Seq Scan (bairro); Seq Scan (endereco_cidadao); Seq Scan (cidadao); Seq Scan (logradouro); Seq Scan (regiao); Index Only |
| DASH | Painel territorial materializado | - | 0.18 | - | Seq Scan (mv_painel_territorial) |

## Tamanho dos índices secundários

| Índice | Tamanho | Tamanho da tabela |
|---|---:|---:|
| emp.ix_historico_candidatura | 24 MB | 64 MB |
| cid.ix_cidadao_nome_trgm | 20 MB | 69 MB |
| cid.ix_endereco_vigente_logradouro | 11 MB | 33 MB |
| edu.ix_matricula_disciplina_periodo | 7248 kB | 74 MB |
| ass.ix_atendimento_beneficiario | 5744 kB | 26 MB |
| cid.ix_cidadao_nascimento | 4136 kB | 69 MB |
| emp.ix_candidatura_vaga | 4096 kB | 19 MB |
| emp.ix_candidatura_candidato | 2760 kB | 19 MB |
| ass.ix_beneficio_programa_ativo | 2232 kB | 5248 kB |
| ass.ix_beneficio_beneficiario | 1616 kB | 5248 kB |
| ass.ix_atendimento_unidade | 1272 kB | 26 MB |
| emp.ix_vaga_empresa | 456 kB | 6656 kB |
| edu.ix_aluno_escola | 368 kB | 4224 kB |
| edu.ix_atribuicao_professor | 336 kB | 1792 kB |
| emp.ix_empresa_cnae | 128 kB | 2624 kB |
| emp.ix_vaga_aberta_area | 64 kB | 6656 kB |
| cid.ix_logradouro_bairro | 48 kB | 576 kB |
| ass.ix_atendimento_data_brin | 24 kB | 26 MB |
| aud.ix_log_data_brin | 24 kB | 40 kB |
| aud.ix_log_registro | 16 kB | 40 kB |

Tamanho total do banco: **698 MB**.
