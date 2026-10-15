# Nota fiscal de serviço (NFS-e) pelo Asaas

> Status: **pronta, desligada por padrão.** Só aparece numa empresa quando o servidor liga `nfseEnabled` em `settings/payments` (como o `asaasEnabled` do piloto de cobrança). Nenhum cliente usa ainda: falta o teste no sandbox (ver [Teste no sandbox](#teste-no-sandbox)).
> Base: [`ASAAS_INTEGRATION.md`](ASAAS_INTEGRATION.md) (conexão, webhook, permissões). Doc do Asaas: https://docs.asaas.com/docs/notas-fiscais

## Visão Geral

A empresa emite a nota fiscal de serviço da OS pela própria conta Asaas. O Asaas manda a nota para a prefeitura e avisa por webhook quando ela é emitida, recusada ou cancelada.

- **O Asaas só emite NFS-e** (serviço), não NF-e (produto). Por isso a nota leva **só os serviços da OS**; as peças ficam de fora, e a folha de emissão diz isso.
- **Uma nota por OS** (padrão), mesmo quando o cliente pagou várias OS juntas. A nota é da OS, não do pagamento.
- **Uma nota com várias OS** (opção, para cliente mensal ou de contrato): escolhida pela pessoa no cliente ("…" → "Emitir uma nota com várias OS").
- Uma OS só pode ter **uma nota ativa** (agendada, enviada, emitida ou com cancelamento negado). Nota com erro ou cancelada libera a OS para outra.

## Decisões

| Decisão | Escolha | Por quê |
|---------|---------|---------|
| Ligação da nota | **Avulsa** (`customer`, sem `payment`/`installment`) | A nota não depende de como a OS foi paga (Pix, dinheiro, cobrança de várias OS, ainda não paga). Vincular a uma cobrança deixaria a nota presa ao ciclo da cobrança (cancelar cobrança, parcelas, várias OS num link) sem ganho para o usuário. A configuração "emitir nota ao receber" do Asaas não é usada |
| Valor | Serviços − parte do desconto que cabe aos serviços | Ver [Regra do valor](#regra-do-valor) |
| Onde fica | `companies/{cid}/invoices/{id}` com `orderIds` | Um documento por nota, seja de uma ou de várias OS; a OS acha a sua nota por `orderIds array-contains` |
| Credenciais da prefeitura | Enviadas **no painel do Asaas**, nunca pelo PraticOS | Certificado digital e senha da prefeitura não passam pelo app nem pelo servidor |

## Regra do valor

Igual ao total da OS no app (`OrderStore.updateTotal`): serviços somam `value`, peças somam `total` (ou `value × quantity`), item sem preço conta zero. O desconto é da OS inteira, então a nota fica com a parte dele que cabe aos serviços:

```
valor = serviços − desconto × serviços / (serviços + peças)
```

Arredondado em centavos, nunca negativo. Exemplo: serviços R$ 300, peças R$ 100, desconto R$ 40 → 300 − 40 × 0,75 = **R$ 270**. Na nota com várias OS, o valor é a soma do valor de cada OS. Implementado em `invoiceValueOfOrder` (`invoice.service.ts`); a folha de emissão mostra serviços, peças fora da nota, desconto e o valor.

OS sem valor de serviço (só peças, ou serviços sem preço) não pode ter nota (`NO_SERVICES`).

## Arquitetura

### Servidor (`firebase/functions`)

| Arquivo | O quê |
|---------|-------|
| `services/asaas/invoice.service.ts` | Regra do valor, descrição, prévia, emissão, cancelamento, status, PDF na OS e o evento do webhook |
| `services/asaas/nfse-setup.service.ts` | Configuração fiscal (`/v3/fiscalInfo`), serviços municipais, serviço padrão e o que falta |
| `services/asaas/asaas-client.ts` | `getFiscalInfo`, `saveFiscalInfo`, `getMunicipalOptions`, `listMunicipalServices`, `createInvoice`, `authorizeInvoice`, `cancelInvoice`, `getInvoice` |
| `routes/v1/nfse.routes.ts` | Rotas do app em `/v1/app/nfse` |
| `services/asaas/webhook.service.ts` | Encaminha `INVOICE_*` para `applyInvoiceEvent` |
| `services/asaas/connection.service.ts` | Assina os eventos `INVOICE_*` no webhook da conexão |
| `scripts/enable-asaas-pilot.ts --nfse` | Liga/desliga `nfseEnabled` de uma empresa |

### Endpoints (`/v1/app/nfse`, bearer do app)

Todos respondem `NFSE_NOT_ENABLED` (403) sem a flag e `ASAAS_NOT_CONNECTED` sem a conta conectada.

| Método e rota | Quem | O quê |
|---------------|------|-------|
| `GET /setup` | dono, admin | O que já está preenchido e o que falta (`fiscalInfo`, `cityAccess`, `service`), regras da cidade |
| `POST /setup/fiscal-info` | dono, admin | Salva a configuração fiscal no Asaas (`POST /v3/fiscalInfo`): e-mail, Simples Nacional, inscrição municipal, CNAE, regime especial, item da lista, RPS |
| `GET /setup/municipal-services?q=` | dono, admin | Serviços municipais da cidade (`GET /v3/fiscalInfo/services`) |
| `PUT /setup/service` | dono, admin | Serviço padrão das notas: serviço municipal (id ou código + nome), impostos (ISS retido, ISS, PIS, COFINS, CSLL, INSS, IR) e modelo da descrição (`{servicos}`, `{os}`) |
| `POST /invoices/preview` | `manage:payments` | Valor, descrição, cliente e CPF/CNPJ de uma ou mais OS |
| `POST /invoices` | `manage:payments` | Emite uma nota para uma ou mais OS (até 50) do mesmo cliente |
| `POST /invoices/{id}/cancel` | `manage:payments` | Cancela; `onlyOnAsaas` só para nota que a prefeitura não cancela |

`manage:payments` = dono, admin e gerente. Consultor e técnico não emitem nem cancelam.

### Emissão (`POST /invoices`)

1. Confere flag, conta, serviço padrão (`NFSE_NOT_READY`), OS do mesmo cliente (`ORDER_NOT_OF_CUSTOMER`), OS fora de orçamento/cancelada (`NFSE_ORDER_NOT_ALLOWED`) e valor de serviço (`NO_SERVICES`).
2. CPF/CNPJ do cliente: o enviado (`customerTaxId`, que também é gravado no cliente) ou o do cadastro; sem ele, `TAX_ID_REQUIRED`.
3. Numa transação: lê as travas `private/nfse/orders/{orderId}`; se alguma aponta para nota ativa, `ORDER_HAS_INVOICE`. Cria a nota `creating` e grava as travas.
4. Acha ou cria o cliente no Asaas e chama `POST /v3/invoices` (avulsa) com `externalReference` = `{companyId}:nf:{invoiceId}`, `serviceDescription`, `observations` ("OS 182, 190"), `value`, `deductions: 0`, `effectiveDate`, serviço municipal e `taxes`.
5. Grava o id do Asaas e o status. Se o Asaas recusar, a nota vira `error` e as travas saem.

Uma nota `creating` com mais de 15 minutos (o servidor caiu no meio) deixa de travar a OS.

### Status

| Nosso | Asaas | No app |
|-------|-------|--------|
| `creating` | — | Aguardando prefeitura |
| `scheduled` | `SCHEDULED` | Aguardando prefeitura |
| `synchronized` | `SYNCHRONIZED` | Aguardando prefeitura |
| `authorized` | `AUTHORIZED` | Emitida · nº 123 (verde) |
| `processingCancellation` | `PROCESSING_CANCELLATION` | Cancelando |
| `cancellationDenied` | `CANCELLATION_DENIED` | Cancelamento negado |
| `canceled` | `CANCELED` | Cancelada (cinza) |
| `error` | `ERROR` | Erro (vermelho), com o motivo |

O status só anda para a frente (evento atrasado ou repetido não desfaz nota emitida ou cancelada); `canceled` é final; `error` pode ir para qualquer um (a nota foi corrigida e reagendada no Asaas).

### Webhook

Eventos assinados na conexão: `INVOICE_CREATED`, `INVOICE_UPDATED`, `INVOICE_SYNCHRONIZED`, `INVOICE_AUTHORIZED`, `INVOICE_PROCESSING_CANCELLATION`, `INVOICE_CANCELED`, `INVOICE_CANCELLATION_DENIED`, `INVOICE_ERROR`. **Empresas conectadas antes desta versão precisam reconectar a conta** para receber esses eventos (como na etapa 3).

- A nota é achada pelo `externalReference` (`{cid}:nf:{id}`); sem ele, por `asaasInvoiceId`. Referência de outra empresa ou nota emitida fora do PraticOS (painel, nota vinculada a cobrança) → registrada e respondida com 200.
- Idempotente como os eventos de cobrança (`private/asaas/events`), e o status segue a regra acima.
- Grava número, código de verificação, `pdfUrl`, `xmlUrl` e `statusDescription` (motivo do erro ou do cancelamento).
- **Emitida**: o PDF entra nos documentos de cada OS (`OrderDocument` tipo `invoice`, id `nfse_{invoiceId}`). **Cancelada**: o documento sai. Sem push por enquanto.

## Modelo de dados (Firestore)

| Caminho | Quem grava | Quem lê |
|---------|-----------|---------|
| `companies/{cid}/settings/payments` → `nfseEnabled` | script/admin | quem lê os pagamentos |
| `companies/{cid}/settings/payments` → `nfseReady` | servidor (ao conferir a configuração) | idem |
| `companies/{cid}/settings/nfse` | servidor | `canViewCharges` |
| `companies/{cid}/invoices/{id}` | servidor (rotas e webhook) | `canViewCharges` |
| `companies/{cid}/private/nfse/orders/{orderId}` | servidor (trava uma nota ativa por OS) | ninguém |

`invoices/{id}`: `asaasInvoiceId`, `status`, `customer {id, name}`, `orderIds`, `orders [{id, number, servicesTotal, productsTotal, discount, value}]`, `value`, `serviceDescription`, `observations`, `effectiveDate`, `municipalServiceName`, `number`, `validationCode`, `pdfUrl`, `xmlUrl`, `statusDescription`, `createdBy`, `createdAt`, `updatedAt`, `authorizedAt`, `canceledAt`.

`settings/nfse`: `municipalServiceId`, `municipalServiceCode`, `municipalServiceName`, `taxes {retainIss, iss, pis, cofins, csll, inss, ir}`, `descriptionTemplate`.

## App

Tudo fica escondido sem `nfseEnabled` + Asaas conectado (`PaymentSettings.nfseAvailable`) e sem a permissão `chargeOrder` (dono, admin, gerente). `NfseController` (`lib/screens/nfse/nfse_access.dart`) junta flag, permissão e as notas da OS ou do cliente.

| Onde | O quê |
|------|-------|
| Conexão do Asaas | Linha "Nota fiscal" → configuração (`NfseSetupScreen`): o que falta, dados fiscais, acesso da prefeitura (aponta para o painel do Asaas), serviço padrão com impostos e modelo da descrição |
| OS (`order_screen_v2.dart`) | "…" → "Emitir nota fiscal" (OS com serviço, fora de orçamento/cancelada, sem nota ativa). Linha "Nota fiscal · Aguardando prefeitura / Emitida / Erro / Cancelada" com ponto de status, que abre o detalhe |
| Cliente | "…" → "Emitir uma nota com várias OS" → escolher as OS (`NfseOrdersPicker`) → mesma folha de emissão |
| Folha de emissão (`NfseIssueSheet`) | Valor (serviços, peças fora, desconto), descrição editável, CPF/CNPJ (pede quando falta), data; ✓ emite |
| Detalhe (`NfseInvoiceScreen`) | Status, número, valor, OS, PDF e XML quando emitida, motivo do erro em português; "…" → "Cancelar nota" em vermelho com confirmação |

Erros viram texto em pt/en/es por `asaasErrorText(..., nota: true)`, em aviso (`showAppToast`), nunca a mensagem crua.

## Ligar para uma empresa (checklist)

1. Empresa com o Asaas conectado **depois desta versão** (senão reconectar, para assinar os eventos `INVOICE_*`).
2. No painel do Asaas da empresa: conta aprovada, endereço e dados da empresa completos.
3. `npm run asaas:pilot -- --project praticos --company <id> --nfse --yes` (liga `nfseEnabled`).
4. Dono/admin abre Conexão do Asaas → "Nota fiscal" e preenche dados fiscais (inscrição municipal, CNAE, Simples Nacional, item da lista quando a cidade pede).
5. No painel do Asaas → Notas fiscais: enviar o acesso da prefeitura que a cidade exige (certificado digital A1, ou usuário e senha, ou token).
6. Escolher o serviço municipal e o ISS (e demais impostos) — conferir com o contador da empresa.
7. Emitir uma nota de valor baixo para uma OS de teste e acompanhar até "Emitida"; conferir o PDF na OS.

## Teste no sandbox

Não testado contra o Asaas real. Antes de oferecer:

- [ ] `GET/POST /v3/fiscalInfo` e `GET /v3/fiscalInfo/municipalOptions` com uma conta sandbox: campos aceitos e o que volta em `authenticationType` / `supportsCancellation`.
- [ ] `GET /v3/fiscalInfo/services` com e sem `description`: formato e se a cidade de teste tem lista.
- [ ] `POST /v3/invoices` avulsa com o payload montado (`taxes`, `deductions: 0`, `municipalServiceId` vs `municipalServiceCode`): aceita e agenda.
- [ ] Webhooks `INVOICE_*` chegando na URL da empresa com o `externalReference`; nota passando a "Emitida" e PDF na OS.
- [ ] Recusa da prefeitura (`INVOICE_ERROR`): motivo em `statusDescription` e OS liberada para outra nota.
- [ ] Cancelamento de nota agendada e de nota emitida; cidade sem cancelamento pela integração (`CANCEL_NOT_SUPPORTED`).
- [ ] Nota com várias OS: descrição com uma linha por OS e observações "OS 182, 190".

## Regras de Negócio

- Só serviços entram na nota; peças nunca.
- Uma nota ativa por OS; nota com erro ou cancelada libera a OS.
- Uma nota com várias OS só junta OS do **mesmo cliente**, até 50.
- Orçamento e OS cancelada não têm nota.
- Data da nota: de hoje até 60 dias à frente (horário de São Paulo).
- Emitir/cancelar: dono, admin, gerente. Configurar: dono, admin.
- Cancelar nota emitida depende da prefeitura; quando a cidade não cancela pela integração, o app explica e manda cancelar no site da prefeitura.

## Limitações conhecidas

- Sem push quando a nota é emitida ou recusada (só a linha na OS muda).
- Nota emitida pelo painel do Asaas, ou vinculada a cobrança pela configuração do Asaas, não aparece no PraticOS.
- Deduções (`deductions`) sempre zero; retenções além do ISS seguem os percentuais do serviço padrão, iguais para todas as notas.
- Estorno de um pagamento não cancela a nota: cancelar à mão se for o caso.
