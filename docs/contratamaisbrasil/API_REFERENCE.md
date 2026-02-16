# Referência de APIs Governamentais e Integração

Este documento detalha as APIs oficiais do ecossistema federal brasileiro que suportam o programa **Contrata Mais Brasil** e a Nova Lei de Licitações (14.133/2021). O consumo dessas APIs é fundamental para que o **PraticOS** funcione como um facilitador oficial ou extraoficial para prefeituras e prestadores de serviço.

## 1. API PNCP (Portal Nacional de Contratações Públicas)
**Status:** Crítica / Obrigatória
**Função:** É o repositório centralizado e obrigatório de todas as compras públicas (incluindo dispensas eletrônicas de prefeituras).
**Documentação (Swagger):** [https://pncp.gov.br/pncp-consulta/v3/api-docs](https://pncp.gov.br/pncp-consulta/v3/api-docs)

### Uso no PraticOS
-   **Monitoramento de Oportunidades:** Consultar o endpoint de contratações filtrando por município e modalidade "Dispensa de Licitação" para capturar novas demandas de serviços (ex: reparos, pintura) quase em tempo real.
-   **Validação de Editais:** Verificar se uma demanda publicada manualmente por uma prefeitura no PraticOS já consta no PNCP (compliance).

---

## 2. API Compras.gov.br (Dados Abertos)
**Status:** Alta Relevância
**Função:** Fornece dados detalhados do SIASG (Sistema Integrado de Administração de Serviços Gerais), incluindo catálogos de materiais e serviços.
**Documentação (Swagger):** 
-   Geral: [https://compras.dados.gov.br/docs/](https://compras.dados.gov.br/docs/)
-   Contratos: [https://contratos.comprasnet.gov.br/docs/api-docs.json](https://contratos.comprasnet.gov.br/docs/api-docs.json)

### Uso no PraticOS
-   **Padronização de Serviços:** Utilizar o **CATSER (Catálogo de Serviços)** via API para que as demandas criadas no PraticOS usem os mesmos códigos e nomenclaturas oficiais do governo (ex: "Serviço de Alvenaria - Código 1234"). Isso facilita a exportação de dados para prestação de contas.
-   **Consulta de Fornecedores:** Verificar histórico de vitórias em licitações de um CNPJ/CPF.

---

## 3. API Plataforma +Brasil
**Status:** Média Relevância (Contexto Específico)
**Função:** Focada na gestão de convênios e transferências de recursos da União para Municípios.
**Documentação:** [https://siconv.estaleiro.serpro.gov.br/maisbrasil-api/swagger/index.html](https://siconv.estaleiro.serpro.gov.br/maisbrasil-api/swagger/index.html)

### Uso no PraticOS
-   Útil apenas se o serviço contratado pela prefeitura for pago com verba de convênio federal (ex: reforma de escola com verba do FNDE). O PraticOS poderia vincular a "Ordem de Serviço" ao número do convênio.

---

## 4. Estratégia de Integração Técnica

### Autenticação e Protocolos
-   **Padrão:** REST over HTTP 1.1.
-   **Formato:** JSON.
-   **Segurança:** 
    -   *Leitura (Dados Abertos):* Geralmente acesso livre, sem necessidade de token.
    -   *Escrita/Transação:* Exige autenticação via **Gov.br** (Oauth2) ou certificados digitais, com Tokens Bearer no header `Authorization`.

### Arquitetura Sugerida para o Módulo Prefeituras
1.  **Microserviço de Ingestão ("Listener"):**
    -   Um job recorrente (crawler/poller) que consulta a API do PNCP a cada 1 hora.
    -   Filtra novas dispensas de licitação nos municípios parceiros do PraticOS.
    -   Gera um "Alerta de Oportunidade" no app para os prestadores cadastrados na região.

2.  **Mapeamento de Dados (Data Mapping):**
    -   `PraticOS.Servico` -> Mapear para `Compras.gov.br.CATSER`.
    -   `PraticOS.Empresa` -> Validar contra `Receita Federal` ou `SICAF` (se disponível via API parceira).

3.  **Bot de Notificação:**
    -   Ao detectar uma nova oportunidade via API, o sistema dispara:
        -   Push Notification no App Prestador.
        -   Mensagem no WhatsApp (via integração Twilio/Wpp API) com link direto para a proposta.
