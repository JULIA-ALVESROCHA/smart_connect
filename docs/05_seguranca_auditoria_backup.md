# Segurança, auditoria e backup

Requisitos atendidos: GER-RNF01 a GER-RNF05, CID-RNF01/02, CID-RN05, EDU-RNF01/02, EMP-RNF01/02, ASS-RNF01/02.

## 1. Autenticação (GER-RNF01)

- Um usuário de banco por pessoa, senha com hash **SCRAM-SHA-256** (`password_encryption = 'scram-sha-256'`).
- `CONNECTION LIMIT` por usuário.
- Em produção: `pg_hba.conf` só com `hostssl ... scram-sha-256` (conexão cifrada obrigatória) e nenhum acesso `trust`.
- A aplicação informa o usuário final com `SET app.usuario = '...'`, que vai para a trilha de auditoria. Assim, mesmo com pool de conexões, sabemos quem fez cada operação.

Teste: senha errada é recusada (`evidencias/02_testes_seguranca.txt`).

## 2. Controle de acesso por perfil (GER-RNF02)

Perfis são papéis `NOLOGIN`. Usuários herdam um perfil. Privilégio mínimo: o esquema `public` não aceita criação de objetos, e nenhum perfil recebe `DELETE` em tabela de histórico.

| Perfil | Pode | Não pode |
|---|---|---|
| `sc_cadastro_cid` | cadastrar e atualizar cidadão, telefone, endereço (pelas funções) | apagar cidadão, ler assistência social |
| `sc_secretaria_edu` | escolas, alunos, matrículas, atribuições | ver CPF completo e filiação; alterar dados pessoais |
| `sc_professor` | consultar turmas e matrículas (visões) | alterar notas ou matrículas |
| `sc_operador_emp` | empresas, vagas, candidaturas | alterar o histórico de candidaturas |
| `sc_empresa` | publicar e acompanhar **as próprias** vagas | ver vagas e candidatos de outra empresa; ler CPF |
| `sc_assistencia` | famílias, beneficiários, benefícios, atendimentos | alterar atendimento registrado; ler matrículas diretamente |
| `sc_gestor_relatorios` | ler o esquema `rel` (agregados) | ler qualquer tabela com dado pessoal |
| `sc_auditor` | ler a trilha de auditoria | alterar ou apagar a trilha |
| `sc_admin` | administração funcional | não é superusuário |

Recursos usados:

- **Visão de dados mínimos** `cid.vw_cidadao_basico`: nome, CPF mascarado (`***.982.247-**`), idade. É o que EDU, EMP e ASS enxergam.
- **Função de localização** `cid.fn_localizar_cidadao(cpf)` com `SECURITY DEFINER`: o funcionário da escola encontra o cidadão pelo CPF sem ter permissão de listar a tabela inteira (passo "localiza o cidadão na base única" dos casos de uso EDU-UC01 e ASS-UC02).
- **Privilégio por coluna**: o operador de cadastro só pode atualizar `data_fim` do endereço, nunca o endereço em si.
- **Row Level Security** em `emp.vaga` e `emp.candidatura`: cada usuário do perfil empresa é ligado a uma empresa em `emp.usuario_empresa`, e as políticas filtram as linhas. Testado: a empresa vê só as suas vagas e não consegue publicar em nome de outra.
- **Funções `SECURITY DEFINER` com `search_path` fixo** para os cruzamentos entre módulos (a elegibilidade consulta EDU e EMP sem dar ao técnico da assistência acesso a essas tabelas).

30 testes conectam de verdade como cada usuário e conferem o que é permitido e o que é negado. Todos passam.

## 3. Privacidade e LGPD (GER-RNF05, ASS-RNF02)

| Princípio da LGPD | Implementação |
|---|---|
| Necessidade / minimização | módulos recebem só o mínimo (visão básica com CPF mascarado); relatórios só agregados |
| Dado sensível (art. 5º, II e art. 11) | condição de PcD em `ass.beneficiario`, acessível só ao perfil de assistência |
| Finalidade | cada perfil acessa o módulo da sua secretaria |
| Segurança e prevenção | trilha de auditoria imutável, senhas SCRAM, TLS em produção |
| Dados de teste | 100% sintéticos; e-mails no domínio reservado `example.com` |

Recomendação para produção: criptografia do volume de disco e dos backups; política de retenção definida pela Secretaria de Administração.

## 4. Auditoria (GER-RNF03)

`aud.log_auditoria` recebe uma linha por INSERT, UPDATE e DELETE nas 20 tabelas transacionais dos quatro módulos, via gatilho genérico:

| Campo | Conteúdo |
|---|---|
| `data_hora` | `clock_timestamp()` (momento real, não o início da transação) |
| `usuario_bd`, `usuario_app` | usuário do banco e usuário da aplicação |
| `transacao` | id da transação, para agrupar operações |
| `operacao`, `esquema`, `tabela`, `chave` | o que foi tocado |
| `dados_antes`, `dados_depois` | linha completa em JSONB |

- UPDATE sem mudança real não gera registro.
- A trilha é imutável: UPDATE, DELETE e TRUNCATE são bloqueados por gatilho.
- `aud.fn_historico(esquema, tabela, chave)` mostra, para um registro, quem mudou o quê, campo a campo (`{"nome": {"de": ..., "para": ...}}`).
- A carga inicial não é auditada (gatilhos desligados durante a carga); a trilha começa na operação.

## 5. Históricos não destrutivos (GER-RNF04)

| Histórico | Proteção |
|---|---|
| Endereços (CID-RN04) | DELETE bloqueado; endereço encerrado é imutável; exclusão de sobreposição |
| Candidaturas (EMP-RNF04) | tabela de histórico somente inserção |
| Atendimentos (ASS-RN05) | UPDATE e DELETE bloqueados |
| Benefícios | encerramento registra data e motivo; a linha não é apagada |
| Auditoria | somente inserção |

## 6. Backup e recuperação

`scripts/backup.sh`:

- `pg_dump` em formato custom (`-Fc`), comprimido: 65 MB para um banco de 698 MB.
- Soma SHA-256 gravada ao lado, para detectar arquivo corrompido.
- Retenção dos 7 backups mais recentes; pasta com permissão 700.
- `--verificar` restaura numa base temporária com `pg_restore -j 2` e compara contagens das tabelas principais. Resultado em `evidencias/07_backup_restauracao.txt`: idênticas.

Estratégia recomendada para produção:

| Camada | Como | Objetivo |
|---|---|---|
| Backup lógico diário | `scripts/backup.sh` via cron, cópia para outro local | recuperar uma tabela ou o banco inteiro |
| Backup físico semanal | `pg_basebackup` | base para recuperação no tempo |
| Arquivamento de WAL contínuo | `archive_mode = on` | recuperação para um instante (PITR); perda máxima de minutos |
| Teste de restauração | `backup.sh --verificar` mensal | backup que nunca foi restaurado não é backup |
| Regra 3-2-1 | 3 cópias, 2 mídias, 1 fora do local | desastre físico |
