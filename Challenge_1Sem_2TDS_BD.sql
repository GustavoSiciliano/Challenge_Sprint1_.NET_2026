/* =====================================================================
   CHALLENGE CTMSP 2026 - 2TDS - Sprint 1
   Disciplina: Mastering Relational and Non-Relational Database
   Projeto   : Átomo+ (plataforma educativa sobre aplicações da
               tecnologia nuclear: conteúdo, quiz por faixa etária e ranking)
   SGBD      : Oracle Database 19c ou superior
   Execução  : SQL Developer -> abrir este arquivo -> "Executar Script" (F5)
   O script pode ser executado várias vezes: ele remove os objetos
   existentes antes de recriá-los.

   Seções
     0. Limpeza (drop seguro, sem erro na primeira execução)
     1. DDL - sequences
     2. DDL - tabelas e constraints
     3. DDL - índices
     4. DDL - comentários (dicionário de dados)
     5. DML - carga de dados
     6. Consultas com JOIN
   ===================================================================== */

SET DEFINE OFF;

-- =====================================================================
-- 0. LIMPEZA
--    Remove apenas os objetos deste projeto, se existirem.
-- =====================================================================
BEGIN
    FOR t IN (SELECT table_name
                FROM user_tables
               WHERE table_name IN ('TB_ALTERNATIVA', 'TB_TENTATIVA_QUIZ',
                                    'TB_PERGUNTA', 'TB_USUARIO',
                                    'TB_AREA_APLICACAO'))
    LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;

    FOR s IN (SELECT sequence_name
                FROM user_sequences
               WHERE sequence_name IN ('SQ_USUARIO', 'SQ_AREA_APLICACAO',
                                       'SQ_PERGUNTA', 'SQ_ALTERNATIVA',
                                       'SQ_TENTATIVA_QUIZ'))
    LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;
END;
/

-- =====================================================================
-- 1. DDL - SEQUENCES
--    INCREMENT BY 1 combina com allocationSize = 1 no JPA (Java)
--    e com HasSequence no EF Core (.NET).
-- =====================================================================
CREATE SEQUENCE sq_usuario        START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE sq_area_aplicacao START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE sq_pergunta       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE sq_alternativa    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE sq_tentativa_quiz START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- =====================================================================
-- 2. DDL - TABELAS
--    Padrão de nomes: TB_ tabela, PK_ chave primária, FK_ estrangeira,
--    UK_ única, CK_ check, IX_ índice, SQ_ sequence.
--    Colunas: id_ identificador, nm_ nome, ds_ descrição, dt_ data,
--    qt_ quantidade, nr_ número, st_ status/flag.
-- =====================================================================

-- Usuário da plataforma (criança, jovem ou adulto).
-- A faixa etária não é armazenada: é derivada de dt_nascimento,
-- evitando dependência transitiva (3FN) e dado desatualizado.
CREATE TABLE tb_usuario (
    id_usuario       NUMBER(10)         DEFAULT sq_usuario.NEXTVAL NOT NULL,
    nm_apelido       VARCHAR2(20 CHAR)  NOT NULL,
    ds_email         VARCHAR2(120 CHAR),
    dt_nascimento    DATE               NOT NULL,
    dt_cadastro      DATE               DEFAULT SYSDATE NOT NULL,
    st_ativo         CHAR(1)            DEFAULT 'S' NOT NULL,
    CONSTRAINT pk_usuario         PRIMARY KEY (id_usuario),
    CONSTRAINT uk_usuario_apelido UNIQUE (nm_apelido),
    CONSTRAINT uk_usuario_email   UNIQUE (ds_email),
    CONSTRAINT ck_usuario_apelido CHECK (LENGTH(nm_apelido) BETWEEN 3 AND 20),
    CONSTRAINT ck_usuario_email   CHECK (ds_email IS NULL OR ds_email LIKE '%_@_%._%'),
    CONSTRAINT ck_usuario_ativo   CHECK (st_ativo IN ('S', 'N'))
);

-- Área de aplicação benéfica da tecnologia nuclear.
-- Entidade usada pela aplicação console .NET (cadastro e consulta).
CREATE TABLE tb_area_aplicacao (
    id_area          NUMBER(10)          DEFAULT sq_area_aplicacao.NEXTVAL NOT NULL,
    nm_area          VARCHAR2(60 CHAR)   NOT NULL,
    ds_resumo        VARCHAR2(500 CHAR)  NOT NULL,
    ds_curiosidade   VARCHAR2(500 CHAR),
    CONSTRAINT pk_area_aplicacao PRIMARY KEY (id_area),
    CONSTRAINT uk_area_nome      UNIQUE (nm_area)
);

-- Pergunta do quiz. Cada pergunta pertence a uma área e a uma categoria.
-- O peso da pergunta NÃO é armazenado: ele depende só da categoria
-- (CRIANCA=10, JOVEM=20, ADULTO=30) e é calculado nas consultas (3FN).
CREATE TABLE tb_pergunta (
    id_pergunta      NUMBER(10)          DEFAULT sq_pergunta.NEXTVAL NOT NULL,
    id_area          NUMBER(10)          NOT NULL,
    ds_enunciado     VARCHAR2(400 CHAR)  NOT NULL,
    ds_categoria     VARCHAR2(10 CHAR)   NOT NULL,
    ds_explicacao    VARCHAR2(600 CHAR)  NOT NULL,
    st_ativa         CHAR(1)             DEFAULT 'S' NOT NULL,
    CONSTRAINT pk_pergunta           PRIMARY KEY (id_pergunta),
    CONSTRAINT fk_pergunta_area      FOREIGN KEY (id_area)
                                     REFERENCES tb_area_aplicacao (id_area),
    CONSTRAINT uk_pergunta_enunciado UNIQUE (ds_enunciado),
    CONSTRAINT ck_pergunta_categoria CHECK (ds_categoria IN ('CRIANCA', 'JOVEM', 'ADULTO')),
    CONSTRAINT ck_pergunta_ativa     CHECK (st_ativa IN ('S', 'N'))
);

-- Alternativa de uma pergunta (A, B, C ou D).
-- Composição: apagar a pergunta apaga suas alternativas (ON DELETE CASCADE).
-- "Exatamente uma correta por pergunta" é garantido pelo índice
-- único baseado em função UX_ALTERNATIVA_CORRETA (seção 3).
CREATE TABLE tb_alternativa (
    id_alternativa   NUMBER(10)          DEFAULT sq_alternativa.NEXTVAL NOT NULL,
    id_pergunta      NUMBER(10)          NOT NULL,
    ds_letra         CHAR(1)             NOT NULL,
    ds_texto         VARCHAR2(200 CHAR)  NOT NULL,
    st_correta       CHAR(1)             DEFAULT 'N' NOT NULL,
    CONSTRAINT pk_alternativa          PRIMARY KEY (id_alternativa),
    CONSTRAINT fk_alternativa_pergunta FOREIGN KEY (id_pergunta)
                                       REFERENCES tb_pergunta (id_pergunta)
                                       ON DELETE CASCADE,
    CONSTRAINT uk_alternativa_letra    UNIQUE (id_pergunta, ds_letra),
    CONSTRAINT ck_alternativa_letra    CHECK (ds_letra IN ('A', 'B', 'C', 'D')),
    CONSTRAINT ck_alternativa_correta  CHECK (st_correta IN ('S', 'N'))
);

-- Tentativa (partida) de quiz concluída por um usuário.
-- A pontuação é derivada (qt_acertos x peso da categoria) e não é
-- armazenada. O ranking é uma consulta sobre esta tabela.
-- Sem ON DELETE CASCADE: o histórico é preservado; usuário inativo
-- é tratado por st_ativo.
CREATE TABLE tb_tentativa_quiz (
    id_tentativa     NUMBER(10)         DEFAULT sq_tentativa_quiz.NEXTVAL NOT NULL,
    id_usuario       NUMBER(10)         NOT NULL,
    ds_categoria     VARCHAR2(10 CHAR)  NOT NULL,
    qt_perguntas     NUMBER(3)          NOT NULL,
    qt_acertos       NUMBER(3)          NOT NULL,
    nr_tempo_seg     NUMBER(5)          NOT NULL,
    dt_realizacao    DATE               DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_tentativa_quiz      PRIMARY KEY (id_tentativa),
    CONSTRAINT fk_tentativa_usuario   FOREIGN KEY (id_usuario)
                                      REFERENCES tb_usuario (id_usuario),
    CONSTRAINT ck_tentativa_categoria CHECK (ds_categoria IN ('CRIANCA', 'JOVEM', 'ADULTO')),
    CONSTRAINT ck_tentativa_perguntas CHECK (qt_perguntas BETWEEN 1 AND 50),
    CONSTRAINT ck_tentativa_acertos   CHECK (qt_acertos BETWEEN 0 AND qt_perguntas),
    CONSTRAINT ck_tentativa_tempo     CHECK (nr_tempo_seg > 0)
);

-- =====================================================================
-- 3. DDL - ÍNDICES
--    O Oracle não indexa chaves estrangeiras automaticamente.
--    Índices em FKs evitam full scan nos JOINs e bloqueio da tabela
--    filha quando a tabela pai é alterada.
-- =====================================================================
CREATE INDEX ix_pergunta_area      ON tb_pergunta (id_area);
CREATE INDEX ix_pergunta_categoria ON tb_pergunta (ds_categoria);
CREATE INDEX ix_tentativa_usuario  ON tb_tentativa_quiz (id_usuario);
CREATE INDEX ix_tentativa_ranking  ON tb_tentativa_quiz (ds_categoria, qt_acertos DESC, nr_tempo_seg);
-- id_pergunta já é a coluna líder de UK_ALTERNATIVA_LETRA, que serve de índice da FK.

-- Regra de negócio: no máximo UMA alternativa correta por pergunta.
-- Linhas com st_correta = 'N' geram NULL e ficam fora do índice;
-- duas linhas 'S' na mesma pergunta violam a unicidade.
CREATE UNIQUE INDEX ux_alternativa_correta
    ON tb_alternativa (CASE WHEN st_correta = 'S' THEN id_pergunta END);

-- =====================================================================
-- 4. DDL - COMENTÁRIOS (dicionário de dados)
-- =====================================================================
COMMENT ON TABLE  tb_usuario                     IS 'Usuários da plataforma Átomo+';
COMMENT ON COLUMN tb_usuario.nm_apelido          IS 'Apelido público exibido no ranking (3 a 20 caracteres, único)';
COMMENT ON COLUMN tb_usuario.ds_email            IS 'E-mail opcional (crianças podem jogar sem e-mail)';
COMMENT ON COLUMN tb_usuario.dt_nascimento       IS 'Base para derivar a faixa etária (criança, jovem, adulto)';
COMMENT ON COLUMN tb_usuario.st_ativo            IS 'S = ativo, N = inativo (exclusão lógica)';

COMMENT ON TABLE  tb_area_aplicacao              IS 'Áreas de aplicação benéfica da tecnologia nuclear';
COMMENT ON COLUMN tb_area_aplicacao.ds_resumo    IS 'Texto educativo curto exibido no card da área';
COMMENT ON COLUMN tb_area_aplicacao.ds_curiosidade IS 'Curiosidade ("você sabia?") sobre a área';

COMMENT ON TABLE  tb_pergunta                    IS 'Banco de perguntas do quiz';
COMMENT ON COLUMN tb_pergunta.ds_categoria       IS 'CRIANCA (peso 10), JOVEM (peso 20) ou ADULTO (peso 30)';
COMMENT ON COLUMN tb_pergunta.ds_explicacao      IS 'Explicação exibida após a resposta (feedback educativo)';

COMMENT ON TABLE  tb_alternativa                 IS 'Alternativas de cada pergunta (A a D, uma correta)';
COMMENT ON COLUMN tb_alternativa.st_correta      IS 'S = alternativa correta, N = incorreta';

COMMENT ON TABLE  tb_tentativa_quiz              IS 'Partidas de quiz concluídas, base do ranking';
COMMENT ON COLUMN tb_tentativa_quiz.nr_tempo_seg IS 'Tempo total da partida em segundos (critério de desempate)';

-- =====================================================================
-- 5. DML - CARGA DE DADOS
-- =====================================================================

-- ---------- Áreas de aplicação (5) ----------
INSERT INTO tb_area_aplicacao (id_area, nm_area, ds_resumo, ds_curiosidade)
VALUES (sq_area_aplicacao.NEXTVAL, 'Saúde',
        'Radioisótopos são usados em exames de imagem e a radiação é usada na radioterapia contra o câncer.',
        'O tecnécio-99m é o radioisótopo mais usado em exames de diagnóstico no mundo.');

INSERT INTO tb_area_aplicacao (id_area, nm_area, ds_resumo, ds_curiosidade)
VALUES (sq_area_aplicacao.NEXTVAL, 'Agricultura',
        'A irradiação conserva alimentos por mais tempo e ajuda a controlar pragas sem agrotóxicos.',
        'Alimento irradiado não fica radioativo: a radiação passa por ele, como a luz de um raio X.');

INSERT INTO tb_area_aplicacao (id_area, nm_area, ds_resumo, ds_curiosidade)
VALUES (sq_area_aplicacao.NEXTVAL, 'Indústria',
        'A radiação inspeciona soldas e peças sem destruí-las e esteriliza materiais médicos descartáveis.',
        'Seringas e luvas cirúrgicas costumam ser esterilizadas com radiação gama do cobalto-60.');

INSERT INTO tb_area_aplicacao (id_area, nm_area, ds_resumo, ds_curiosidade)
VALUES (sq_area_aplicacao.NEXTVAL, 'Pesquisa Científica',
        'Técnicas nucleares permitem datar fósseis, estudar o meio ambiente e desenvolver novos materiais.',
        'A datação por carbono-14 permite estimar a idade de materiais orgânicos de até cerca de 50 mil anos.');

INSERT INTO tb_area_aplicacao (id_area, nm_area, ds_resumo, ds_curiosidade)
VALUES (sq_area_aplicacao.NEXTVAL, 'Energia',
        'Usinas nucleares geram eletricidade em grande escala sem emitir CO2 durante a geração.',
        'O Programa Nuclear da Marinha, conduzido pelo CTMSP, desenvolveu ultracentrífugas nacionais para enriquecer urânio.');

-- ---------- Usuários (6) ----------
INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'atomzinho', NULL, DATE '2016-04-12', TO_DATE('2026-10-18 09:10', 'YYYY-MM-DD HH24:MI'));

INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'lua_curiosa', NULL, DATE '2015-09-03', TO_DATE('2026-10-18 10:25', 'YYYY-MM-DD HH24:MI'));

INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'nerd_do_isotopo', 'pedro.alves@email.com', DATE '2010-01-22', TO_DATE('2026-10-19 14:02', 'YYYY-MM-DD HH24:MI'));

INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'bia_quimica', 'beatriz.souza@email.com', DATE '2009-06-30', TO_DATE('2026-10-19 16:40', 'YYYY-MM-DD HH24:MI'));

INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'prof_marcos', 'marcos.lima@email.com', DATE '1984-11-15', TO_DATE('2026-10-20 08:15', 'YYYY-MM-DD HH24:MI'));

INSERT INTO tb_usuario (id_usuario, nm_apelido, ds_email, dt_nascimento, dt_cadastro)
VALUES (sq_usuario.NEXTVAL, 'helena_rad', 'helena.costa@email.com', DATE '1991-02-08', TO_DATE('2026-10-20 19:50', 'YYYY-MM-DD HH24:MI'));

-- ---------- Perguntas (9: 3 por categoria) e alternativas (36) ----------
-- Cada pergunta é inserida e, em seguida, suas alternativas usam
-- sq_pergunta.CURRVAL, que guarda o id recém-gerado nesta sessão.

-- P1 - CRIANCA - Saúde
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Saúde'),
        'A radiação pode ajudar os médicos a tratar qual doença?', 'CRIANCA',
        'Na radioterapia, a radiação é direcionada para destruir células do câncer.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Câncer', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Gripe', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Cárie', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Catapora', 'N');

-- P2 - CRIANCA - Agricultura
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Agricultura'),
        'Um alimento que passou por irradiação fica radioativo?', 'CRIANCA',
        'Não. A radiação passa pelo alimento e elimina micróbios, mas não deixa o alimento radioativo.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Sim, ele passa a brilhar no escuro', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Não, ele continua seguro para comer', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Só se for uma fruta', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Só se ficar fora da geladeira', 'N');

-- P3 - CRIANCA - Energia
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Energia'),
        'O que uma usina nuclear produz para chegar até as nossas casas?', 'CRIANCA',
        'A usina usa o calor do reator para gerar vapor, girar turbinas e produzir eletricidade.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Água encanada', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Gás de cozinha', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Eletricidade', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Vento', 'N');

-- P4 - JOVEM - Indústria
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Indústria'),
        'Que técnica usa radiação gama para encontrar falhas em soldas sem destruir a peça?', 'JOVEM',
        'A gamagrafia funciona como um raio X industrial e revela trincas e bolhas internas.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Gamagrafia', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Eletrólise', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Destilação', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Galvanização', 'N');

-- P5 - JOVEM - Pesquisa Científica
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Pesquisa Científica'),
        'Qual isótopo é usado para estimar a idade de fósseis e materiais orgânicos?', 'JOVEM',
        'Seres vivos absorvem carbono-14 e, após a morte, ele decai em ritmo conhecido, o que permite datar o material.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Urânio-235', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Carbono-14', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Cobalto-60', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Iodo-131', 'N');

-- P6 - JOVEM - Agricultura
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Agricultura'),
        'Na Técnica do Inseto Estéril, a radiação é usada para quê?', 'JOVEM',
        'Machos esterilizados por radiação são soltos no ambiente e, sem descendentes, a população da praga diminui.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Eliminar plantas daninhas', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Esterilizar machos da praga e reduzir a população', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Aumentar o tamanho dos frutos', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Irrigar o solo', 'N');

-- P7 - ADULTO - Saúde
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Saúde'),
        'Qual radioisótopo é o mais usado em exames de diagnóstico da medicina nuclear?', 'ADULTO',
        'O tecnécio-99m tem meia-vida de cerca de 6 horas e emite radiação gama fácil de detectar, ideal para imagens.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Tecnécio-99m', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Plutônio-239', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Césio-137', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Trítio', 'N');

-- P8 - ADULTO - Energia
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Energia'),
        'Que tecnologia do ciclo do combustível nuclear a Marinha do Brasil desenvolveu no seu Programa Nuclear?', 'ADULTO',
        'O CTMSP desenvolveu ultracentrífugas nacionais para enriquecer urânio, tecnologia dominada por poucos países.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Ultracentrífugas para enriquecimento de urânio', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Reatores de fusão nuclear', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Painéis fotovoltaicos', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Turbinas eólicas offshore', 'N');

-- P9 - ADULTO - Indústria
INSERT INTO tb_pergunta (id_pergunta, id_area, ds_enunciado, ds_categoria, ds_explicacao)
VALUES (sq_pergunta.NEXTVAL,
        (SELECT id_area FROM tb_area_aplicacao WHERE nm_area = 'Indústria'),
        'Seringas e luvas cirúrgicas descartáveis costumam ser esterilizadas com radiação gama de qual fonte?', 'ADULTO',
        'A radiação gama do cobalto-60 esteriliza o produto já embalado, sem calor e sem deixar resíduo radioativo.');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'A', 'Cobalto-60', 'S');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'B', 'Urânio-238', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'C', 'Rádio-226', 'N');
INSERT INTO tb_alternativa (id_alternativa, id_pergunta, ds_letra, ds_texto, st_correta) VALUES (sq_alternativa.NEXTVAL, sq_pergunta.CURRVAL, 'D', 'Carbono-14', 'N');

-- ---------- Tentativas de quiz (10) ----------
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'atomzinho'),
        'CRIANCA', 3, 2, 95, TO_DATE('2026-10-18 09:20', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'atomzinho'),
        'CRIANCA', 3, 3, 80, TO_DATE('2026-10-18 09:35', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'lua_curiosa'),
        'CRIANCA', 3, 3, 72, TO_DATE('2026-10-18 10:40', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'nerd_do_isotopo'),
        'JOVEM', 3, 3, 110, TO_DATE('2026-10-19 14:20', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'bia_quimica'),
        'JOVEM', 3, 2, 98, TO_DATE('2026-10-19 16:55', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'bia_quimica'),
        'JOVEM', 3, 3, 104, TO_DATE('2026-10-20 18:05', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'prof_marcos'),
        'ADULTO', 3, 3, 130, TO_DATE('2026-10-20 08:30', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'helena_rad'),
        'ADULTO', 3, 2, 85, TO_DATE('2026-10-20 20:10', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'helena_rad'),
        'JOVEM', 3, 3, 90, TO_DATE('2026-10-21 07:45', 'YYYY-MM-DD HH24:MI'));
INSERT INTO tb_tentativa_quiz (id_tentativa, id_usuario, ds_categoria, qt_perguntas, qt_acertos, nr_tempo_seg, dt_realizacao)
VALUES (sq_tentativa_quiz.NEXTVAL, (SELECT id_usuario FROM tb_usuario WHERE nm_apelido = 'prof_marcos'),
        'ADULTO', 3, 1, 60, TO_DATE('2026-10-21 12:00', 'YYYY-MM-DD HH24:MI'));

COMMIT;

-- =====================================================================
-- 6. CONSULTAS COM JOIN
-- =====================================================================

-- ---------------------------------------------------------------------
-- Consulta 1 - Ranking por categoria
-- Pergunta da solução: "Quem são os melhores jogadores de cada categoria?"
-- JOIN: TB_USUARIO x TB_TENTATIVA_QUIZ
-- Regras: pontuação = acertos x peso da categoria (10/20/30);
--         vale a melhor tentativa de cada usuário na categoria;
--         desempate pelo menor tempo; só usuários ativos.
-- ---------------------------------------------------------------------
WITH pontuacoes AS (
    SELECT t.ds_categoria,
           u.id_usuario,
           u.nm_apelido,
           t.qt_acertos,
           t.qt_perguntas,
           t.nr_tempo_seg,
           t.qt_acertos * CASE t.ds_categoria
                              WHEN 'CRIANCA' THEN 10
                              WHEN 'JOVEM'   THEN 20
                              WHEN 'ADULTO'  THEN 30
                          END AS pontuacao,
           ROW_NUMBER() OVER (PARTITION BY t.ds_categoria, u.id_usuario
                              ORDER BY t.qt_acertos DESC, t.nr_tempo_seg ASC) AS ordem_usuario
      FROM tb_tentativa_quiz t
     INNER JOIN tb_usuario u
             ON u.id_usuario = t.id_usuario
     WHERE u.st_ativo = 'S'
)
SELECT ds_categoria                        AS categoria,
       RANK() OVER (PARTITION BY ds_categoria
                    ORDER BY pontuacao DESC, nr_tempo_seg ASC) AS posicao,
       nm_apelido                          AS jogador,
       pontuacao,
       qt_acertos || '/' || qt_perguntas   AS acertos,
       nr_tempo_seg                        AS tempo_segundos
  FROM pontuacoes
 WHERE ordem_usuario = 1
 ORDER BY CASE ds_categoria WHEN 'CRIANCA' THEN 1 WHEN 'JOVEM' THEN 2 ELSE 3 END,
          posicao;

-- ---------------------------------------------------------------------
-- Consulta 2 - Gabarito educativo por área de aplicação
-- Pergunta da solução: "Quais perguntas existem em cada área, para qual
-- público, e qual é a resposta correta com sua explicação?"
-- (alimenta a tela de revisão do app depois do quiz)
-- JOIN: TB_AREA_APLICACAO x TB_PERGUNTA x TB_ALTERNATIVA
-- ---------------------------------------------------------------------
SELECT a.nm_area                         AS area,
       p.ds_categoria                    AS categoria,
       p.ds_enunciado                    AS pergunta,
       alt.ds_letra || ') ' || alt.ds_texto AS resposta_correta,
       p.ds_explicacao                   AS explicacao
  FROM tb_area_aplicacao a
 INNER JOIN tb_pergunta p
         ON p.id_area = a.id_area
 INNER JOIN tb_alternativa alt
         ON alt.id_pergunta = p.id_pergunta
        AND alt.st_correta  = 'S'
 WHERE p.st_ativa = 'S'
 ORDER BY a.nm_area,
          CASE p.ds_categoria WHEN 'CRIANCA' THEN 1 WHEN 'JOVEM' THEN 2 ELSE 3 END;

-- ---------------------------------------------------------------------
-- Consulta 3 (extra) - Cobertura de conteúdo por área
-- Pergunta da solução: "Alguma área está sem perguntas para algum público?"
-- LEFT JOIN mantém áreas sem perguntas no resultado (contagem zero).
-- ---------------------------------------------------------------------
SELECT a.nm_area                                                    AS area,
       COUNT(CASE WHEN p.ds_categoria = 'CRIANCA' THEN 1 END)      AS qt_crianca,
       COUNT(CASE WHEN p.ds_categoria = 'JOVEM'   THEN 1 END)      AS qt_jovem,
       COUNT(CASE WHEN p.ds_categoria = 'ADULTO'  THEN 1 END)      AS qt_adulto,
       COUNT(p.id_pergunta)                                         AS qt_total
  FROM tb_area_aplicacao a
  LEFT JOIN tb_pergunta p
         ON p.id_area  = a.id_area
        AND p.st_ativa = 'S'
 GROUP BY a.nm_area
 ORDER BY qt_total DESC, a.nm_area;

-- ---------------------------------------------------------------------
-- Conferência rápida da carga (5+ registros por tabela)
-- ---------------------------------------------------------------------
SELECT 'TB_USUARIO'        AS tabela, COUNT(*) AS registros FROM tb_usuario
UNION ALL SELECT 'TB_AREA_APLICACAO', COUNT(*) FROM tb_area_aplicacao
UNION ALL SELECT 'TB_PERGUNTA',       COUNT(*) FROM tb_pergunta
UNION ALL SELECT 'TB_ALTERNATIVA',    COUNT(*) FROM tb_alternativa
UNION ALL SELECT 'TB_TENTATIVA_QUIZ', COUNT(*) FROM tb_tentativa_quiz;

/* =====================================================================
   FIM DO SCRIPT
   Sprint 2 (2º semestre): procedures de CRUD com tratamento de
   exceções, functions com cursor (ex.: FN_PONTUACAO, FN_RANKING) e
   integração com as APIs Java e .NET.
   ===================================================================== */
