# API PNCP - Referência Validada (Fev/2026)

Documentação baseada em testes reais feitos contra a API do PNCP em 13/02/2026.

## Base URL

```
https://pncp.gov.br/api/consulta
```

- **Swagger UI:** https://pncp.gov.br/api/consulta/swagger-ui/index.html
- **OpenAPI Spec:** https://pncp.gov.br/pncp-consulta/v3/api-docs

## Autenticação

Leitura é **livre**, sem token. Apesar do Swagger mencionar JWT Bearer, as consultas funcionam sem autenticação.

---

## Endpoints Validados

### Buscar contratações por data de publicação

```
GET /v1/contratacoes/publicacao
```

| Parâmetro | Tipo | Obrigatório | Descrição |
|-----------|------|-------------|-----------|
| `dataInicial` | string | Sim | Formato `YYYYMMDD` |
| `dataFinal` | string | Sim | Formato `YYYYMMDD` |
| `codigoModalidadeContratacao` | int | Sim | Ver tabela de modalidades abaixo |
| `cnpj` | string | Não | CNPJ do órgão (sem pontuação) |
| `uf` | string | Não | Sigla do estado |
| `codigoMunicipioIbge` | string | Não | Código IBGE do município |
| `pagina` | int | Não | Página (default 1) |
| `tamanhoPagina` | int | Não | Itens por página (min 10, max ~500) |

### Outros endpoints disponíveis

| Endpoint | Descrição |
|----------|-----------|
| `GET /v1/contratacoes/proposta` | Com período de proposta aberto |
| `GET /v1/contratacoes/atualizacao` | Por data de atualização |
| `GET /v1/orgaos/{cnpj}/compras/{ano}/{sequencial}` | Contratação específica |
| `GET /v1/contratos` | Contratos por data |
| `GET /v1/atas` | Atas de registro de preço |
| `GET /v1/pca/` | Planejamento de contratações |

---

## Códigos de Modalidade

| Código | Modalidade |
|--------|-----------|
| **8** | **Dispensa de Licitação** ← foco Contrata Mais Brasil |
| 6 | Pregão - Eletrônico |
| 4 | Concorrência - Eletrônica |
| 9 | Inexigibilidade |
| 13 | Credenciamento |

---

## Exemplos Testados (cURL)

### 1. Dispensas de um município (por código IBGE)

```bash
curl -s "https://pncp.gov.br/api/consulta/v1/contratacoes/publicacao?\
dataInicial=20260101&\
dataFinal=20260213&\
codigoModalidadeContratacao=8&\
codigoMunicipioIbge=4215695&\
pagina=1&\
tamanhoPagina=50"
```

**Resultado:** 8 dispensas de Santiago do Sul/SC (Jan-Fev 2026).

> **Atenção:** O filtro por `codigoMunicipioIbge` retorna TODOS os órgãos sediados no município (prefeitura, órgãos estaduais, federais, autarquias, conselhos), não apenas a prefeitura.

### 2. Dispensas de um órgão específico (por CNPJ)

```bash
# Apenas Prefeitura de Florianópolis
curl -s "https://pncp.gov.br/api/consulta/v1/contratacoes/publicacao?\
dataInicial=20260101&\
dataFinal=20260213&\
codigoModalidadeContratacao=8&\
cnpj=82892282000143&\
pagina=1&\
tamanhoPagina=50"
```

**Resultado:** 3 dispensas (apenas da prefeitura).

> **Dica importante:** `cnpj` é muito mais preciso que `codigoMunicipioIbge`. Florianópolis por IBGE retorna ~281 registros (todos os órgãos na cidade), por CNPJ da prefeitura retorna apenas 3.

### 3. Obter código IBGE de um município

```bash
curl -s "https://servicodados.ibge.gov.br/api/v1/localidades/estados/SC/municipios"
```

---

## Estrutura de Resposta (JSON)

```json
{
  "data": [
    {
      "valorTotalEstimado": 3090.00,
      "modalidadeNome": "Dispensa",
      "modoDisputaNome": "Dispensa Com Disputa",
      "situacaoCompraNome": "Divulgada no PNCP",
      "orgaoEntidade": {
        "cnpj": "82892282000143",
        "razaoSocial": "MUNICIPIO DE FLORIANOPOLIS",
        "poderId": "N",
        "esferaId": "M"
      },
      "anoCompra": 2026,
      "sequencialCompra": 1,
      "numeroCompra": "1",
      "processo": "00268928/2025",
      "objetoCompra": "Aquisição de lacres para operações...",
      "unidadeOrgao": {
        "ufNome": "Santa Catarina",
        "codigoUnidade": "988105",
        "ufSigla": "SC",
        "municipioNome": "Florianópolis",
        "nomeUnidade": "PREFEITURA MUNICIPAL DE FLORIANOPOLIS - SC",
        "codigoIbge": "4205407"
      },
      "dataPublicacaoPncp": "2026-01-05T15:26:17",
      "dataAberturaProposta": "2026-01-07T13:00:00",
      "dataEncerramentoProposta": "2026-01-12T12:00:00",
      "amparoLegal": {
        "codigo": 19,
        "nome": "Lei 14.133/2021, Art. 75, II",
        "descricao": "Dispensa de Licitação: valores inferiores a R$ 50.000,00"
      },
      "numeroControlePNCP": "82892282000143-1-000001/2026",
      "srp": false,
      "valorTotalHomologado": null,
      "informacaoComplementar": "...",
      "fontesOrcamentarias": [],
      "dataInclusao": "2026-01-05T15:26:17",
      "dataAtualizacao": "2026-01-05T15:26:17"
    }
  ],
  "totalRegistros": 3,
  "totalPaginas": 1,
  "numeroPagina": 1,
  "paginasRestantes": 0,
  "empty": false
}
```

### Campos relevantes para o PraticOS

| Campo | Descrição |
|-------|-----------|
| `objetoCompra` | Descrição do serviço/produto |
| `valorTotalEstimado` | Valor estimado da contratação |
| `orgaoEntidade.cnpj` | CNPJ do órgão contratante |
| `orgaoEntidade.razaoSocial` | Nome do órgão |
| `orgaoEntidade.esferaId` | `M` = Municipal, `E` = Estadual, `F` = Federal |
| `unidadeOrgao.codigoIbge` | Código IBGE do município |
| `unidadeOrgao.municipioNome` | Nome do município |
| `dataAberturaProposta` | Início do período de propostas |
| `dataEncerramentoProposta` | Fim do período de propostas |
| `situacaoCompraNome` | "Divulgada no PNCP", "Revogada", etc. |
| `amparoLegal.nome` | Base legal (Art. 75, I / II / VIII, etc.) |
| `numeroControlePNCP` | Identificador único no PNCP |

---

## CNPJs e Códigos IBGE Validados

| Município | Código IBGE | CNPJ Prefeitura | Outros CNPJs |
|-----------|-------------|-----------------|--------------|
| Santiago do Sul/SC | `4215695` | `01612781000138` | `13019421000106` (Fundo Mun. Saúde) |
| Florianópolis/SC | `4205407` | `82892282000143` | — |

---

## Relação PNCP × Contrata Mais Brasil

> **IMPORTANTE:** Os dois sistemas são **paralelos e independentes**.

| Aspecto | PNCP | Contrata Mais Brasil |
|---------|------|---------------------|
| API pública | Sim (REST/JSON) | **Não existe** |
| Conteúdo | Dispensas/licitações tradicionais | Oportunidades MEI (pequenos serviços) |
| Cross-publish | Não publica no Contrata+ | Não publica no PNCP |
| IDs | `numeroControlePNCP` | ID interno sequencial (ex: `5552`) |
| Acesso aos dados | API livre | Scraping HTML |

Para a oportunidade `https://contratamaisbrasil.sistema.gov.br/oportunidades/5552`, **não existe forma de buscar via API**. O Contrata Mais Brasil é uma aplicação Django server-rendered, sem endpoints JSON para oportunidades. A única alternativa é scraping HTML.

---

## Portais Web para Visualização

| Portal | URL com filtros |
|--------|----------------|
| **PNCP** | `https://pncp.gov.br/app/editais?municipioId=4205407&municipioNome=Florianópolis&uf=SC&modalidade=8` |
| **Contrata Mais Brasil** | `https://contratamaisbrasil.sistema.gov.br/oportunidades/?uf=SC&municipio=Florianópolis` |
| **Compras.gov.br** | `https://cnetmobile.estaleiro.serpro.gov.br/comprasnet-fas/public/compras/acompanhar` |
