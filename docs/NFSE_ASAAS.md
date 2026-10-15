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
| `services/asaas/invoice.service.ts` | Regra do valor, descrição, prévia, emissão, cancelamento, status, conferência com o Asaas (`reconcileInvoice`) e o evento do webhook |
| `services/asaas/nfse-setup.service.ts` | Configuração fiscal (`/v3/fiscalInfo`), serviços municipais, serviço padrão e o que falta |
| `services/asaas/asaas-client.ts` | `getFiscalInfo`, `saveFiscalInfo`, `getMunicipalOptions`, `listMunicipalServices`, `createInvoice`, `authorizeInvoice`, `cancelInvoice`, `getInvoice`, `listInvoicesByExternalReference` |
| `routes/v1/nfse.routes.ts` | Rotas do app em `/v1/app/nfse` |
| `services/asaas/webhook.service.ts` | Encaminha `INVOICE_*` para `applyInvoiceEvent` |
| `services/asaas/webhook-events.ts` | Eventos do webhook e `hasNfseWebhookEvents` (conexão tem os `INVOICE_*`?) |
| `services/asaas/connection.service.ts` | Assina os eventos `INVOICE_*` no webhook e grava a lista em `private/asaas.webhookEvents` |
| `scripts/enable-asaas-pilot.ts --nfse` | Liga/desliga `nfseEnabled` de uma empresa; recusa ligar (`NFSE_RECONNECT_NEEDED`) se a conexão não tem os eventos `INVOICE_*` |

### Endpoints (`/v1/app/nfse`, bearer do app)

Todos respondem `NFSE_NOT_ENABLED` (403) sem a flag, `ASAAS_NOT_CONNECTED` sem a conta conectada e `NFSE_RECONNECT_NEEDED` (409, "Reconecte o Asaas para emitir notas.") quando a conexão foi feita antes da nota fiscal (sem `webhookEvents` com os `INVOICE_*`): sem esses eventos a recusa da prefeitura nunca chegaria e a OS ficaria travada.

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

1. Confere flag, conta, configuração pronta (`nfseReady`, senão `NFSE_NOT_READY`) e feita na conta conectada (`NFSE_SETUP_NEEDED`), OS do mesmo cliente (`ORDER_NOT_OF_CUSTOMER`), OS fora de orçamento/cancelada (`NFSE_ORDER_NOT_ALLOWED`) e valor de serviço (`NO_SERVICES`).
2. CPF/CNPJ do cliente: o enviado (`customerTaxId`, que também é gravado no cliente) ou o do cadastro; sem ele, `TAX_ID_REQUIRED`.
3. Confere com o Asaas as notas antigas que ainda travam essas OS (ver [Conferência com o Asaas](#conferência-com-o-asaas)). Numa transação: lê as travas `private/nfse/orders/{orderId}`; se alguma aponta para nota ativa, `ORDER_HAS_INVOICE`. Cria a nota `creating` e grava as travas.
4. Acha ou cria o cliente no Asaas e chama `POST /v3/invoices` (avulsa) com `externalReference` = `{companyId}:nf:{invoiceId}`, `serviceDescription`, `observations` ("OS 182, 190"), `value`, `deductions: 0`, `effectiveDate`, serviço municipal e `taxes`.
5. Grava o id do Asaas **logo que ele responde**, antes de qualquer outra coisa, e depois o status. Cada nota guarda a conta em que foi emitida (`asaasEnvironment`, `asaasWalletId`).
6. Se o Asaas **recusar** (400, 401, 403, 404 ou 422), nada foi criado: a nota é apagada e as travas saem. **Sem resposta certa** (tempo esgotado, 408, 5xx, rede) o Asaas pode ter criado a nota: ela fica `creating` e a OS continua travada até a conferência (repetir na hora dá `ORDER_HAS_INVOICE`, nunca duas notas).

### Conferência com o Asaas

`reconcileInvoice` olha no Asaas uma nota não final (`creating`, `scheduled`, `synchronized`, `processingCancellation`) sem novidade há mais de 3 minutos:

- Com `asaasInvoiceId`: `GET /v3/invoices/{id}` e grava a situação (pega a recusa da prefeitura cujo webhook se perdeu).
- Sem `asaasInvoiceId` (resposta do create perdida): `GET /v3/invoices?externalReference={cid}:nf:{id}`. Achou: grava o id e a situação. Não achou: a nota nunca chegou ao Asaas, é apagada e a OS fica livre.
- Asaas fora do ar: nada muda, a OS continua travada.

Roda na prévia, na emissão e no cancelamento que tocam a OS; o webhook também completa a nota (`INVOICE_*` com a nossa referência grava o id). Mais de uma nota no Asaas com a mesma referência gera log `ALERT`.

### Conta do Asaas

`settings/nfse` guarda a conta em que o serviço foi configurado (`asaasEnvironment`, `asaasWalletId`). Trocando a conta conectada, a configuração volta a faltar o serviço (`nfseReady` false) e emitir dá `NFSE_SETUP_NEEDED` ("A conta do Asaas mudou. Configure a nota fiscal de novo."). Configuração salva antes desta regra (sem a conta) também pede o serviço de novo. Cancelar nota de outra conta dá `INVOICE_OTHER_ACCOUNT` ("Esta nota é de outra conta do Asaas. Cancele por lá."); nota sem a conta gravada (anterior à regra) cancela normalmente.

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

Saindo de `error`, a transação confere se a trava de cada OS ainda aponta para essa nota. Se alguma OS já tem outra nota, a situação é gravada mas a nota vira `conflict: true`: não trava a OS de novo, gera log `ALERT` e o detalhe mostra "Nota emitida fora do PraticOS, confira no Asaas.". Nota em conflito nunca conta como a nota da OS.

### Webhook

Eventos assinados na conexão (gravados em `private/asaas.webhookEvents`): `INVOICE_CREATED`, `INVOICE_UPDATED`, `INVOICE_SYNCHRONIZED`, `INVOICE_AUTHORIZED`, `INVOICE_PROCESSING_CANCELLATION`, `INVOICE_CANCELED`, `INVOICE_CANCELLATION_DENIED`, `INVOICE_ERROR`. **Empresas conectadas antes desta versão precisam reconectar a conta** para receber esses eventos: até lá as rotas respondem `NFSE_RECONNECT_NEEDED` e a configuração no app mostra "Reconecte o Asaas para emitir notas.".

- A nota é achada pelo `externalReference` (`{cid}:nf:{id}`); sem ele, por `asaasInvoiceId`. Referência de outra empresa ou nota emitida fora do PraticOS (painel, nota vinculada a cobrança) → registrada e respondida com 200. Referência nossa sem o documento da nota (ou com outro id do Asaas) → 200 com log `ALERT`: existe nota no Asaas que o PraticOS perdeu.
- Idempotente como os eventos de cobrança (`private/asaas/events`), e o status segue a regra acima.
- Grava número, código de verificação, `pdfUrl`, `xmlUrl` e `statusDescription` (motivo do erro ou do cancelamento).
- PDF e XML ficam **só no documento da nota** (`invoices/{id}`), abertos pela linha "Nota fiscal" da OS. O servidor nunca escreve em `orders/{id}.documents`: o app grava essa lista inteira e apagaria (ou traria de volta) o PDF. Sem push por enquanto.

## Modelo de dados (Firestore)

| Caminho | Quem grava | Quem lê |
|---------|-----------|---------|
| `companies/{cid}/settings/payments` → `nfseEnabled` | script/admin | quem lê os pagamentos |
| `companies/{cid}/settings/payments` → `nfseReady` | servidor (ao conferir a configuração) | idem |
| `companies/{cid}/settings/nfse` | servidor | `canViewCharges` |
| `companies/{cid}/invoices/{id}` | servidor (rotas e webhook) | `canViewCharges` |
| `companies/{cid}/private/nfse/orders/{orderId}` | servidor (trava uma nota ativa por OS) | ninguém |

`invoices/{id}`: `asaasInvoiceId`, `status`, `customer {id, name}`, `orderIds`, `orders [{id, number, servicesTotal, productsTotal, discount, value}]`, `value`, `serviceDescription`, `observations`, `effectiveDate`, `municipalServiceName`, `number`, `validationCode`, `pdfUrl`, `xmlUrl`, `statusDescription`, `createdBy`, `createdAt`, `updatedAt`, `authorizedAt`, `canceledAt`, `asaasEnvironment`, `asaasWalletId`, `conflict`.

`settings/nfse`: `municipalServiceId`, `municipalServiceCode`, `municipalServiceName`, `taxes {retainIss, iss, pis, cofins, csll, inss, ir}`, `descriptionTemplate`, `asaasEnvironment`, `asaasWalletId`.

`private/asaas` (conexão): além dos campos da [integração](ASAAS_INTEGRATION.md), `webhookEvents` (eventos assinados ao conectar).

## App

Tudo fica escondido sem `nfseEnabled` + Asaas conectado (`PaymentSettings.nfseAvailable`) e sem a permissão `chargeOrder` (dono, admin, gerente). `NfseController` (`lib/screens/nfse/nfse_access.dart`) junta flag, permissão e as notas da OS ou do cliente.

| Onde | O quê |
|------|-------|
| Conexão do Asaas | Linha "Nota fiscal" → configuração (`NfseSetupScreen`): o que falta, dados fiscais, acesso da prefeitura (aponta para o painel do Asaas), serviço padrão com impostos e modelo da descrição |
| OS (`order_screen_v2.dart`) | "…" → "Emitir nota fiscal" (OS com serviço, fora de orçamento/cancelada, sem nota ativa). Linha "Nota fiscal · Aguardando prefeitura / Emitida / Erro / Cancelada" com ponto de status, que abre o detalhe |
| Cliente | "…" → "Emitir uma nota com várias OS" → escolher as OS (`NfseOrdersPicker`) → mesma folha de emissão |
| Folha de emissão (`NfseIssueSheet`) | Valor (serviços, peças fora, desconto), descrição editável, CPF/CNPJ (pede quando falta), data; ✓ emite |
| Detalhe (`NfseInvoiceScreen`) | Status, número, valor, OS, PDF e XML quando emitida, motivo do erro em português, aviso de nota em conflito; "…" → "Cancelar nota" em vermelho com confirmação |

Erros viram texto em pt/en/es por `asaasErrorText(..., nota: true)`, em aviso (`showAppToast`), nunca a mensagem crua.

## Ligar para uma empresa (checklist)

1. Empresa com o Asaas conectado **depois desta versão** (senão reconectar, para assinar os eventos `INVOICE_*`).
2. No painel do Asaas da empresa: conta aprovada, endereço e dados da empresa completos.
3. `npm run asaas:pilot -- --project praticos --company <id> --nfse --yes` (liga `nfseEnabled`).
4. Dono/admin abre Conexão do Asaas → "Nota fiscal" e preenche dados fiscais (inscrição municipal, CNAE, Simples Nacional, item da lista quando a cidade pede).
5. No painel do Asaas → Notas fiscais: enviar o acesso da prefeitura que a cidade exige (certificado digital A1, ou usuário e senha, ou token).
6. Escolher o serviço municipal e o ISS (e demais impostos) — conferir com o contador da empresa.
7. Emitir uma nota de valor baixo para uma OS de teste e acompanhar até "Emitida"; abrir o PDF pela linha "Nota fiscal" da OS.

## Teste no sandbox

Não testado contra o Asaas real. Antes de oferecer:

- [ ] `GET/POST /v3/fiscalInfo` e `GET /v3/fiscalInfo/municipalOptions` com uma conta sandbox: campos aceitos e o que volta em `authenticationType` / `supportsCancellation`.
- [ ] `GET /v3/fiscalInfo/services` com e sem `description`: formato e se a cidade de teste tem lista.
- [ ] `POST /v3/invoices` avulsa com o payload montado (`taxes`, `deductions: 0`, `municipalServiceId` vs `municipalServiceCode`): aceita e agenda.
- [ ] Webhooks `INVOICE_*` chegando na URL da empresa com o `externalReference`; nota passando a "Emitida" com PDF e XML.
- [ ] `GET /v3/invoices?externalReference=` acha a nota agendada (conferência de create sem resposta).
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
