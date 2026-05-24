-- ============================================================
-- NUTRYON - SERVICO DE IA PARA ORACLE APEX
-- Objetivo: expor as sugestoes da IA para paginas APEX.
--
-- Pre-requisito:
-- 1. Executar sql/nutryon_mvp.sql para criar tabelas, dados e views.
-- 2. Opcional: executar apex/nutryon_oml.sql se o schema tiver OML.
--
-- Uso no APEX:
-- SELECT PKG_NUTRYON_IA.SUGERIR_INGREDIENTES_JSON('ALMOCO', 5) AS JSON
-- FROM DUAL;
--
-- Alternativa para Interactive Report:
-- SELECT *
-- FROM VW_SUGESTOES_REFEICAO
-- WHERE TIPO_REFEICAO = :P_TIPO_REFEICAO
-- ORDER BY CONFIANCA_PCT DESC, FREQUENCIA DESC;
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_NUTRYON_IA AS
    FUNCTION SUGERIR_INGREDIENTES_JSON (
        p_tipo_refeicao IN VARCHAR2,
        p_limite        IN NUMBER DEFAULT 5
    ) RETURN CLOB;
END PKG_NUTRYON_IA;
/

CREATE OR REPLACE PACKAGE BODY PKG_NUTRYON_IA AS
    FUNCTION SUGERIR_INGREDIENTES_JSON (
        p_tipo_refeicao IN VARCHAR2,
        p_limite        IN NUMBER DEFAULT 5
    ) RETURN CLOB IS
        v_json CLOB;
    BEGIN
        SELECT JSON_ARRAYAGG(
                   JSON_OBJECT(
                       'tipo_refeicao'      VALUE TIPO_REFEICAO,
                       'alimento_sugerido'  VALUE ALIMENTO_SUGERIDO,
                       'frequencia'         VALUE FREQUENCIA,
                       'confianca_pct'      VALUE CONFIANCA_PCT,
                       'kcal_100g'          VALUE KCAL_100G,
                       'proteinas_100g'     VALUE PROTEINAS_100G,
                       'carboidratos_100g'  VALUE CARBOIDRATOS_100G,
                       'gorduras_100g'      VALUE GORDURAS_100G
                       RETURNING CLOB
                   )
                   RETURNING CLOB
               )
          INTO v_json
          FROM (
                SELECT *
                  FROM (
                        SELECT TIPO_REFEICAO,
                               ALIMENTO_SUGERIDO,
                               FREQUENCIA,
                               CONFIANCA_PCT,
                               KCAL_100G,
                               PROTEINAS_100G,
                               CARBOIDRATOS_100G,
                               GORDURAS_100G
                          FROM VW_SUGESTOES_REFEICAO
                         WHERE p_tipo_refeicao IS NULL
                            OR UPPER(TIPO_REFEICAO) = UPPER(p_tipo_refeicao)
                         ORDER BY CONFIANCA_PCT DESC, FREQUENCIA DESC
                       )
                 WHERE ROWNUM <= NVL(p_limite, 5)
               );

        RETURN NVL(v_json, '[]');
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '{"erro":"' || REPLACE(SQLERRM, '"', '''') || '"}';
    END SUGERIR_INGREDIENTES_JSON;
END PKG_NUTRYON_IA;
/

-- ============================================================
-- TESTES MANUAIS PARA EVIDENCIA DA ENTREGA
-- ============================================================

SELECT PKG_NUTRYON_IA.SUGERIR_INGREDIENTES_JSON('ALMOCO', 5) AS SUGESTOES_JSON
FROM DUAL;

SELECT PKG_NUTRYON_IA.SUGERIR_INGREDIENTES_JSON(NULL, 10) AS SUGESTOES_GERAIS_JSON
FROM DUAL;
