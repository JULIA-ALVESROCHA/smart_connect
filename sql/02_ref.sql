-- =====================================================================
-- SmartCity Connect | 02 - Tabelas de referencia (dados publicos)
-- =====================================================================

-- IBGE Localidades
CREATE TABLE ref.uf (
  cod_uf   smallint    PRIMARY KEY,
  sigla    char(2)     NOT NULL UNIQUE,
  nome     varchar(40) NOT NULL UNIQUE,
  regiao   varchar(15) NOT NULL CHECK (regiao IN ('Norte','Nordeste','Sudeste','Sul','Centro-Oeste'))
);
COMMENT ON TABLE ref.uf IS 'Unidades da Federacao. Fonte: IBGE Localidades';

CREATE TABLE ref.municipio (
  cod_ibge   integer      PRIMARY KEY CHECK (cod_ibge BETWEEN 1000000 AND 9999999),
  nome       varchar(60)  NOT NULL,
  cod_uf     smallint     NOT NULL REFERENCES ref.uf,
  latitude   numeric(9,5),
  longitude  numeric(9,5),
  ddd        char(2),
  ficticio   boolean      NOT NULL DEFAULT false
);
COMMENT ON TABLE ref.municipio IS 'Municipios brasileiros (codigo IBGE de 7 digitos). Fonte: IBGE Localidades. ficticio = true apenas para Nova Esperanca Digital';

-- IBGE CNAE 2.3: hierarquia secao > divisao > grupo > classe.
-- Cada nivel em sua tabela elimina a dependencia transitiva classe -> grupo -> divisao -> secao.
CREATE TABLE ref.cnae_secao (
  cod_secao  char(1)      PRIMARY KEY,
  descricao  varchar(120) NOT NULL
);
CREATE TABLE ref.cnae_divisao (
  cod_divisao char(2)      PRIMARY KEY,
  descricao   varchar(160) NOT NULL,
  cod_secao   char(1)      NOT NULL REFERENCES ref.cnae_secao
);
CREATE TABLE ref.cnae_grupo (
  cod_grupo   char(3)      PRIMARY KEY,
  descricao   varchar(200) NOT NULL,
  cod_divisao char(2)      NOT NULL REFERENCES ref.cnae_divisao
);
CREATE TABLE ref.cnae_classe (
  cod_classe  char(5)      PRIMARY KEY,
  descricao   varchar(200) NOT NULL,
  cod_grupo   char(3)      NOT NULL REFERENCES ref.cnae_grupo
);
COMMENT ON TABLE ref.cnae_classe IS 'Classes da CNAE 2.3. Fonte: IBGE/CONCLA';

-- MTE CBO 2002
CREATE TABLE ref.cbo_ocupacao (
  cod_cbo  char(6)      PRIMARY KEY CHECK (cod_cbo ~ '^\d{6}$'),
  titulo   varchar(150) NOT NULL
);
COMMENT ON TABLE ref.cbo_ocupacao IS 'Ocupacoes da Classificacao Brasileira de Ocupacoes 2002. Fonte: Ministerio do Trabalho e Emprego';

-- Niveis de escolaridade em ordem crescente (usado por candidatos e vagas)
CREATE TABLE ref.escolaridade (
  id_escolaridade smallint    PRIMARY KEY,
  descricao       varchar(40) NOT NULL UNIQUE
);
COMMENT ON TABLE ref.escolaridade IS 'Niveis de escolaridade ordenados: id maior = nivel mais alto';

-- Salario minimo nacional por vigencia (parametro dos criterios de programas sociais)
CREATE TABLE ref.salario_minimo (
  vigencia_inicio date          PRIMARY KEY,
  valor           numeric(10,2) NOT NULL CHECK (valor > 0),
  ato_legal       varchar(60)   NOT NULL
);
COMMENT ON TABLE ref.salario_minimo IS 'Salario minimo nacional. Fonte: decretos federais';

INSERT INTO ref.escolaridade VALUES
 (1,'Sem instrução'),(2,'Fundamental incompleto'),(3,'Fundamental completo'),
 (4,'Médio incompleto'),(5,'Médio completo'),(6,'Superior incompleto'),
 (7,'Superior completo'),(8,'Pós-graduação');

INSERT INTO ref.salario_minimo VALUES
 ('2024-01-01',1412.00,'Decreto 11.864/2023'),
 ('2025-01-01',1518.00,'Decreto 12.342/2024'),
 ('2026-01-01',1621.00,'Decreto 12.797/2025');
