# Setup funcional do app Nutryon no APEX

Este guia monta o Nutryon como aplicacao de verdade no APEX, nao apenas tabelas:

- escolher usuario
- montar refeicao
- adicionar alimento e quantidade
- atualizar dashboard
- ver sugestoes de IA por tipo de refeicao

## 1. Scripts obrigatorios

Execute no `SQL Workshop > SQL Commands`, nesta ordem:

1. `sql/nutryon_mvp.sql`
2. `sql/dados_treinamento_ia.sql`
3. `apex/nutryon_ai_service.sql`
4. `apex/nutryon_app_runtime.sql`

O script `sql/dados_treinamento_ia.sql` tambem inclui o catalogo expandido de alimentos. O script `apex/nutryon_app_runtime.sql` concentra as views, LOVs e packages usadas pelas paginas do APEX.

Teste rapido:

```sql
SELECT * FROM VW_APP_USUARIOS_LOV;
SELECT * FROM VW_APP_TIPOS_REFEICAO_LOV;
SELECT * FROM VW_APP_INGREDIENTES_LOV;
SELECT * FROM VW_APP_SUGESTOES_POR_TIPO;

SELECT PKG_NUTRYON_IA.SUGERIR_INGREDIENTES_JSON('ALMOCO', 5)
FROM DUAL;
```

## 2. Pagina Dashboard

Use uma pagina `Blank`, por exemplo pagina 4.

### Item: usuario ativo

Crie um item:

- Name: `P4_ID_USUARIO`
- Type: `Select List`
- List of Values Type: `SQL Query`
- SQL:

```sql
SELECT DISPLAY_VALUE d,
       RETURN_VALUE r
FROM VW_APP_USUARIOS_LOV
```

Em `Default`, coloque:

```sql
SELECT MIN(ID_USUARIO) FROM USUARIO
```

### Regiao: KPIs do dia

Tipo: `Cards`

SQL:

```sql
SELECT 'Calorias' AS TITULO,
       KCAL_CONSUMIDA || ' / ' || META_KCAL || ' kcal' AS SUBTITULO,
       PCT_META || '% da meta' AS TEXTO
FROM VW_APP_DASHBOARD_DETALHADO
WHERE ID_USUARIO = :P4_ID_USUARIO
UNION ALL
SELECT 'Proteinas',
       PROT_CONSUMIDA || ' / ' || META_PROT || 'g',
       PCT_PROT || '% da meta'
FROM VW_APP_DASHBOARD_DETALHADO
WHERE ID_USUARIO = :P4_ID_USUARIO
UNION ALL
SELECT 'Carboidratos',
       CARB_CONSUMIDA || ' / ' || META_CARB || 'g',
       PCT_CARB || '% da meta'
FROM VW_APP_DASHBOARD_DETALHADO
WHERE ID_USUARIO = :P4_ID_USUARIO
UNION ALL
SELECT 'Gorduras',
       GORD_CONSUMIDA || ' / ' || META_GORD || 'g',
       PCT_GORD || '% da meta'
FROM VW_APP_DASHBOARD_DETALHADO
WHERE ID_USUARIO = :P4_ID_USUARIO
```

Mapeamento:

- Title Column: `TITULO`
- Subtitle Column: `SUBTITULO`
- Body Column: `TEXTO`

### Dynamic Action

No item `P4_ID_USUARIO`, crie uma Dynamic Action:

- Event: `Change`
- True Action: `Refresh`
- Selection Type: `Region`
- Region: KPIs do dia

Assim, trocar o usuario atualiza o dashboard.

## 3. Pagina Montar Refeicao

Crie a pagina `Blank` numero 3, chamada `Montar Refeicao`. O fluxo implementado permite varios alimentos na mesma refeicao:

1. Usuario escolhe usuario, tipo e observacao.
2. Usuario escolhe ingrediente e quantidade.
3. Clica em `Adicionar alimento`.
4. O alimento entra em uma lista da refeicao atual.
5. Usuario repete o processo quantas vezes quiser.
6. Ao final, volta ao Dashboard.

### Itens necessarios

Crie os itens:

| Item | Tipo |
|---|---|
| `P3_ID_USUARIO` | Select List |
| `P3_ID_TIPO_REFEICAO` | Select List |
| `P3_OBS` | Text Field |
| `P3_ID_INGREDIENTE` | Select List |
| `P3_QTDE_G` | Number Field |
| `P3_ID_REFEICAO` | Hidden |
| `P3_ID_ITEM_REMOVER` | Hidden |

### Botao: Adicionar alimento

Troque o botao principal para:

- Name: `ADICIONAR_ALIMENTO`
- Label: `Adicionar alimento`
- Action: `Submit Page`

Crie ou substitua o processo PL/SQL por:

```sql
BEGIN
    PKG_NUTRYON_MULTI_ITEM.ADICIONAR_ITEM_ATUAL(
        p_id_usuario       => :P3_ID_USUARIO,
        p_id_tipo_refeicao => :P3_ID_TIPO_REFEICAO,
        p_obs              => :P3_OBS,
        p_id_ingrediente   => :P3_ID_INGREDIENTE,
        p_qtde_g           => :P3_QTDE_G,
        p_id_refeicao      => :P3_ID_REFEICAO
    );
END;
```

Condicao do processo:

- When Button Pressed: `ADICIONAR_ALIMENTO`

Importante: remova a Branch que volta automaticamente para o Dashboard nesse botao. Assim a pessoa consegue adicionar mais alimentos na mesma refeicao.

### Regiao: alimentos da refeicao atual

Crie uma regiao `Classic Report` ou `Interactive Report` chamada `Alimentos desta refeicao`.

SQL:

```sql
SELECT ID_ITEM,
       NOM_INGREDIENTE,
       QTDE_G,
       KCAL,
       PROTEINA_G,
       CARBO_G,
       GORDURA_G,
       'Remover' AS REMOVER
FROM VW_APP_ITENS_REFEICAO_ATUAL
WHERE ID_REFEICAO = :P3_ID_REFEICAO
ORDER BY ID_ITEM
```

Em `Page Items to Submit`, coloque:

```text
P3_ID_REFEICAO
```

Configure as colunas:

- `ID_ITEM`: tipo `Hidden Column`, para nao aparecer para o usuario.
- `REMOVER`: tipo `Link`, para excluir o item da refeicao.

No link da coluna `REMOVER`, use:

- Target Type: `Page in this application`
- Page: `3`
- Set Items:
  - `P3_ID_ITEM_REMOVER` = `#ID_ITEM#`
  - `P3_ID_REFEICAO` = `&P3_ID_REFEICAO.`
- Request: `REMOVER_ITEM`
- Clear Cache: vazio
- Link Text: pode ser `Remover`, `Excluir` ou um icone de lixeira.

Crie um processo para remover o item:

- Name: `Remover item da refeicao`
- Type: `Execute Code`
- Language: `PL/SQL`
- Execution Point: `Before Header`
- Server-side Condition:
  - Type: `Request = Value`
  - Value: `REMOVER_ITEM`

Codigo:

```sql
BEGIN
    PKG_NUTRYON_MULTI_ITEM.REMOVER_ITEM(:P3_ID_ITEM_REMOVER);
END;
```

Por que precisa ser `Before Header`: o link do relatorio nao funciona como um botao de submit. Ele recarrega a pagina com o request `REMOVER_ITEM`. Assim, o processo precisa rodar antes da pagina ser renderizada de novo.

### Regiao: total da refeicao

Crie uma regiao `Cards` chamada `Total da refeicao`.

SQL:

```sql
SELECT 'Calorias' AS TITULO,
       KCAL_TOTAL || ' kcal' AS SUBTITULO,
       TOTAL_ITENS || ' alimento(s)' AS TEXTO
FROM VW_APP_TOTAL_REFEICAO
WHERE ID_REFEICAO = :P3_ID_REFEICAO
UNION ALL
SELECT 'Proteinas',
       PROTEINA_TOTAL_G || 'g',
       'Total da refeicao'
FROM VW_APP_TOTAL_REFEICAO
WHERE ID_REFEICAO = :P3_ID_REFEICAO
UNION ALL
SELECT 'Carboidratos',
       CARBO_TOTAL_G || 'g',
       'Total da refeicao'
FROM VW_APP_TOTAL_REFEICAO
WHERE ID_REFEICAO = :P3_ID_REFEICAO
UNION ALL
SELECT 'Gorduras',
       GORDURA_TOTAL_G || 'g',
       'Total da refeicao'
FROM VW_APP_TOTAL_REFEICAO
WHERE ID_REFEICAO = :P3_ID_REFEICAO
```

Mapeamento:

- Title Column: `TITULO`
- Subtitle Column: `SUBTITULO`
- Body Column: `TEXTO`

Em `Page Items to Submit`, coloque:

```text
P3_ID_REFEICAO
```

### Botao: Finalizar refeicao

Crie outro botao:

- Name: `FINALIZAR_REFEICAO`
- Label: `Finalizar refeicao`
- Action: `Submit Page`

Crie uma Branch:

- When Button Pressed: `FINALIZAR_REFEICAO`
- Target Page: Dashboard

Resultado: agora uma refeicao pode ter banana + leite + aveia, ou arroz + feijao + frango + brocolis, e o Dashboard soma tudo.

## 4. Pagina Sugestoes IA

Crie uma pagina `Blank`, por exemplo pagina 8, chamada `Sugestoes IA`.

### Item: tipo de refeicao

Crie:

- Name: `P8_ID_TIPO_REFEICAO`
- Type: `Select List`
- LOV:

```sql
SELECT DISPLAY_VALUE d,
       RETURN_VALUE r
FROM VW_APP_TIPOS_REFEICAO_LOV
```

### Regiao: cards de sugestoes

Tipo: `Cards`

SQL:

```sql
SELECT ALIMENTO_SUGERIDO,
       'Confianca ' || CONFIANCA_PCT || '%' AS SUBTITULO,
       INSIGHT || ' | ' || KCAL_100G || ' kcal/100g | P: ' ||
       PROTEINAS_100G || 'g C: ' || CARBOIDRATOS_100G || 'g G: ' ||
       GORDURAS_100G || 'g' AS RESUMO
FROM VW_APP_SUGESTOES_POR_TIPO
WHERE ID_TIPO_REFEICAO = :P8_ID_TIPO_REFEICAO
ORDER BY CONFIANCA_PCT DESC, FREQUENCIA DESC
```

Mapeamento:

- Title Column: `ALIMENTO_SUGERIDO`
- Subtitle Column: `SUBTITULO`
- Body Column: `RESUMO`

### Dynamic Action

No item `P8_ID_TIPO_REFEICAO`:

- Event: `Change`
- True Action: `Refresh`
- Region: cards de sugestoes

Resultado: escolher `CAFE DA MANHA`, `ALMOCO`, `LANCHE` ou `JANTAR` muda as sugestoes da IA.

## 5. Usar sugestao da IA para montar refeicao

No video, mostre este fluxo:

1. Abrir `Sugestoes IA`.
2. Selecionar `ALMOCO`.
3. O app sugere, por exemplo, arroz, feijao e frango.
4. Ir para `Montar Refeicao`.
5. Criar almoco usando um alimento sugerido.
6. Voltar ao Dashboard e mostrar calorias/macros atualizados.

Isso demonstra que a IA nao esta apenas visual: ela orienta a escolha do usuario e o banco recalcula o dashboard.

## 6. O que ainda e simulacao

O APEX puro nao cria automaticamente uma tela Angular completa. Aqui a IA esta no banco:

- historico de refeicoes alimenta `VW_SUGESTOES_REFEICAO`
- `VW_APP_SUGESTOES_POR_TIPO` filtra por tipo
- `PKG_NUTRYON_IA.SUGERIR_INGREDIENTES_JSON` expoe JSON
- formulario APEX registra novas refeicoes
- dashboard recalcula pelo historico atualizado

Se o ambiente liberar `DBMS_DATA_MINING`, o bloco OML em `apex/nutryon_oml.sql` pode substituir o fallback SQL por regras Apriori reais.
