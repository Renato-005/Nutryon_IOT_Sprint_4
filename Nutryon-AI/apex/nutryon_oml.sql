-- ============================================================
-- NUTRYON – INTEGRAÇÃO ORACLE MACHINE LEARNING (OML)
-- Algoritmo: Apriori (Association Rules)
-- Disciplina: Disruptive Architectures: IoT, IoB & Generative IA
-- FIAP – 2025
-- ============================================================
-- PRE-REQUISITO: banco populado com nutryon_mvp_completo.sql
-- Requer DBMS_DATA_MINING disponivel no schema
-- Oracle Database 12c ou superior
-- ============================================================


-- ============================================================
-- BLOCO 1 – VIEW TRANSACIONAL
-- Transforma o historico no formato esperado pelo Apriori:
-- CASE_ID = ID da refeicao (transacao)
-- ITEM_ID = nome do ingrediente (item)
-- ============================================================

CREATE OR REPLACE VIEW VW_OML_TRANSACOES AS
SELECT
    r.ID_REFEICAO     AS CASE_ID,
    i.NOM_INGREDIENTE AS ITEM_ID
FROM REFEICAO r
JOIN REFEICAO_ITEM ri ON ri.ID_REFEICAO   = r.ID_REFEICAO
JOIN INGREDIENTE   i  ON i.ID_INGREDIENTE = ri.ID_INGREDIENTE


-- Verificar se a view esta correta
SELECT * FROM VW_OML_TRANSACOES ORDER BY CASE_ID


-- ============================================================
-- BLOCO 2 – TABELA DE PARAMETROS DO MODELO
-- ============================================================

CREATE TABLE TB_OML_PARAMS (
    SETTING_NAME  VARCHAR2(30),
    SETTING_VALUE VARCHAR2(128)
)

INSERT ALL
    INTO TB_OML_PARAMS VALUES ('ALGO_NAME',          'ALGO_APRIORI_ASSOCIATION_RULES')
    INTO TB_OML_PARAMS VALUES ('ASSO_MIN_SUPPORT',    '0.1')
    INTO TB_OML_PARAMS VALUES ('ASSO_MIN_CONFIDENCE', '0.6')
SELECT 1 FROM DUAL

COMMIT


-- ============================================================
-- BLOCO 3 – TREINAMENTO DO MODELO OML
-- Requer DBMS_DATA_MINING disponivel no schema
-- Execute no SQL Developer com SERVEROUTPUT ON
-- ============================================================

-- BEGIN
--   BEGIN
--     DBMS_DATA_MINING.DROP_MODEL('MDL_NUTRYON_ASSOC');
--   EXCEPTION WHEN OTHERS THEN NULL;
--   END;
--   DBMS_DATA_MINING.CREATE_MODEL(
--     model_name          => 'MDL_NUTRYON_ASSOC',
--     mining_function     => DBMS_DATA_MINING.ASSOCIATION,
--     data_table_name     => 'VW_OML_TRANSACOES',
--     case_id_column_name => 'CASE_ID',
--     target_column_name  => NULL,
--     settings_table_name => 'TB_OML_PARAMS'
--   );
--   DBMS_OUTPUT.PUT_LINE('Modelo criado com sucesso.');
-- END;


-- ============================================================
-- BLOCO 4 – CONSULTAR REGRAS DO MODELO
-- Execute apos o treinamento
-- ============================================================

-- SELECT
--     antecedent_item_name        AS "Se consumir",
--     consequent_item_name        AS "Sistema sugere",
--     ROUND(confidence * 100, 1)  AS "Confianca %",
--     ROUND(support  * 100, 1)    AS "Suporte %",
--     ROUND(lift, 2)              AS "Lift"
-- FROM TABLE(
--     DBMS_DATA_MINING.GET_ASSOCIATION_RULES('MDL_NUTRYON_ASSOC')
-- )
-- WHERE confidence >= 0.6 AND lift > 1
-- ORDER BY confidence DESC


-- ============================================================
-- BLOCO 5 – VIEW DE SUGESTOES COM DBMS_DATA_MINING
-- Versao completa que usa as regras do modelo treinado
-- ============================================================

-- CREATE OR REPLACE VIEW VW_SUGESTOES_OML AS
-- SELECT
--     a.antecedent_item_name         AS ALIMENTO_BASE,
--     a.consequent_item_name         AS ALIMENTO_SUGERIDO,
--     ROUND(a.confidence * 100, 1)   AS CONFIANCA_PCT,
--     ROUND(a.lift, 2)               AS RELEVANCIA,
--     NVL(i.KCAL_100G, 0)            AS KCAL_100G,
--     NVL(i.PROT_100G, 0)            AS PROTEINAS_100G,
--     NVL(i.CARB_100G, 0)            AS CARBOIDRATOS_100G,
--     NVL(i.GORD_100G, 0)            AS GORDURAS_100G
-- FROM TABLE(
--     DBMS_DATA_MINING.GET_ASSOCIATION_RULES('MDL_NUTRYON_ASSOC')
-- ) a
-- LEFT JOIN INGREDIENTE i ON i.NOM_INGREDIENTE = a.consequent_item_name
-- WHERE a.confidence >= 0.6 AND a.lift > 1
-- ORDER BY a.confidence DESC


-- ============================================================
-- BLOCO 6 – VIEW DE SUGESTOES ALTERNATIVA (SQL analitico)
-- Funciona sem DBMS_DATA_MINING
-- Esta e a versao implementada no MVP do Oracle APEX
-- ============================================================

CREATE OR REPLACE VIEW VW_SUGESTOES_REFEICAO AS
SELECT
    t.NOM_TIPO                                                                 AS TIPO_REFEICAO,
    i.NOM_INGREDIENTE                                                          AS ALIMENTO_SUGERIDO,
    COUNT(*)                                                                   AS FREQUENCIA,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY t.NOM_TIPO), 1) AS CONFIANCA_PCT,
    i.KCAL_100G,
    i.PROT_100G                                                                AS PROTEINAS_100G,
    i.CARB_100G                                                                AS CARBOIDRATOS_100G,
    i.GORD_100G                                                                AS GORDURAS_100G
FROM REFEICAO r
JOIN TIPO_REFEICAO t  ON t.ID_TIPO_REFEICAO = r.ID_TIPO_REFEICAO
JOIN REFEICAO_ITEM ri ON ri.ID_REFEICAO     = r.ID_REFEICAO
JOIN INGREDIENTE   i  ON i.ID_INGREDIENTE   = ri.ID_INGREDIENTE
GROUP BY t.NOM_TIPO, i.NOM_INGREDIENTE,
         i.KCAL_100G, i.PROT_100G, i.CARB_100G, i.GORD_100G
ORDER BY t.NOM_TIPO, FREQUENCIA DESC


-- Teste da view
SELECT TIPO_REFEICAO, ALIMENTO_SUGERIDO,
       CONFIANCA_PCT || '%' AS CONFIANCA,
       KCAL_100G, PROTEINAS_100G
FROM VW_SUGESTOES_REFEICAO


-- ============================================================
-- BLOCO 7 – JOB DE RE-TREINAMENTO SEMANAL
-- Todo domingo as 3h — requer DBMS_SCHEDULER
-- ============================================================

-- CREATE OR REPLACE PROCEDURE PRC_TREINAR_OML_NUTRYON AS
-- BEGIN
--   BEGIN
--     DBMS_DATA_MINING.DROP_MODEL('MDL_NUTRYON_ASSOC');
--   EXCEPTION WHEN OTHERS THEN NULL;
--   END;
--   DBMS_DATA_MINING.CREATE_MODEL(
--     model_name          => 'MDL_NUTRYON_ASSOC',
--     mining_function     => DBMS_DATA_MINING.ASSOCIATION,
--     data_table_name     => 'VW_OML_TRANSACOES',
--     case_id_column_name => 'CASE_ID',
--     target_column_name  => NULL,
--     settings_table_name => 'TB_OML_PARAMS'
--   );
-- END;

-- BEGIN
--   DBMS_SCHEDULER.CREATE_JOB(
--     job_name        => 'JOB_TREINAR_OML_NUTRYON',
--     job_type        => 'PLSQL_BLOCK',
--     job_action      => 'BEGIN PRC_TREINAR_OML_NUTRYON; END;',
--     start_date      => SYSTIMESTAMP,
--     repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=3; BYMINUTE=0',
--     enabled         => TRUE
--   );
-- END;


-- ============================================================
-- BLOCO 8 – DEMOS PARA O VIDEO
-- Execute cada SELECT separadamente durante a gravacao
-- ============================================================

-- DEMO 1: Historico completo com macros calculados
SELECT u.NOM_USUARIO,
       t.NOM_TIPO                                AS TIPO_REFEICAO,
       i.NOM_INGREDIENTE,
       ri.QTDE_G,
       ROUND(i.KCAL_100G * ri.QTDE_G / 100, 1)  AS KCAL,
       ROUND(i.PROT_100G * ri.QTDE_G / 100, 1)  AS PROTEINA_G
FROM REFEICAO r
JOIN USUARIO       u  ON u.ID_USUARIO       = r.ID_USUARIO
JOIN TIPO_REFEICAO t  ON t.ID_TIPO_REFEICAO = r.ID_TIPO_REFEICAO
JOIN REFEICAO_ITEM ri ON ri.ID_REFEICAO     = r.ID_REFEICAO
JOIN INGREDIENTE   i  ON i.ID_INGREDIENTE   = ri.ID_INGREDIENTE
ORDER BY r.DT_REF


-- DEMO 2: View transacional — entrada do modelo
SELECT * FROM VW_OML_TRANSACOES ORDER BY CASE_ID


-- DEMO 3: Dashboard — consumo vs meta
SELECT NOM_USUARIO, OBJETIVO, META_KCAL,
       KCAL_CONSUMIDA, KCAL_RESTANTE,
       PCT_META || '%' AS PROGRESSO
FROM VW_DASHBOARD_USUARIO


-- DEMO 4: Sugestoes IA filtradas por almoco
SELECT TIPO_REFEICAO, ALIMENTO_SUGERIDO,
       CONFIANCA_PCT || '%' AS CONFIANCA,
       KCAL_100G
FROM VW_SUGESTOES_REFEICAO
WHERE TIPO_REFEICAO = 'ALMOCO'
