# Contexto Técnico e Integrações

Para que o PraticOS possa atuar em conformidade ou se integrar ao ecossistema governamental no futuro, é importante entender os padrões tecnológicos utilizados pela **Plataforma +Brasil** (base do Contrata Mais Brasil).

## Padrões de API
As integrações governamentais modernas (Siconv/Plataforma +Brasil) seguem os seguintes padrões:
- **Arquitetura**: REST/HTTP 1.1.
- **Formato de Dados**: JSON.
- **Autenticação**: Header `Authorization` com token de acesso (Bearer).
- **Documentação**: Frequentemente disponibilizada via **Swagger/OpenAPI**.

## Pontos de Integração Potenciais
1.  **Sistemas de Compras**: Receber processos de compras e enviar propostas via API.
2.  **SICAF (Cadastro de Fornecedores)**: Consulta de regularidade do prestador (CNPJ/CPF) para garantir que ele pode ser contratado.
3.  **SIASG**: Integração para órgãos que já utilizam o sistema federal.

## Requisitos para o PraticOS (Adaptabilidade)
Para espelhar a eficiência do programa, o módulo de prefeituras do PraticOS deve:
- **Webhooks**: Implementar webhooks para notificar o prestador instantaneamente quando uma nova demanda de prefeitura "cair" no sistema (similar ao alerta de WhatsApp).
- **Geoprocessamento**: Utilizar as coordenadas GPS da demanda para filtrar prestadores num raio de X km, garantindo o "fomento local" exigido por muitas leis municipais.
- **Padronização JSON**: Seguir nomes de campos similares aos do governo (ex: `objeto`, `valorEstimado`, `justificativa`) para facilitar migrações ou exportações de dados para portais de transparência.
