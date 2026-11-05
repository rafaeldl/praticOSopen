# NFS-e direta (Emissor Nacional, sem Asaas)

Documento técnico da emissão de NFS-e direto no Sistema Nacional (Sefin/ADN). Desenho e decisões: [`superpowers/specs/2026-11-05-nfse-direta-design.md`](superpowers/specs/2026-11-05-nfse-direta-design.md); pesquisa e spike: [`NFSE_DIRECT_DISCOVERY.md`](NFSE_DIRECT_DISCOVERY.md). Épico: #559. Este arquivo cresce a cada etapa.

## Visão geral

Uma empresa tem um ou mais **emitentes fiscais** (`companies/{cid}/fiscalEmitters`), cada um com o seu certificado A1. O servidor guarda o certificado cifrado, monta e assina a DPS, envia ao governo e grava a nota em `companies/{cid}/invoices` com `provider: 'direct'`. A cobrança pelo Asaas não muda.

## Dados (etapa #562)

Ver a tabela da §7 da spec. Resumo das regras do Firestore:

| Caminho | Lê | Grava |
|---|---|---|
| `companies/{cid}/fiscalEmitters/{id}` | dono, admin, gerente | servidor |
| `companies/{cid}/nfseImports/{batchId}` | dono, admin | servidor |
| `companies/{cid}/invoices`, `settings/nfse` | dono, admin, gerente | servidor |
| `companies/{cid}/private/nfse/**` (emitters, orders, audit) | ninguém | servidor |
| `nfseCertificates/{emitterId}`, `nfseCertificateRequests/{hash}`, `nfseKeyDestructions/{id}` | ninguém | servidor |

Tipos: `firebase/functions/src/models/nfse-direct.types.ts`. App: `lib/models/fiscal_emitter.dart`, `fiscal_address.dart`, campos novos em `customer.dart` e `nfse.dart`. `settings/nfse.autoIssue` usa a mesma chave da nota pelo Asaas com valores próprios (`never` | `selectedCustomers` | `allOrders`); cada motor lê só os seus.

## Cofre do certificado (etapa #561)

Código: `firebase/functions/src/services/nfse/`.

| Arquivo | Faz |
|---|---|
| `certificate.ts` | Abre o .pfx na memória (`node-forge`, aceita PFX "legacy" RC2/3DES), acha o certificado do titular pela chave, confere validade, cadeia até uma raiz ICP-Brasil (`X509Certificate` do Node) e lê o CNPJ (otherName `2.16.76.1.3.3` ou o sufixo `:CNPJ` do CN) |
| `icp-brasil-roots.ts` | Raízes v5, v10, v11 e v12 baixadas do ITI, com a impressão SHA-256 de cada uma. Raiz nova: acrescentar aqui |
| `envelope.ts` | DEK nova de 256 bits por certificado, AES-256-GCM, com dado adicional `praticos/nfse-cert/v1/{companyId}/{emitterId}` (cópia para outro documento não abre) |
| `key-vault.ts` | Cloud KMS: chave `nfse-certs/emitter-{emitterId}` por emitente, criada com `destroyScheduledDuration` de 24 h; versão nova na troca; destruição da versão ao apagar |
| `certificate-vault.service.ts` | `storeCertificate` (adicionar CNPJ ou trocar), `loadCertificate` (para uma chamada, sem cache), `deleteCertificate`, `purgeExpiredCertificates` (vencido há mais de 90 dias), `deleteCompanyCertificates` (exclusão de conta), `processPendingKeyDestructions` |
| `errors.ts` | Códigos `CERT_*`, `EMITTER_*`, `TERMS_NOT_ACCEPTED`, `KEY_VAULT_UNAVAILABLE` → HTTP |

Rota: `firebase/functions/src/routes/v1/nfse-certificate.routes.ts`, para montar em `/v1/app/nfse/emitters` na função `nfseApi` (etapa #563). Só dono e admin, só com `settings/payments.nfseDirectEnabled`.

- `POST /certificate` `{ pfxBase64, password, termsVersion }`: adiciona o CNPJ (cria o emitente com CNPJ e razão social do certificado; regime, cidade e serviço vêm das consultas da etapa #563 e da importação).
- `PUT /:emitterId/certificate`: troca (o CNPJ tem de ser o do emitente).
- `DELETE /:emitterId/certificate`: apaga de verdade.

### Regras

1. Senha e .pfx nunca são gravados nem logados; os logs levam só o código do erro.
2. Em `nfseCertificates/{emitterId}` ficam `ciphertext`, `iv`, `tag`, `wrappedDek`, `kmsKeyVersion`, `taxId`, `notAfter`, `status`, `termsVersion` (base64 nos binários). O emitente mostra só titular, validade, quem enviou e quando.
3. Um CNPJ é emitente uma vez por empresa (`EMITTER_ALREADY_EXISTS`).
4. Trocar: a chave do emitente ganha versão nova (primária) e a antiga é destruída.
5. Apagar: apaga o material e a DEK cifrada e agenda a destruição da versão (24 h, dá para desfazer no console do KMS nesse prazo). Depois disso, qualquer cópia do documento em backup fica ilegível. O emitente e as notas ficam; `certificate.status` vira `deleted` (ou `expired` na limpeza dos 90 dias).
6. Se o KMS não destruir na hora, a versão vai para `nfseKeyDestructions` e `processPendingKeyDestructions` tenta de novo (rotina diária da `nfseApi`).
7. Auditoria em `companies/{cid}/private/nfse/audit`: ação (`upload`, `replace`, `delete`, `purge-expired`, `destroy-failed`), emitente, quem, quando, aparelho (`x-app-version` ou user agent) e IP. O upload grava a versão do termo aceito (`NFSE_CERTIFICATE_TERMS_VERSION`).

### Cloud KMS (configurado em 2026-11-05)

Feito à mão por um dono do projeto. Estado em produção:

| Item | Valor |
|---|---|
| API | `cloudkms.googleapis.com` ligada no projeto `praticos` |
| Key ring | `projects/praticos/locations/southamerica-east1/keyRings/nfse-certs` |
| Chaves | uma por emitente, `emitter-{emitterId}`, criadas pelo código no primeiro certificado (`ENCRYPT_DECRYPT`, `SOFTWARE`, `destroyScheduledDuration` 86400 s, labels `app=praticos`, `use=nfse-certificate`). O prazo de 24 h vem do código na criação de cada chave; o key ring não tem esse campo |
| Conta | `nfse-api@praticos.iam.gserviceaccount.com`, usada só pela `nfseApi` e pela `nfseDaily` (`NFSE_SERVICE_ACCOUNT` em `src/nfse-api.ts`) |
| Variáveis | nenhuma obrigatória. `NFSE_KMS_LOCATION` (padrão `southamerica-east1`) e `NFSE_KMS_KEY_RING` (padrão `nfse-certs`); o projeto vem de `GCLOUD_PROJECT`. Sem segredos |

Permissões da `nfse-api` (nada de KMS no projeto):

| Onde | Papel | Para quê |
|---|---|---|
| key ring `nfse-certs` | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | cifrar e decifrar a DEK |
| key ring `nfse-certs` | `projects/praticos/roles/nfseKeyManager` (papel próprio: `cloudkms.cryptoKeys.create`, `.get`, `.update`, `cloudkms.cryptoKeyVersions.create`, `.destroy`) | criar a chave do emitente, versão nova na troca, trocar a primária, destruir a versão |
| projeto | `roles/datastore.user` | Firestore |
| bucket `praticos.appspot.com` | `roles/storage.objectUser` | XML da nota em `tenants/{cid}/invoices/` |

Comandos usados (para recriar em outro projeto, troque `praticos`):

```bash
gcloud services enable cloudkms.googleapis.com --project praticos
gcloud kms keyrings create nfse-certs --location southamerica-east1 --project praticos
gcloud iam service-accounts create nfse-api --display-name "NFS-e direta (nfseApi)" --description "Unica conta que decifra os certificados A1" --project praticos
gcloud iam roles create nfseKeyManager --project praticos --title "NFS-e: chaves do emitente" --stage GA \
  --permissions cloudkms.cryptoKeys.create,cloudkms.cryptoKeys.get,cloudkms.cryptoKeys.update,cloudkms.cryptoKeyVersions.create,cloudkms.cryptoKeyVersions.destroy
SA=serviceAccount:nfse-api@praticos.iam.gserviceaccount.com
gcloud kms keyrings add-iam-policy-binding nfse-certs --location southamerica-east1 --project praticos --member $SA --role roles/cloudkms.cryptoKeyEncrypterDecrypter
gcloud kms keyrings add-iam-policy-binding nfse-certs --location southamerica-east1 --project praticos --member $SA --role projects/praticos/roles/nfseKeyManager
gcloud projects add-iam-policy-binding praticos --member $SA --role roles/datastore.user --condition=None
gcloud storage buckets add-iam-policy-binding gs://praticos.appspot.com --member $SA --role roles/storage.objectUser
```

O deploy pelo CI (`github-actions-deployer`) já pode usar a conta: tem `roles/iam.serviceAccountUser` no projeto.

#### Quem mais alcança as chaves

- As outras Functions rodam com a conta padrão de computação (v2) ou `praticos@appspot` (as duas v1). Ambas têm Editor, que não tem `useToEncrypt`, `useToDecrypt` nem `cryptoKeyVersions.destroy`, e nenhuma está na política do key ring ou das chaves. Por isso o `accountApi`, ao apagar uma conta, não destrói a versão: ela vai para `nfseKeyDestructions` e a `nfseDaily` destrói no dia seguinte.
- Os donos do projeto (papel Owner) conseguem decifrar e destruir. É do papel e não muda.
- Quem pode se passar pela `nfse-api` (papel `serviceAccountTokenCreator` ou `actAs`) também alcança as chaves. Revisar essa lista ao mexer em IAM no projeto.

#### Teste em produção (2026-11-05)

Script local rodando como `nfse-api` (ADC com impersonação, permissão `serviceAccountTokenCreator` dada ao dono só durante o teste e tirada depois), com certificado falso gerado na hora (`__tests__/test-certificates.ts`) e empresa descartável `kms-smoke-…`:

1. `storeCertificate`: criou a chave `emitter-{id}`, versão 1, e gravou `nfseCertificates/{id}`.
2. `loadCertificate`: abriu chave e cadeia.
3. `deleteCertificate`: apagou o material e agendou a destruição na hora (fila vazia).
4. `loadCertificate` de novo: `CERT_NOT_FOUND`.
5. `gcloud kms keys versions list`: versão 1 em `DESTROY_SCHEDULED`, destruição 24 h depois.
6. Limpeza: empresa, certificado e fila apagados. A chave de teste fica no key ring sem versão utilizável (o KMS não apaga chaves).

Para conferir o estado de uma chave:

```bash
gcloud kms keys versions list --key projects/praticos/locations/southamerica-east1/keyRings/nfse-certs/cryptoKeys/emitter-{emitterId}
gcloud kms keyrings get-iam-policy nfse-certs --location southamerica-east1 --project praticos
```

## Motor de emissão (etapa #563)

Código: `firebase/functions/src/services/nfse/` e `firebase/functions/src/nfse-api.ts`.

| Arquivo | Faz |
|---|---|
| `layouts/v20260209.ts`, `layouts/v20261020.ts` | Montam a DPS de cada pacote (produção usa 20260209, testes 20261020). Diferenças: `finNFSe` só no 20261020; ordem de `cNBS` × `xDescServ` |
| `layouts/common.ts` | Regras por regime e texto: prestador só com CNPJ, IM e regime (E0121, E0128); MEI sem `regApTribSN` nem `tribFed`, `indTotTrib=0`; Simples com `regApTribSN`, PIS/COFINS CST 08 e `pTotTribSN`; sem retenção nem `pAliq`; textos só Latin-1, sem quebra de linha (fora a descrição) |
| `layouts/v2027.ts`, `layouts/ibscbs.ts`, `layouts/ibscbs-table.ts` | Leiaute 2027: o mesmo pacote de cada ambiente com o grupo `IBSCBS` (ver "Leiaute 2027 (IBS/CBS)" abaixo) |
| `dps.ts` | Id da DPS (cidade + 1/2 + documento + série + número), `dhEmi` em Brasília com recuo de 5 s sem voltar ao dia anterior, escolha do leiaute por ambiente e data de competência (`config/nfse.layoutByEnvironment`), evento de cancelamento e101101 |
| `signature.ts` | XMLDSig enveloped RSA-SHA1 C14N (`xml-crypto`) |
| `sefin-client.ts` | mTLS com a chave e a cadeia do cofre num `https.Agent` por chamada; `POST /nfse`, `GET /dps/{id}`, `GET /nfse/{chave}`, `POST /nfse/{chave}/eventos`, `GET` no ADN. Recusa com código é resposta; tempo esgotado, rede, 5xx ou resposta sem nota viram `SefinUnavailableError` ("sem resposta certa") |
| `refusals.ts` | Tabela de recusas por código em pt/en/es, com o grupo que a folha abre (`customerData`, `emitterSetup`, `certificate`, `other`) |
| `description.ts` | Descrição pela regra fixa (nome do catálogo + detalhe sem repetir palavra, estilo do emitente, uma linha por OS) e `xInfComp` "OS 182 · Emitida pelo PraticOS (praticos.app)" |
| `totals.ts` | Notas do ano e do mês por emitente (menos canceladas) e aviso do MEI a 80% e acima do teto (`config/nfse.meiAnnualLimit`, R$ 81.000) |
| `registry.service.ts` | CNC (inscrição municipal, `HABILITADO`), convênio da cidade, alíquota do serviço na data e CNPJ pela BrasilAPI |
| `issue.service.ts` | Prévia, emitir, conferir, cancelar e recalcular o faturamento |
| `config.ts` | `config/nfse`: `environment` (`production` padrão, `test`), `layoutByEnvironment`, `meiAnnualLimit` |

Rotas (`routes/v1/nfse-direct.routes.ts`, em `/v1/app/nfse/direct` na `nfseApi`), dono, admin e gerente:

- `POST /invoices/preview` `{ orderIds, emitterId? }`: valor, descrição, emitente marcado e lista, destinatário, o que falta (`taxId`, `address`, `email`), aviso do MEI, OS que já têm nota.
- `POST /invoices` `{ orderIds, emitterId?, description?, recipient? }`: 201 emitida, 202 sem resposta certa ainda (`creating`), 422 `NFSE_REFUSED` com `details.refusal`.
- `POST /invoices/:id/cancel` `{ reason: 'issueError' | 'serviceNotProvided' }`: 422 `CANCEL_REFUSED` com `details.usePortal` quando a cidade recusa.
- `POST /invoices/:id/reconcile`: confere uma nota `creating` agora.

### Numeração e idempotência

1. Uma transação reserva o número (`private/nfse/emitters/{id}.nextDpsNumber`), cria a nota `creating` com `dps { id, series, number }` e trava as OS (`private/nfse/orders/{orderId}`). O que entra na DPS fica em `private/nfse/dps/{invoiceId}` para reenviar a mesma.
2. Emitida: grava `accessKey`, `number` (o `nNFSe` do governo), `xmlPath` (`tenants/{cid}/invoices/{id}/nfse.xml`), `lastEmitterId` no cliente da OS e o faturamento do emitente.
3. Recusada: `error` com `errorCode` e `refusal`; as OS ficam livres; o número fica com a DPS recusada (a próxima usa o seguinte).
4. Sem resposta certa: continua `creating` e travada. Depois de 3 minutos, `reconcileDirectInvoice` pergunta `GET /dps/{id}`: existe → busca a nota e grava; não existe → reenvia a mesma DPS (mesmo número, `dhEmi` novo). A rotina diária `nfseDaily` confere todas as `creating`.

### Leiaute 2027 (IBS/CBS) (etapa #575)

A partir da competência 01/01/2027 a DPS do Simples e do MEI leva o grupo `infDPS/IBSCBS` (Anexo VI v1.04.01, linha 373: "Para optantes do Simples Nacional, os grupos IBSCBS só serão obrigatórios a partir de 2027"). Os dois XSD publicados (produção 20260209 e Produção Restrita 20261020) já têm o grupo, como opcional, então o leiaute 2027 é o pacote de cada ambiente mais o grupo:

| Leiaute | Base | Diferença no `IBSCBS` |
|---|---|---|
| `v2027_20260209` | produção | `finNFSe` dentro do grupo, `cIndOp` obrigatório, `CST`/`cClassTrib` em `trib/gIBSCBS` |
| `v2027_20261020` | Produção Restrita | `finNFSe` já no `infDPS`, `CST`/`cClassTrib` direto em `trib` |

O que vai no grupo: `cIndOp`, `indDest=0` (quem recebe o serviço é o tomador), `CST` e `cClassTrib`. Valores não: a calculadora do governo calcula IBS e CBS e recusa código errado (E0858-E0860, E0901, E0958), o que volta como recusa normal.

**De onde vêm os códigos.** `ibscbs-table.ts` é gerado do Anexo VIII (tabela de correlação item LC 116 × NBS × cIndOp × cClassTrib, versão 20261026) por `firebase/functions/scripts/nfse/build-ibscbs-table.py`. Regra:

1. NBS do serviço do emitente → o primeiro `cIndOp` da linha e `cClassTrib` 000001 (tributação integral) quando a linha tem, senão o primeiro. Para oficina (14.01) dá 050101: serviço feito no estabelecimento; 050102 é "em outro lugar".
2. Sem NBS: o par que a maioria das NBS do item dá (14.01 → 050101/000001 em 23 de 25).
3. Serviço fora da tabela: 100301 (demais serviços) e 000001; o governo julga.
4. `service.operationIndicator`/`service.taxClassification` na `DpsInput` ganham dos três (ainda não ligados ao cadastro do emitente).

`CST` = 3 primeiros dígitos do `cClassTrib`.

**Quando liga.** `layoutFor(ambiente, config, dataDeCompetência)`. Sem configuração: até 31/12/2026 o pacote do ambiente; de 01/01/2027 o `v2027_*` do mesmo pacote. `config/nfse.layoutByEnvironment` aceita, por ambiente, um id (vale sempre) ou uma agenda `[{ layout }, { from: 'AAAA-MM-DD', layout }]`; passo com id desconhecido ou data malformada é ignorado, e sem passo válido volta ao padrão.

- Testar antes de janeiro: `config/nfse` com `environment: 'test'` e `layoutByEnvironment.test: 'v2027_20261020'` (o governo aceita IBSCBS desde a competência 01/01/2026, E0850).
- Segurar em janeiro se der problema: `layoutByEnvironment.production: 'v20260209'`. Um id fixo vale para sempre e passa por cima da troca de 2027: tirar assim que resolver, senão o Simples e o MEI ficam sem IBSCBS e o governo recusa.

**Pendências conhecidas (acompanhar no portal):**

- `regApIBSCBSSN` (regime do IBS/CBS no Simples) e `cAtvSN` (atividade do Simples) estão na NT 009 §2.4 e no Anexo VI, mas em nenhum XSD publicado; mandar hoje quebra o schema. Quando sair o XSD, é um módulo novo (a tabela já traz `cAtvSN` por NBS).
- No Anexo VI 1.04.01 o `indDest` sai do `IBSCBS` e vai para o `infDPS`, e aparecem `indZFMALC`, `indDoacao`, `condominios`, `gPgtoVinc`. Ainda não estão em XSD.
- Falta a emissão de verdade no ambiente de testes (critério da issue #575): ver se `cIndOp` 100301/050101 passa sem endereço do tomador.

### Ainda não ligado

`nfseApi` e `nfseDaily` estão em `src/nfse-api.ts`, exportadas pelo `index.ts` e rodando como `nfse-api@`. As rotas ficam fechadas enquanto `nfseDirectEnabled` estiver desligada na empresa. Depois do primeiro deploy, conferir no dia seguinte, nos logs, que a `nfseDaily` rodou (linha `[nfseDaily]`) e não parou por falta de permissão. O PDF (DANFSe) é a etapa #564, a importação e a leitura diária do ADN são a #569, a emissão automática é a #571.

Testes: DPS dos dois regimes nos quatro leiautes (com e sem IBS/CBS) validada contra os XSD oficiais (`__tests__/fixtures/xsd/`, via `xmllint-wasm`), assinatura conferida, respostas do governo gravadas como fixtures. Nada vai ao governo nos testes.

## Cliente: dados para nota (etapa #568)

Só aparece com `settings/payments.nfseDirectEnabled` ligada (`loadCustomerInvoiceConfig`, em `lib/screens/customers/customer_invoice_fields.dart`). Com ela desligada, o CPF/CNPJ continua em "Mais dados", como antes.

- **Grupo "Dados para nota"** no cadastro do cliente (cartão no cadastro novo, link "+ Dados para nota" na edição): CPF/CNPJ, razão social, CEP, rua, número, complemento, bairro, cidade, UF e e-mail da nota (vazio, a nota vai para o e-mail do cliente). Grava `taxId`, `legalName`, `fiscalAddress` e `invoiceEmail`.
- **Busca do CNPJ**: com um CNPJ numérico válido, o app consulta a BrasilAPI (dados públicos da Receita) e preenche razão social, endereço com o código IBGE da cidade e e-mail. Mostra "Confira antes de salvar"; nada é salvo sem o "Salvar". CNPJ alfanumérico ainda não tem consulta pública.
- **Busca do CEP**: com 8 dígitos, o ViaCEP preenche rua, bairro, cidade, UF e o código IBGE. Quem digita outra cidade perde o código (a nota pede o código; a folha de emissão abre os campos).
- As buscas só escrevem em campo vazio ou no que outra busca escreveu, nunca por cima do que a pessoa digitou. Sem internet ou sem resultado: "Preencha à mão". Serviço: `lib/services/fiscal_lookup_service.dart`.
- **CPF/CNPJ único na empresa**: ao salvar um número que outro cliente já tem (só quando o número mudou), o app bloqueia com "REVENDA EXEMPLO LTDA já tem este CNPJ" e oferece "Mandar as notas desta loja para ela": salva o cliente sem o número e com `invoiceRecipient` apontando para o outro. A conferência usa a lista de clientes da empresa (`findCustomerWithTaxId`); corrida entre dois aparelhos é aceita, como na spec.
- **Nota fiscal para**: "…" do cliente → "Mandar a nota para outro cliente" abre "Para quem vai a nota?" (tela de escolher, com "Nenhum" primeiro e ✓ no atual). A linha "Nota fiscal para" só aparece quando preenchida, na tela do cliente e no grupo; tocar troca ou tira. Precisa de `manageCustomers`.
- **Emitir nota sozinha**: interruptor do cliente (`autoIssueInvoice`) que só aparece quando `settings/nfse.autoIssue` é `selectedCustomers` (vem desligado) ou `allOrders` (vem ligado e serve para tirar o cliente da regra). Quem não lê `settings/nfse` (sem acesso a cobranças) não vê o interruptor.

Fora desta etapa: app web (o cliente no web não tem esses campos ainda), oferta na 3ª nota e a emissão automática no servidor (etapa 11 da spec).
