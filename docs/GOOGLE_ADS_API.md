# Google Ads API - Acesso via Claude Code

## Visao Geral

O PraticOS possui acesso direto a API do Google Ads para gerenciamento de campanhas via Claude Code. Isso permite criar, editar, monitorar e otimizar campanhas de anuncios sem sair do terminal.

## Credenciais

### Arquivo de configuracao

As credenciais ficam em `~/.google-ads.yaml`:

```yaml
developer_token: "SEU_DEVELOPER_TOKEN"
client_id: "SEU_CLIENT_ID.apps.googleusercontent.com"
client_secret: "GOCSPX-xxxxxxxx"
refresh_token: "1//xxxxxxxx"
login_customer_id: "1569666691"
use_proto_plus: True
```

### Contas

| Conta | ID | Tipo |
|-------|-----|------|
| PraticOS Manager | 156-966-6691 | Manager (MCC) |
| PraticOS | 673-501-4760 | Conta de anuncios |

### Nivel de Acesso

- **Atual**: Acesso Padrao (leitura e escrita)
- Permite criar, editar, pausar e gerenciar campanhas via API

## Como usar

### Dependencias

```bash
pip3 install google-ads google-auth-oauthlib
```

### Codigo base para qualquer operacao

```python
import warnings
warnings.filterwarnings('ignore')

from google.ads.googleads.client import GoogleAdsClient

client = GoogleAdsClient.load_from_storage('/Users/rafaeldl/.google-ads.yaml')
ga_service = client.get_service('GoogleAdsService')

CUSTOMER_ID = '6735014760'
MANAGER_ID = '1569666691'
```

### Operacoes comuns

#### Listar campanhas

```python
query = '''
    SELECT
        campaign.id,
        campaign.name,
        campaign.status,
        campaign_budget.amount_micros
    FROM campaign
    ORDER BY campaign.id
'''
response = ga_service.search(customer_id=CUSTOMER_ID, query=query)
for row in response:
    budget = row.campaign_budget.amount_micros / 1_000_000
    print(f'{row.campaign.name} | Status: {row.campaign.status.name} | Budget: R${budget:.2f}')
```

#### Performance de campanhas

```python
query = '''
    SELECT
        campaign.name,
        metrics.impressions,
        metrics.clicks,
        metrics.cost_micros,
        metrics.conversions,
        metrics.ctr
    FROM campaign
    WHERE segments.date DURING LAST_30_DAYS
    ORDER BY metrics.cost_micros DESC
'''
response = ga_service.search(customer_id=CUSTOMER_ID, query=query)
for row in response:
    cost = row.metrics.cost_micros / 1_000_000
    print(f'{row.campaign.name} | Clicks: {row.metrics.clicks} | CTR: {row.metrics.ctr:.2%} | Cost: R${cost:.2f}')
```

#### Performance de keywords

```python
query = '''
    SELECT
        ad_group_criterion.keyword.text,
        ad_group_criterion.keyword.match_type,
        metrics.impressions,
        metrics.clicks,
        metrics.cost_micros,
        metrics.ctr
    FROM keyword_view
    WHERE segments.date DURING LAST_30_DAYS
    ORDER BY metrics.impressions DESC
'''
response = ga_service.search(customer_id=CUSTOMER_ID, query=query)
for row in response:
    cost = row.metrics.cost_micros / 1_000_000
    print(f'{row.ad_group_criterion.keyword.text} | Clicks: {row.metrics.clicks} | CTR: {row.metrics.ctr:.2%} | Cost: R${cost:.2f}')
```

## Renovacao do Refresh Token

Se o token expirar, rodar:

```bash
python3 -c "
from google_auth_oauthlib.flow import InstalledAppFlow

flow = InstalledAppFlow.from_client_config(
    {
        'installed': {
            'client_id': 'SEU_CLIENT_ID',
            'client_secret': 'SEU_CLIENT_SECRET',
            'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
            'token_uri': 'https://oauth2.googleapis.com/token',
        }
    },
    scopes=['https://www.googleapis.com/auth/adwords'],
)

flow.run_local_server(port=8080)
print('Refresh Token:', flow.credentials.refresh_token)
"
```

Atualizar o valor em `~/.google-ads.yaml`.

## Upgrade para Acesso Padrao (escrita)

Para criar/editar campanhas via API:

1. Acesse [ads.google.com](https://ads.google.com) na conta **PraticOS Manager** (156-966-6691)
2. Va em **Adm.** > **Central de API**
3. Clique em **Solicitar acesso padrao** (ou "Apply for Standard Access")
4. Preencha o formulario de compliance
5. Aguarde aprovacao do Google (normalmente poucos dias)

## Referencia

- [Google Ads API Query Language (GAQL)](https://developers.google.com/google-ads/api/docs/query/overview)
- [Google Ads API Python Client](https://github.com/googleads/google-ads-python)
- [GAQL Interactive Builder](https://developers.google.com/google-ads/api/fields/v17/overview_query_builder)
