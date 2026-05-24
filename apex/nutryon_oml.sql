-- ============================================================
-- NUTRYON - ORACLE MACHINE LEARNING
-- Algoritmo: Apriori / Association Rules
--
-- Objetivo:
-- Preparar a entrada do modelo e o procedimento de treinamento OML.
--
-- Execute depois de:
-- 1. sql/nutryon_mvp.sql
-- 2. sql/dados_treinamento_ia.sql
--
-- Observacao:
-- O treinamento depende da permissao ao pacote DBMS_DATA_MINING.
-- Caso o ambiente APEX nao libere esse pacote, use o fallback funcional
-- ja criado em VW_SUGESTOES_REFEICAO.
-- ============================================================

CREATE OR REPLACE VIEW VW_OML_TRANSACOES AS
SELECT
    r.ID_REFEICAO AS CASE_ID,
    i.NOM_INGREDIENTE AS ITEM_ID
FROM REFEICAO r
JOIN REFEICAO_ITEM ri ON ri.ID_REFEICAO = r.ID_REFEICAO
JOIN INGREDIENTE i ON i.ID_INGREDIENTE = ri.ID_INGREDIENTE;

BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE TB_OML_PARAMS PURGE';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -942 THEN
                RAISE;
            END IF;
    END;

    EXECUTE IMMEDIATE '
        CREATE TABLE TB_OML_PARAMS (
            SETTING_NAME  VARCHAR2(30),
            SETTING_VALUE VARCHAR2(128)
        )';

    INSERT INTO TB_OML_PARAMS (SETTING_NAME, SETTING_VALUE)
    VALUES ('ALGO_NAME', 'ALGO_APRIORI_ASSOCIATION_RULES');

    INSERT INTO TB_OML_PARAMS (SETTING_NAME, SETTING_VALUE)
    VALUES ('ASSO_MIN_SUPPORT', '0.1');

    INSERT INTO TB_OML_PARAMS (SETTING_NAME, SETTING_VALUE)
    VALUES ('ASSO_MIN_CONFIDENCE', '0.6');

    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE PRC_TREINAR_OML_NUTRYON AS
BEGIN
    EXECUTE IMMEDIATE q'[
        BEGIN
            BEGIN
                DBMS_DATA_MINING.DROP_MODEL('MDL_NUTRYON_ASSOC');
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;

            DBMS_DATA_MINING.CREATE_MODEL(
                model_name          => 'MDL_NUTRYON_ASSOC',
                mining_function     => DBMS_DATA_MINING.ASSOCIATION,
                data_table_name     => 'VW_OML_TRANSACOES',
                case_id_column_name => 'CASE_ID',
                target_column_name  => NULL,
                settings_table_name => 'TB_OML_PARAMS'
            );
        END;
    ]';
END;
/

-- Testes manuais para evidencia:
SELECT * FROM VW_OML_TRANSACOES ORDER BY CASE_ID;

SELECT SETTING_NAME,
       SETTING_VALUE
FROM TB_OML_PARAMS;
