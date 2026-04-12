# Nutryon AI — Inteligência Artificial com Oracle Machine Learning

Componente de Inteligência Artificial do projeto **Nutryon**, desenvolvido para a disciplina **Disruptive Architectures: IoT, IoB & Generative IA** da FIAP.

---

## 👥 Integrantes

| Nome | RM |
|---|---|
| Renato | RM560928 |
| Victor | RM560087 |
| Luan Noqueli Klochko | RM560313 |
| Lucas Higuti Fontanezi | RM561120 |

---

## 📌 Sobre o projeto

O Nutryon é um aplicativo de nutrição e controle de macronutrientes que calcula automaticamente as necessidades calóricas do usuário com base no seu perfil (peso, altura, idade, objetivo e nível de atividade) e permite registrar refeições diárias acompanhando o consumo de proteínas, carboidratos e gorduras em tempo real.

Este repositório contém o componente de IA do projeto, que utiliza **Oracle Machine Learning (OML)** com o algoritmo **Apriori (Association Rules)** para analisar o histórico de refeições e sugerir automaticamente os ingredientes mais prováveis para cada nova refeição.

---

## 🧠 Problema de IA Resolvido

O principal ponto de abandono em aplicativos de nutrição é o registro manual e repetitivo das refeições. Mais de 80% dos usuários param de registrar em menos de duas semanas porque o processo de buscar cada ingrediente individualmente é trabalhoso.

A IA resolve isso aprendendo os padrões do próprio usuário: se Carlos sempre registra Frango Grelhado e Feijão Cozido juntos no almoço, o modelo descobre essa regra e passa a sugerir automaticamente essa combinação quando um novo almoço é iniciado.

---

## 🤖 Modelo Utilizado

**Algoritmo:** Apriori — Regras de Associação (Association Rules)  
**Pacote:** `DBMS_DATA_MINING` — nativo no Oracle Database  
**Modelo treinado:** `MDL_NUTRYON_ASSOC`

### Métricas configuradas

| Métrica | Valor | Significado |
|---|---|---|
| Suporte mínimo | 10% | Ingrediente aparece em pelo menos 10% das refeições |
| Confiança mínima | 60% | 60% de chance de B aparecer dado A |
| Lift | > 1 | Associação real, não coincidência estatística |

### Por que Apriori?

- Nativo no Oracle Database — zero dependência externa, zero custo adicional
- Dados já existem no banco — tabelas REFEICAO, REFEICAO_ITEM e INGREDIENTE
- Não precisa de dados rotulados — aprende diretamente do histórico
- Integração com Oracle APEX por SQL puro — sem middleware
- Regras interpretáveis — fácil de demonstrar e validar

---

## 🚀 Como Executar

### Pré-requisitos

- Acesso ao Oracle APEX (ambiente FIAP ou apex.oracle.com)
- Workspace com schema próprio
- SQL Workshop disponível

### Opção A — MVP completo (recomendado para demonstração)

Execute o arquivo `sql/nutryon_mvp_completo.sql` **um comando por vez** no SQL Workshop → SQL Commands do Oracle APEX. O arquivo está dividido em blocos comentados e cria todas as tabelas, insere os dados de demonstração e cria as três views para o APEX.

**Ordem de execução dos blocos:**
1. DROP das tabelas existentes (se houver)
2. CREATE TABLE de cada tabela
3. INSERT dos dados base (tipos de refeição, categorias, ingredientes)
4. INSERT dos usuários
5. INSERT das refeições e itens
6. COMMIT
7. CREATE das views (VW_DASHBOARD_USUARIO, VW_HISTORICO_REFEICOES, VW_SUGESTOES_REFEICAO)

> ⚠️ O SQL Commands do APEX aceita **apenas um comando por vez**. Não cole o arquivo inteiro — cole bloco por bloco conforme indicado nos comentários.

### Opção B — OML com DBMS_DATA_MINING (modelo completo)

Execute o arquivo `sql/nutryon_oml_completo.sql` após o banco estar populado. Este script cria a view transacional para o algoritmo Apriori, configura os parâmetros do modelo, realiza o treinamento e cria o job de re-treinamento semanal.

> ⚠️ Requer que o pacote `DBMS_DATA_MINING` esteja disponível no schema. Disponível no Oracle Database 12c ou superior.

### Criando o app no Oracle APEX

Após executar o SQL:

1. Acesse App Builder → Create → Use Create App Wizard
2. Nome: `Nutryon`
3. Adicione três páginas do tipo **Interactive Report:**
   - `VW_HISTORICO_REFEICOES` → nome: Histórico de Refeições
   - `VW_DASHBOARD_USUARIO` → nome: Dashboard
   - `VW_SUGESTOES_REFEICAO` → nome: Sugestões IA
4. Clique em **Create Application**
5. Clique em **Run Application**

---

## 📊 Páginas do App

### Histórico de Refeições
Exibe todas as refeições registradas com macros calculados automaticamente — kcal, proteína, carboidrato e gordura — com base nos valores nutricionais por 100g de cada ingrediente.

### Dashboard
Mostra o progresso calórico de cada usuário no dia atual comparado à meta personalizada, com percentual de atingimento e macros consumidos.

### Sugestões IA
Saída direta do modelo Apriori. Para cada tipo de refeição exibe os ingredientes mais frequentes no histórico com o percentual de confiança calculado pelo algoritmo e os valores nutricionais por 100g.

---

## 🛠️ Tecnologias Utilizadas

| Tecnologia | Uso |
|---|---|
| Oracle Database | Banco de dados relacional |
| Oracle Machine Learning (OML) | Treinamento do modelo Apriori |
| DBMS_DATA_MINING | Pacote nativo para machine learning |
| Oracle APEX | Interface do usuário / Interactive Reports |
| Oracle Scheduler | Re-treinamento automático semanal |
| PL/SQL | Procedures, functions e triggers |

---

## 🔗 Repositórios Relacionados

- **Frontend Angular:** https://github.com/VoyDcode/Nutryon-angular
- **Backend Spring Boot:** https://github.com/VoyDcode/Nutryon

---

## 🎥 Vídeo Pitch

https://www.youtube.com/watch?v=c6dg-uSwNLs

---

## 📝 Resultados Parciais

### Sprint 1 — Base do sistema
Modelagem do banco de dados Oracle com tabelas de usuário, ingredientes, refeições e nutrientes. Implementação do cadastro e autenticação.

### Sprint 2 — Cálculos nutricionais
Implementação dos cálculos de TMB e TDEE. Functions PL/SQL para cálculo automático de calorias. Procedures de relatório e trigger de auditoria.

### Sprint 3 — IA e MVP no APEX
Integração do Oracle Machine Learning com algoritmo Apriori. MVP funcional no Oracle APEX com três páginas Interactive Report. Views SQL para histórico, dashboard e sugestões baseadas em IA.
