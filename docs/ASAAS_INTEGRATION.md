# Integração Asaas

> Status: **em preparação** (2026-10-04). Implementação na issue #303.
> Estratégia e parceria: [`business/PARCERIAS.md`](../business/PARCERIAS.md).

## Visão Geral

O técnico cobra o cliente da OS (Pix, boleto ou cartão) pela conta Asaas dele, e o pagamento confirmado dá baixa na OS automaticamente. Depois: NFS-e e split para a Rafsoft. Caminho de distribuição: publicar o PraticOS na **Flapp Store** (loja de apps dentro da conta Asaas).

## Ambientes

| Ambiente | Painel | API base |
|----------|--------|----------|
| Sandbox | https://sandbox.asaas.com | `https://api-sandbox.asaas.com/v3` |
| Produção | https://www.asaas.com | `https://api.asaas.com/v3` |

- Autenticação: header `access_token: <chave>`. Enviar também `User-Agent` identificando o PraticOS.
- Chaves de sandbox começam com `$aact_hmlg`; de produção, com `$aact_prod`. Ao gravar em `.env`, usar aspas simples por causa do `$`.
- Chaves sem uso por 3 meses são desabilitadas pelo Asaas.
- Documentação oficial: https://docs.asaas.com (também disponível via MCP `asaas` no Claude Code).

## Configuração local (desenvolvimento)

`firebase/functions/.env.local` (gitignored):

```bash
ASAAS_SANDBOX_API_KEY='$aact_hmlg_...'
```

Nunca commitar chaves. Produção usará Secret Manager. Onde cada credencial está fica no inventário privado de acessos (fora deste repositório).

Teste rápido da chave:

```bash
curl -s https://api-sandbox.asaas.com/v3/myAccount -H "access_token: $ASAAS_SANDBOX_API_KEY" -H "User-Agent: praticos-dev"
```

## Arquitetura planejada

```
App (OS) ──► Functions /api ──► Asaas API (conta do técnico)
                 ▲                      │
                 └──── webhook ◄────────┘  PAYMENT_RECEIVED / PAYMENT_CONFIRMED
```

- **Conexão da conta do técnico**, dois modos atrás da mesma interface:
  1. chave de API colada pelo técnico (sandbox e piloto);
  2. permissões concedidas na contratação pela Flapp Store (quando homologado).
- Credencial do técnico guardada só no backend (Secret Manager ou criptografada), nunca no app nem em texto puro no Firestore.
- Cobrança criada com `billingType: UNDEFINED` (cliente escolhe Pix, boleto ou cartão), valor em aberto da OS e cliente da OS (find-or-create no Asaas).
- Link da OS (`/q/{token}`) mostra "Pagar" com a URL da fatura.
- Webhook autenticado por token registra a transação na OS (mesmo modelo de pagamentos parciais) e atualiza o status de pagamento.
- Feature flag por empresa para o piloto.

## Recursos do Asaas que vamos usar

| Recurso | Doc |
|---------|-----|
| Cobranças | https://docs.asaas.com/reference/criar-nova-cobranca |
| Clientes | https://docs.asaas.com/reference/criar-novo-cliente |
| Webhooks de cobrança | https://docs.asaas.com/docs/webhook-para-cobrancas |
| Split (fase 2) | https://docs.asaas.com/docs/split-de-pagamentos |
| NFS-e (fase 3) | https://docs.asaas.com/docs/notas-fiscais |
| Subcontas / BaaS (futuro) | https://docs.asaas.com/docs/criacao-de-subcontas · https://docs.asaas.com/docs/sobre-baas |
| Flapp Store | https://docs.asaas.com/docs/flappstore |

## Regras de Negócio

- Uma OS pode ter várias cobranças (pagamentos parciais); cada pagamento confirmado vira uma transação na OS.
- Cancelar a OS não cancela cobranças automaticamente nesta fase (decisão a revisar na implementação).
- Estorno no Asaas deve estornar a transação na OS.
- Recursos de cobrança de serviço físico ficam fora do IAP da Apple; não amarrar recursos pagos do app iOS a planos vendidos fora da loja sem revisar a guideline 3.1.1.
