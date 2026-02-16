# Estratégia de Acesso aos Dados: Contrata Mais Brasil

Este documento detalha a estratégia técnica para localizar e consumir as oportunidades do programa **Contrata Mais Brasil** utilizando as APIs públicas do governo (SIASG/Compras.gov.br), visto que o portal utiliza identificadores internos que não são expostos diretamente no PNCP.

## 1. A Natureza dos Dados
O **Contrata Mais Brasil** não possui um banco de dados isolado. Ele funciona como uma "camada de apresentação" (frontend) simplificada para processos que ocorrem no backend do **SIASG** (Sistema Integrado de Administração de Serviços Gerais).

- **Oportunidade no Portal:** Visualizada com ID interno (ex: `5618`).
- **Registro Real (API):** Armazenada como **Dispensa de Licitação** (Modalidade 6) ou **Cotação Eletrônica**.

## 2. Mapeamento para API do Compras.gov.br
Para o PraticOS listar essas oportunidades, não devemos buscar pelo ID do portal (5618), mas sim filtrar o fluxo de dispensas de licitação dos municípios alvo.

### Endpoint Principal
```http
GET https://compras.dados.gov.br/licitacoes/v1/licitacoes.json
```

### Parâmetros de Filtragem (A "Query Mágica")
Para encontrar as oportunidades típicas do Contrata+ (pequenos reparos, serviços imediatos), utilize os seguintes filtros:

| Parâmetro | Valor | Descrição |
| :--- | :--- | :--- |
| `modalidade` | **6** | Código para **Dispensa de Licitação** (Art. 75 Lei 14.133). |
| `uasg` | *(Opcional)* | Código da Unidade Gestora (Prefeitura/Órgão). Útil para monitorar uma prefeitura específica. |
| `data_publicacao_min` | `YYYY-MM-DD` | Para pegar apenas novas oportunidades (incremental). |
| `objeto` | *keywords* | Palavras-chave como "manutenção", "pintura", "reparo", "serviço". |

### Exemplo de Requisição (cURL)
Buscar todas as dispensas de licitação (possíveis oportunidades Contrata+) publicadas a partir de 01/01/2026:

```bash
curl -X GET "https://compras.dados.gov.br/licitacoes/v1/licitacoes.json?modalidade=6&data_publicacao_min=2026-01-01" 
     -H "Accept: application/json"
```

## 3. Algoritmo de Ingestão para o PraticOS

Para replicar a funcionalidade de "Notificação de Oportunidade" do Contrata Mais Brasil dentro do PraticOS, o seguinte algoritmo é sugerido:

1.  **Polling (Busca Recorrente):**
    -   A cada X minutos, consultar o endpoint de licitações filtrando por `modalidade=6` e `data_publicacao` do dia.
2.  **Filtragem Geográfica:**
    -   O retorno da API contém a `UASG`. É necessário consultar a API de UASGs (`/licitacoes/v1/uasgs/{id_uasg}`) para descobrir o **Município** e **UF** daquele órgão.
    -   Se o município corresponder à base de um usuário Prestador do PraticOS, prosseguir.
3.  **Filtragem de Categoria (CATSER):**
    -   Analisar o objeto ou os itens da licitação. Se corresponderem a serviços de zeladoria (eletricista, encanador, pedreiro), classificar a oportunidade.
4.  **Notificação:**
    -   Enviar Push Notification: *"Nova oportunidade de Pintura detectada na Prefeitura de [Cidade]! Toque para ver o edital."*

## 4. Diferença: ID do Portal vs. ID Oficial
-   **ID Portal (5618):** Apenas um índice do banco de dados do site `contratamaisbrasil.sistema.gov.br`. Não serve para busca em APIs externas.
-   **Chave Única Oficial:** `Código da UASG` + `Número da Modalidade` + `Número da Licitação` (ex: `15322906000522024`).

> **Nota Importante:** O PNCP (Portal Nacional de Contratações Públicas) é o futuro, mas para *pequenas dispensas* (foco do Contrata+), a API de Dados Abertos do Compras.gov.br (SIASG) ainda é a fonte mais granular e confiável para "scrapear" essas demandas.
