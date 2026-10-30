# Nota fiscal de serviço (NFS-e) pelo Asaas

> Status: **pronta, desligada por padrão.** Só aparece numa empresa quando o servidor liga `nfseEnabled` em `settings/payments` (como o `asaasEnabled` do piloto de cobrança). Fluxo principal validado no sandbox em 2026-10-28 (ver [Teste no sandbox](#teste-no-sandbox)); falta o piloto com um cliente real.
> Base: [`ASAAS_INTEGRATION.md`](ASAAS_INTEGRATION.md) (conexão, webhook, permissões). Doc do Asaas: https://docs.asaas.com/docs/notas-fiscais

## Visão Geral

A empresa emite a nota fiscal de serviço da OS pela própria conta Asaas. O Asaas manda a nota para a prefeitura e avisa por webhook quando ela é emitida, recusada ou cancelada.

- **O Asaas só emite NFS-e** (serviço), não NF-e (produto). Por isso a nota leva **só os serviços da OS**; as peças ficam de fora, e a folha de emissão diz isso.
- **Uma nota por OS** (padrão), mesmo quando o cliente pagou várias OS juntas. A nota é da OS, não do pagamento.
- **Uma nota com várias OS** (opção, para cliente mensal ou de contrato): escolhida pela pessoa no cliente ("…" → "Emitir uma nota com várias OS").
- **Quando emitir** (por empresa, `settings/nfse.autoIssue`): "Só quando eu pedir" (padrão), "Quando a OS for paga" ou "Quando a OS for concluída" (empresas que emitem a nota antes de receber). Ver [Emissão automática](#emissão-automática).
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
| `services/asaas/invoice-customer.service.ts` | E-mail e endereço com CEP do cliente que a prefeitura exige: o que falta, envio ao cliente do Asaas e cópia no cadastro (ver [Dados do cliente](#dados-do-cliente)) |
| `services/asaas/nfse-setup.service.ts` | Configuração fiscal (`/v3/fiscalInfo`), serviços municipais, serviço padrão e o que falta |
| `services/asaas/asaas-client.ts` | `getCustomer`, `updateCustomer` (`PUT /v3/customers/{id}`), `getFiscalInfo`, `saveFiscalInfo`, `getMunicipalOptions`, `listMunicipalServices`, `createInvoice`, `authorizeInvoice`, `cancelInvoice`, `getInvoice`, `listInvoicesByExternalReference` |
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
| `POST /invoices/preview` | `manage:payments` | Valor, descrição, cliente, CPF/CNPJ e os dados do cliente que faltam para a nota (`customer.contact`, `customer.missingData`) de uma ou mais OS |
| `POST /invoices` | `manage:payments` | Emite uma nota para uma ou mais OS (até 50) do mesmo cliente; `customerData` leva o e-mail/endereço digitados na folha |
| `POST /invoices/{id}/cancel` | `manage:payments` | Cancela; `onlyOnAsaas` só para nota que a prefeitura não cancela |

`manage:payments` = dono, admin e gerente. Consultor e técnico não emitem nem cancelam.

### Emissão (`POST /invoices`)

1. Confere flag, conta, configuração pronta (`nfseReady`, senão `NFSE_NOT_READY`) e feita na conta conectada (`NFSE_SETUP_NEEDED`), OS do mesmo cliente (`ORDER_NOT_OF_CUSTOMER`), OS fora de orçamento/cancelada (`NFSE_ORDER_NOT_ALLOWED`) e valor de serviço (`NO_SERVICES`).
2. CPF/CNPJ do cliente: o enviado (`customerTaxId`, que também é gravado no cliente) ou o do cadastro; sem ele, `TAX_ID_REQUIRED`.
3. Confere com o Asaas as notas antigas que ainda travam essas OS (ver [Conferência com o Asaas](#conferência-com-o-asaas)). Numa transação: lê as travas `private/nfse/orders/{orderId}`; se alguma aponta para nota ativa, `ORDER_HAS_INVOICE`. Cria a nota `creating` e grava as travas.
4. Acha ou cria o cliente no Asaas (já com o e-mail e o endereço digitados) e confere os [dados do cliente](#dados-do-cliente): faltando algo, `CUSTOMER_DATA_REQUIRED` antes de criar a nota. Depois chama `POST /v3/invoices` (avulsa) com `externalReference` = `{companyId}:nf:{invoiceId}`, `serviceDescription`, `observations` ("OS 182, 190"), `value`, `deductions: 0`, `effectiveDate`, serviço municipal e `taxes`. O `municipalServiceName` vai cortado em **250 caracteres** (com "…"): o Asaas recusa maior (400 `invalid_name`, sandbox 2026-10-29) e a lista da cidade tem nomes maiores (o 14.01.01, de mecânica, tem 297). A configuração e a nota guardam o nome inteiro.
5. Grava o id do Asaas **logo que ele responde**, antes de qualquer outra coisa, e depois o status. Cada nota guarda a conta em que foi emitida (`asaasEnvironment`, `asaasWalletId`).
6. Se o Asaas **recusar** (400, 401, 403, 404 ou 422), nada foi criado: a nota é apagada, as travas saem e o app recebe o motivo (ver [Recusa do Asaas](#recusa-do-asaas)). **Sem resposta certa** (tempo esgotado, 408, 5xx, rede) o Asaas pode ter criado a nota: ela fica `creating` e a OS continua travada até a conferência (repetir na hora dá `ORDER_HAS_INVOICE`, nunca duas notas).
7. Com data de hoje, chama `POST /v3/invoices/{id}/authorize` para emitir na hora. Se o Asaas **recusar a emissão** (400, 401, 403, 404 ou 422; por exemplo "E-mail do cliente incompleto.; Endereço do cliente incompleto.; CEP do cliente é inválido."):
   - a nota agendada **é cancelada no Asaas** (agendada ainda não foi à prefeitura, cancelar é só no Asaas) e fica `error` com `errorCode` e o texto do Asaas em `statusDescription`. A OS fica livre: o usuário corrige e emite de novo;
   - `errorCode` e o que o app recebe seguem a [Recusa do Asaas](#recusa-do-asaas);
   - com o cancelamento feito, a nota ganha `canceledOnAsaas: true` e eventos atrasados dessa nota do Asaas (`INVOICE_CANCELED`, `INVOICE_CREATED`) não mexem mais nela: o motivo fica;
   - se o cancelamento falhar, a nota fica `scheduled` com o motivo e a OS travada (log `ALERT`): cancelar na tela da nota e emitir de novo. Ela **continua viva no Asaas** e segue os eventos dele: `INVOICE_ERROR` troca o nosso motivo pelo do Asaas, e se o Asaas emitir depois (cliente corrigido no painel), `INVOICE_AUTHORIZED` a deixa emitida e a OS travada de novo (ou em `conflict`, se a OS já tiver outra nota).

   Escolhemos cancelar em vez de manter agendada para tentar de novo: assim não precisa de rota de "tentar emitir de novo", a emissão repetida é a mesma de sempre e a nota recusada não fica parada como "Aguardando prefeitura" sem motivo. **Sem resposta certa** do authorize, a nota fica agendada (o Asaas emite na data).

### Recusa do Asaas

Quando o Asaas recusa o create ou o authorize, o texto dele diz o que corrigir. `refusalCode` (`invoice.service.ts`) separa pelo texto:

| Texto do Asaas fala de | Código | Na folha de emissão |
|---|---|---|
| e-mail, endereço, CEP, bairro ou número **do cliente** ("CEP do cliente é inválido") | `CUSTOMER_DATA_REQUIRED` | Aviso com o texto do Asaas e **todos** os campos do cliente abertos (preenchidos com o que o Asaas tem), não só os que faltam |
| serviço municipal (texto, ou código `invalid_name`/`invalid_municipalService*`), alíquota, ISS, inscrição municipal, CNAE, regime, tributação, dados fiscais | `NFSE_SETUP_REJECTED` | Aviso com o texto do Asaas e "Configurar", que abre a configuração da nota (`NfseSetupScreen`). Quem não configura (gerente) vê "Peça ao dono…". `NFSE_NOT_READY` e `NFSE_SETUP_NEEDED` fazem o mesmo |
| outra coisa (inclusive "CPF/CNPJ do cliente inválido", que a folha não edita, e a descrição livre do serviço, que a folha já mostra) | `ASAAS_VALIDATION_ERROR` (nota gravada `ASAAS_REJECTED`) | Aviso "O Asaas recusou a nota: {texto do Asaas}" |

O Asaas recusar **salvar o cliente** (400 no `PUT /v3/customers/{id}` ou na criação com o endereço digitado) com texto sobre e-mail/endereço também vira `CUSTOMER_DATA_REQUIRED` com o texto dele: a folha reabre os campos.

O texto do Asaas vai na resposta em `error.detail` (`toHttpError`), e o app o mostra só nas telas da nota. O log do servidor grava o status e os pares `código: texto` do Asaas (`asaasErrorLog`, texto até 200 caracteres), nunca o payload nem os dados do cliente.

### Dados do cliente

A prefeitura não aceita nota sem o **e-mail** e o **endereço com CEP** do cliente (teste no sandbox em 2026-10-28: com só nome e CPF, o `authorize` respondeu 400 "E-mail do cliente incompleto.; Endereço do cliente incompleto.; CEP do cliente é inválido."; com `email`, `postalCode`, `address`, `addressNumber` e `province` no cliente do Asaas, a mesma nota foi emitida). O cliente do PraticOS só tem `address` em texto livre, então o endereço da nota fica no **cliente do Asaas**:

- **Prévia:** lê o cliente do Asaas já ligado (sem criar) e devolve `customer.contact` (o que ele tem; o e-mail do PraticOS completa) e `customer.missingData` (`email`, `postalCode`, `address`, `addressNumber`, `province`). Asaas fora do ar: conta só o e-mail do PraticOS.
- **Folha:** pede o que falta (e-mail; ou CEP, rua, número, complemento e bairro). O ✓ só fica azul com e-mail válido e CEP de 8 dígitos.
- **Emissão:** cliente novo no Asaas já é criado com esses dados. Depois o servidor junta o digitado, o que o Asaas tem e o e-mail do PraticOS; o que mudou vai por `PUT /v3/customers/{id}`. Ainda faltando: `CUSTOMER_DATA_REQUIRED` (400), nada é criado.
- **No cadastro do PraticOS:** o digitado entra só onde está vazio (e-mail; endereço como texto "Rua, número, complemento - bairro - CEP 00000-000"). Nunca troca o que o usuário escreveu.
- **Emissão automática:** cliente sem esses dados grava `auto-{orderId}` com `errorCode: CUSTOMER_DATA_REQUIRED`; o usuário emite pelo "…" e a folha pede os dados.

### Emissão automática

`settings/nfse.autoIssue`: `manual` (padrão, campo ausente), `paid` ou `completed`. Escolhido na configuração da nota ("Emitir a nota"), salvo pelo mesmo `PUT /setup/service` (sem o campo, o servidor mantém o que estava).

1. O gatilho único da OS (`onOrderUpdatedAsaas` → `handleOrderUpdatedAsaas`) chama `autoIssueInvoice` quando `payment` vira `paid` (momento `paid`) ou `status` vira `done` (momento `completed`). Só na virada: salvar de novo uma OS já paga ou concluída não emite. A OS que vira `paid` só porque o total caiu até o valor já pago não emite: nenhum dinheiro entrou (`syncPaymentStatusWithTotal` grava `paymentSyncedAt`, e o gatilho reconhece a mudança por ele).
2. `autoIssueInvoice` só segue com `nfseEnabled`, `nfseReady`, Asaas conectado e `autoIssue` igual ao momento.
3. **Uma vez por OS:** se a OS já teve qualquer nota (até cancelada, com erro ou automática que falhou), fica com o usuário. Assim cancelar a nota e reabrir/concluir a OS de novo não emite outra.
4. Emite como na emissão manual (`createInvoice`, uma nota só da OS, data de hoje), com `createdBy` `{ id: 'system', name: 'PraticOS' }` e `auto: true`.
5. **Falha que o usuário resolve** (cliente sem CPF/CNPJ, sem e-mail ou endereço, OS só com peças, configuração feita em outra conta, recusa do Asaas): grava `invoices/auto-{orderId}` com `status: 'error'`, `errorCode` (e o texto do Asaas em `statusDescription` quando ele recusou, `ASAAS_REJECTED`). A OS mostra "Nota fiscal · Erro"; o detalhe diz "A nota não saiu sozinha" e o motivo. Não trava a OS: o usuário emite pelo "…". Se o Asaas recusou a **emissão** de uma nota já criada, a própria nota fica com o erro (item 7 da emissão) e não se grava `auto-{orderId}`.
6. **Sem resposta do Asaas**: igual à manual, a nota fica `creating` e travada até a conferência. Erros que não são da OS (flag desligada, OS já com nota, orçamento/cancelada) não gravam nada.

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

O status só anda para a frente (evento atrasado ou repetido não desfaz nota emitida ou cancelada); `canceled` é final; `error` pode ir para qualquer um (a nota foi corrigida e reagendada no Asaas), menos a `error` com `canceledOnAsaas` (o PraticOS desistiu dela e a cancelou no Asaas), que não muda mais.

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

`invoices/{id}`: `asaasInvoiceId`, `status`, `customer {id, name}`, `orderIds`, `orders [{id, number, servicesTotal, productsTotal, discount, value}]`, `value`, `serviceDescription`, `observations`, `effectiveDate`, `municipalServiceName`, `number`, `validationCode`, `pdfUrl`, `xmlUrl`, `statusDescription`, `createdBy`, `createdAt`, `updatedAt`, `authorizedAt`, `canceledAt`, `asaasEnvironment`, `asaasWalletId`, `conflict`, `auto` (emitida sozinha), `errorCode` (por que não saiu: automática que falhou ou emissão recusada pelo Asaas), `canceledOnAsaas` (recusada e cancelada no Asaas pelo PraticOS).

`settings/nfse`: `municipalServiceId`, `municipalServiceCode`, `municipalServiceName`, `taxes {retainIss, iss, pis, cofins, csll, inss, ir}`, `descriptionTemplate`, `autoIssue` (`manual` | `paid` | `completed`), `asaasEnvironment`, `asaasWalletId`.

`private/asaas` (conexão): além dos campos da [integração](ASAAS_INTEGRATION.md), `webhookEvents` (eventos assinados ao conectar).

## App

Tudo fica escondido sem `nfseEnabled` + Asaas conectado (`PaymentSettings.nfseAvailable`) e sem a permissão `chargeOrder` (dono, admin, gerente). `NfseController` (`lib/screens/nfse/nfse_access.dart`) junta flag, permissão e as notas da OS ou do cliente.

| Onde | O quê |
|------|-------|
| Conexão do Asaas | Linha "Nota fiscal" → configuração (`NfseSetupScreen`): o que falta, dados fiscais, acesso da prefeitura (aponta para o painel do Asaas), serviço padrão com impostos e modelo da descrição, e "Emitir a nota" (quando emitir sozinha) |
| OS (`order_screen_v2.dart`) | "…" → "Emitir nota fiscal" (OS com serviço, fora de orçamento/cancelada, sem nota ativa). Linha "Nota fiscal · Aguardando prefeitura / Emitida / Erro / Cancelada" com ponto de status, que abre o detalhe |
| Cliente | "…" → "Emitir uma nota com várias OS" → escolher as OS (`NfseOrdersPicker`) → mesma folha de emissão |
| Folha de emissão (`NfseIssueSheet`) | Valor (serviços, peças fora, desconto), descrição editável, CPF/CNPJ (pede quando falta), e-mail e endereço com CEP do cliente (pede o que falta), data; ✓ emite. Servidor respondendo `CUSTOMER_DATA_REQUIRED`: avisa e recarrega a prévia para mostrar os campos |
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

Validado em 2026-10-28 com uma conta sandbox:

- [x] `GET/POST /v3/fiscalInfo` e `GET /v3/fiscalInfo/municipalOptions`: campos aceitos, `authenticationType` / `supportsCancellation` voltam.
- [x] `GET /v3/fiscalInfo/services`: lista da cidade de teste.
- [x] `POST /v3/invoices` avulsa com o payload montado: aceita e agenda (`SCHEDULED`). Com o nome do serviço 14.01.01 inteiro (297 caracteres), 400 `invalid_name` "A descrição do serviço deve ter no máximo 250 caracteres." (2026-10-29): daí o corte em 250.
- [x] `POST /v3/invoices/{id}/authorize`: com o cliente só com nome e CPF, 400 (e-mail, endereço e CEP do cliente); com os dados completos, `SYNCHRONIZED` → `AUTHORIZED` com número e PDF. Deu a regra dos [dados do cliente](#dados-do-cliente).
- [x] `PUT /v3/customers/{id}` é atualização parcial: mandar só o e-mail e depois só o endereço manteve o e-mail.
- [x] `GET /v3/invoices?externalReference=` acha a nota (conferência de create sem resposta).
- [x] Cancelamento: `PROCESSING_CANCELLATION` → `CANCELED`.

Falta:

- [ ] Webhooks `INVOICE_*` chegando na URL da empresa com o `externalReference`; nota passando a "Emitida" com PDF e XML no app.
- [ ] Recusa da prefeitura (`INVOICE_ERROR`): motivo em `statusDescription` e OS liberada para outra nota.
- [ ] Cidade sem cancelamento pela integração (`CANCEL_NOT_SUPPORTED`).
- [ ] Emissão pelo app com cliente sem endereço: folha pede os dados, servidor atualiza o cliente do Asaas e a nota sai.
- [ ] Emissão automática: com "Quando a OS for concluída", concluir uma OS de teste e ver a nota sair sozinha; com cliente sem CPF, ver "Nota fiscal · Erro" com o motivo.
- [ ] Nota com várias OS: descrição com uma linha por OS e observações "OS 182, 190".

## Regras de Negócio

- Só serviços entram na nota; peças nunca.
- Uma nota ativa por OS; nota com erro ou cancelada libera a OS.
- Uma nota com várias OS só junta OS do **mesmo cliente**, até 50.
- Orçamento e OS cancelada não têm nota.
- Nota só sai com o cliente tendo CPF/CNPJ, e-mail e endereço com CEP no Asaas; a folha pede o que falta.
- Emissão recusada pelo Asaas: a nota agendada é cancelada no Asaas, fica com erro e o motivo, e a OS fica livre para emitir de novo.
- Recusa do Asaas abre o que corrige: dados do cliente na folha, configuração da nota, ou o texto do Asaas.
- Nome do serviço municipal vai ao Asaas com no máximo 250 caracteres.
- Emissão automática: no momento escolhido (paga ou concluída), uma vez por OS, só com a configuração pronta. Nunca junta várias OS numa nota.
- Data da nota: de hoje até 60 dias à frente (horário de São Paulo).
- Emitir/cancelar: dono, admin, gerente. Configurar: dono, admin.
- Cancelar nota emitida depende da prefeitura; quando a cidade não cancela pela integração, o app explica e manda cancelar no site da prefeitura.

## Limitações conhecidas

- Sem push quando a nota é emitida ou recusada (só a linha na OS muda).
- A recusa do Asaas é classificada pelo texto (`refusalCode`): texto novo que não fala de cliente nem de configuração cai no aviso com o texto do Asaas.
- Sem busca de endereço pelo CEP na folha: o usuário digita rua e bairro.
- Endereço do cliente no PraticOS continua texto livre; o endereço estruturado da nota fica só no cliente do Asaas (trocar de conta Asaas pede de novo).
- Nota emitida pelo painel do Asaas, ou vinculada a cobrança pela configuração do Asaas, não aparece no PraticOS.
- Deduções (`deductions`) sempre zero; retenções além do ISS seguem os percentuais do serviço padrão, iguais para todas as notas.
- Estorno de um pagamento não cancela a nota: cancelar à mão se for o caso.
- Emissão automática "quando paga" usa a situação de pagamento da OS: OS paga junto com outras num link de várias OS gera uma nota por OS, não uma nota do pagamento.
