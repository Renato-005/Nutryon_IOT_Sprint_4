-- ============================================================
-- NUTRYON - RUNTIME FUNCIONAL PARA ORACLE APEX
-- Execute depois de:
-- 1. sql/nutryon_mvp.sql
-- 2. sql/dados_treinamento_ia.sql
-- 3. apex/nutryon_ai_service.sql
--
-- Objetivo:
-- Fazer o APEX se comportar como app real:
-- - selecionar usuario
-- - montar refeicao
-- - adicionar e remover varios alimentos na mesma refeicao
-- - atualizar dashboard
-- - sugerir alimentos por tipo de refeicao
-- ============================================================

CREATE OR REPLACE VIEW VW_APP_USUARIOS_LOV AS
SELECT
    ID_USUARIO AS RETURN_VALUE,
    NOM_USUARIO AS DISPLAY_VALUE
FROM USUARIO
ORDER BY NOM_USUARIO;

CREATE OR REPLACE VIEW VW_APP_TIPOS_REFEICAO_LOV AS
SELECT
    ID_TIPO_REFEICAO AS RETURN_VALUE,
    NOM_TIPO AS DISPLAY_VALUE
FROM TIPO_REFEICAO
ORDER BY ID_TIPO_REFEICAO;

CREATE OR REPLACE VIEW VW_APP_INGREDIENTES_LOV AS
SELECT
    ID_INGREDIENTE AS RETURN_VALUE,
    NOM_INGREDIENTE || ' - ' || KCAL_100G || ' kcal/100g' AS DISPLAY_VALUE
FROM INGREDIENTE
ORDER BY NOM_INGREDIENTE;

CREATE OR REPLACE VIEW VW_APP_SUGESTOES_POR_TIPO AS
SELECT
    t.ID_TIPO_REFEICAO,
    s.TIPO_REFEICAO,
    i.ID_INGREDIENTE,
    s.ALIMENTO_SUGERIDO,
    s.FREQUENCIA,
    s.CONFIANCA_PCT,
    s.KCAL_100G,
    s.PROTEINAS_100G,
    s.CARBOIDRATOS_100G,
    s.GORDURAS_100G,
    CASE
        WHEN s.CONFIANCA_PCT >= 50 THEN 'Sugestao forte para este tipo de refeicao'
        WHEN s.CONFIANCA_PCT >= 25 THEN 'Boa combinacao pelo historico'
        ELSE 'Opcao complementar'
    END AS INSIGHT
FROM VW_SUGESTOES_REFEICAO s
JOIN TIPO_REFEICAO t ON t.NOM_TIPO = s.TIPO_REFEICAO
JOIN INGREDIENTE i ON i.NOM_INGREDIENTE = s.ALIMENTO_SUGERIDO;

CREATE OR REPLACE VIEW VW_APP_DASHBOARD_DETALHADO AS
SELECT
    d.ID_USUARIO,
    d.NOM_USUARIO,
    d.OBJETIVO,
    d.META_KCAL,
    d.KCAL_CONSUMIDA,
    d.KCAL_RESTANTE,
    d.PROT_CONSUMIDA,
    d.CARB_CONSUMIDA,
    d.GORD_CONSUMIDA,
    d.PCT_META,
    u.META_PROT,
    u.META_CARB,
    u.META_GORD,
    ROUND(d.PROT_CONSUMIDA / NULLIF(u.META_PROT, 0) * 100, 1) AS PCT_PROT,
    ROUND(d.CARB_CONSUMIDA / NULLIF(u.META_CARB, 0) * 100, 1) AS PCT_CARB,
    ROUND(d.GORD_CONSUMIDA / NULLIF(u.META_GORD, 0) * 100, 1) AS PCT_GORD
FROM VW_DASHBOARD_USUARIO d
JOIN USUARIO u ON u.ID_USUARIO = d.ID_USUARIO;

CREATE OR REPLACE VIEW VW_APP_ITENS_REFEICAO_ATUAL AS
SELECT
    ri.ID_ITEM,
    ri.ID_REFEICAO,
    i.NOM_INGREDIENTE,
    ri.QTDE_G,
    ROUND(i.KCAL_100G * ri.QTDE_G / 100, 1) AS KCAL,
    ROUND(i.PROT_100G * ri.QTDE_G / 100, 1) AS PROTEINA_G,
    ROUND(i.CARB_100G * ri.QTDE_G / 100, 1) AS CARBO_G,
    ROUND(i.GORD_100G * ri.QTDE_G / 100, 1) AS GORDURA_G
FROM REFEICAO_ITEM ri
JOIN INGREDIENTE i ON i.ID_INGREDIENTE = ri.ID_INGREDIENTE;

CREATE OR REPLACE VIEW VW_APP_TOTAL_REFEICAO AS
SELECT
    r.ID_REFEICAO,
    u.ID_USUARIO,
    u.NOM_USUARIO,
    t.NOM_TIPO AS TIPO_REFEICAO,
    r.OBS,
    TO_CHAR(r.DT_REF, 'DD/MM/YYYY HH24:MI') AS DATA_HORA,
    ROUND(NVL(SUM(i.KCAL_100G * ri.QTDE_G / 100), 0), 1) AS KCAL_TOTAL,
    ROUND(NVL(SUM(i.PROT_100G * ri.QTDE_G / 100), 0), 1) AS PROTEINA_TOTAL_G,
    ROUND(NVL(SUM(i.CARB_100G * ri.QTDE_G / 100), 0), 1) AS CARBO_TOTAL_G,
    ROUND(NVL(SUM(i.GORD_100G * ri.QTDE_G / 100), 0), 1) AS GORDURA_TOTAL_G,
    COUNT(ri.ID_ITEM) AS TOTAL_ITENS
FROM REFEICAO r
JOIN USUARIO u ON u.ID_USUARIO = r.ID_USUARIO
JOIN TIPO_REFEICAO t ON t.ID_TIPO_REFEICAO = r.ID_TIPO_REFEICAO
LEFT JOIN REFEICAO_ITEM ri ON ri.ID_REFEICAO = r.ID_REFEICAO
LEFT JOIN INGREDIENTE i ON i.ID_INGREDIENTE = ri.ID_INGREDIENTE
GROUP BY r.ID_REFEICAO, u.ID_USUARIO, u.NOM_USUARIO, t.NOM_TIPO, r.OBS, r.DT_REF;

CREATE OR REPLACE PACKAGE PKG_NUTRYON_APP AS
    PROCEDURE CRIAR_REFEICAO (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_refeicao      OUT NUMBER
    );

    PROCEDURE ADICIONAR_ITEM (
        p_id_refeicao    IN NUMBER,
        p_id_ingrediente IN NUMBER,
        p_qtde_g         IN NUMBER
    );

END PKG_NUTRYON_APP;
/

CREATE OR REPLACE PACKAGE BODY PKG_NUTRYON_APP AS
    PROCEDURE CRIAR_REFEICAO (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_refeicao      OUT NUMBER
    ) IS
    BEGIN
        IF p_id_usuario IS NULL THEN
            RAISE_APPLICATION_ERROR(-20701, 'Selecione um usuario.');
        END IF;

        IF p_id_tipo_refeicao IS NULL THEN
            RAISE_APPLICATION_ERROR(-20702, 'Selecione o tipo de refeicao.');
        END IF;

        INSERT INTO REFEICAO (
            ID_USUARIO,
            DT_REF,
            ID_TIPO_REFEICAO,
            OBS
        ) VALUES (
            p_id_usuario,
            SYSDATE,
            p_id_tipo_refeicao,
            NVL(p_obs, 'Refeicao registrada pelo APEX')
        )
        RETURNING ID_REFEICAO INTO p_id_refeicao;
    END CRIAR_REFEICAO;

    PROCEDURE ADICIONAR_ITEM (
        p_id_refeicao    IN NUMBER,
        p_id_ingrediente IN NUMBER,
        p_qtde_g         IN NUMBER
    ) IS
    BEGIN
        IF p_id_refeicao IS NULL THEN
            RAISE_APPLICATION_ERROR(-20703, 'Selecione uma refeicao.');
        END IF;

        IF p_id_ingrediente IS NULL THEN
            RAISE_APPLICATION_ERROR(-20704, 'Selecione um ingrediente.');
        END IF;

        IF NVL(p_qtde_g, 0) <= 0 THEN
            RAISE_APPLICATION_ERROR(-20705, 'Informe uma quantidade em gramas maior que zero.');
        END IF;

        INSERT INTO REFEICAO_ITEM (
            ID_REFEICAO,
            ID_INGREDIENTE,
            QTDE_G
        ) VALUES (
            p_id_refeicao,
            p_id_ingrediente,
            p_qtde_g
        );
    END ADICIONAR_ITEM;

END PKG_NUTRYON_APP;
/

CREATE OR REPLACE PACKAGE PKG_NUTRYON_MULTI_ITEM AS
    PROCEDURE CRIAR_REFEICAO_SE_NECESSARIO (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_refeicao      IN OUT NUMBER
    );

    PROCEDURE ADICIONAR_ITEM_ATUAL (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_ingrediente   IN NUMBER,
        p_qtde_g           IN NUMBER,
        p_id_refeicao      IN OUT NUMBER
    );

    PROCEDURE REMOVER_ITEM (
        p_id_item IN NUMBER
    );
END PKG_NUTRYON_MULTI_ITEM;
/

CREATE OR REPLACE PACKAGE BODY PKG_NUTRYON_MULTI_ITEM AS
    PROCEDURE CRIAR_REFEICAO_SE_NECESSARIO (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_refeicao      IN OUT NUMBER
    ) IS
    BEGIN
        IF p_id_refeicao IS NOT NULL THEN
            RETURN;
        END IF;

        PKG_NUTRYON_APP.CRIAR_REFEICAO(
            p_id_usuario       => p_id_usuario,
            p_id_tipo_refeicao => p_id_tipo_refeicao,
            p_obs              => p_obs,
            p_id_refeicao      => p_id_refeicao
        );
    END CRIAR_REFEICAO_SE_NECESSARIO;

    PROCEDURE ADICIONAR_ITEM_ATUAL (
        p_id_usuario       IN NUMBER,
        p_id_tipo_refeicao IN NUMBER,
        p_obs              IN VARCHAR2,
        p_id_ingrediente   IN NUMBER,
        p_qtde_g           IN NUMBER,
        p_id_refeicao      IN OUT NUMBER
    ) IS
    BEGIN
        CRIAR_REFEICAO_SE_NECESSARIO(
            p_id_usuario       => p_id_usuario,
            p_id_tipo_refeicao => p_id_tipo_refeicao,
            p_obs              => p_obs,
            p_id_refeicao      => p_id_refeicao
        );

        PKG_NUTRYON_APP.ADICIONAR_ITEM(
            p_id_refeicao    => p_id_refeicao,
            p_id_ingrediente => p_id_ingrediente,
            p_qtde_g         => p_qtde_g
        );

        COMMIT;
    END ADICIONAR_ITEM_ATUAL;

    PROCEDURE REMOVER_ITEM (
        p_id_item IN NUMBER
    ) IS
    BEGIN
        DELETE FROM REFEICAO_ITEM
         WHERE ID_ITEM = p_id_item;

        COMMIT;
    END REMOVER_ITEM;
END PKG_NUTRYON_MULTI_ITEM;
/

-- ============================================================
-- TESTES MANUAIS
-- ============================================================

SELECT * FROM VW_APP_USUARIOS_LOV;
SELECT * FROM VW_APP_TIPOS_REFEICAO_LOV;
SELECT * FROM VW_APP_INGREDIENTES_LOV;
SELECT * FROM VW_APP_SUGESTOES_POR_TIPO;
SELECT * FROM VW_APP_DASHBOARD_DETALHADO;
SELECT * FROM VW_APP_ITENS_REFEICAO_ATUAL;
SELECT * FROM VW_APP_TOTAL_REFEICAO;
