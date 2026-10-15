# PDF_GENERATION.md

## Visão Geral

Geração do PDF da Ordem de Serviço, usado pelo "Compartilhar PDF / Imprimir" da tela de OS
e pela tela de preview (`PdfPreviewScreen`).

O PDF é composto por:

1. **Página principal da OS** — cabeçalho, cliente, resumo financeiro, equipamentos,
   QR Code, **fotos anexadas à OS**, termos e assinaturas.
2. **Uma página por formulário** anexado à OS (checklists/vistorias), com as fotos de
   cada item respondido.

Planos Free recebem marca d'água (ver `FeatureGateService.shouldShowPdfWatermark`).

## Arquitetura

| Arquivo | Responsabilidade |
|---------|------------------|
| `lib/services/pdf/pdf_service.dart` | Orquestra: carrega fontes e imagens, monta o `pw.Document` |
| `lib/services/pdf/pdf_main_os_builder.dart` | Widgets da página principal da OS |
| `lib/services/pdf/pdf_forms_builder.dart` | Widgets das páginas de formulários |
| `lib/services/pdf/pdf_photo_grid.dart` | Grid de fotos compartilhado entre os dois builders |
| `lib/services/pdf/pdf_image_loader.dart` | Download + cache das imagens (logo, badges, fotos) |
| `lib/services/pdf/pdf_localizations.dart` | Strings do PDF (sem acentos, para as fontes Helvetica) |
| `lib/services/pdf/pdf_styles.dart` | Cores, espaçamentos e formato de página |

## Fluxo de Dados

```
OsPdfData (order, customer, company, forms, config, localizations)
        ↓
PdfService.generateOsPdf(data, options)
        ↓
_loadFonts()  +  _loadImages(data, options)   ← PdfImageLoader (HTTP + cache)
        ↓
PdfMainOsBuilder.buildContent(..., osPhotos)  →  página principal
PdfFormsBuilder.buildFormContent(...)         →  uma página por formulário
        ↓
doc.save() → Uint8List
```

## Fotos no PDF

Existem duas origens de fotos, controladas de forma independente por `OsPdfOptions`:

| Origem | Modelo | Opção | Limite |
|--------|--------|-------|--------|
| Fotos anexadas à OS | `order.photos` (`List<OrderPhoto>`) | `includeOsPhotos` | `maxOsPhotos` (default **30**) |
| Fotos de itens de formulário | `form.responses[].photoUrls` | `includeFormPhotos` | `maxPhotosPerItem` (default 8) |

As fotos da OS aparecem na página principal, na seção **"Fotos Anexadas (N)"**, posicionada
entre o QR Code e os Termos/Assinaturas.

### Paginação do grid

`PdfMainOsBuilder.buildPhotosSection` retorna uma **lista de widgets de nível superior**
(e não um único widget) e o grid é um `pw.Wrap`.

Isso é obrigatório: no pacote `pdf`, apenas widgets que implementam `SpanningWidget`
(como `Wrap` e `Table`) conseguem quebrar entre páginas dentro de um `MultiPage`. Um grid
de fotos colocado dentro de uma `Column` não quebra e faz a geração falhar
(`Widget won't fit into the page` / `TooManyPagesException`) quando há muitas fotos.

Por isso `buildContent` devolve:

```dart
[
  buildStatusBar(order),          // barra de status
  Padding(Column(...)),           // cliente + financeiro + equipamentos + QR
  ...buildPhotosSection(osPhotos) // cabeçalho + Wrap (quebra entre páginas)
  Padding(Column(...)),           // termos + assinaturas
]
```

### Regras de negócio

- Fotos sem `url` (ou com URL vazia) são ignoradas e não consomem o limite.
- Downloads que falham (HTTP != 200 ou erro de rede) são descartados silenciosamente —
  a foto é opcional e nunca impede a geração do PDF.
- A seção "Fotos" não é renderizada quando não há nenhuma foto baixada com sucesso.
- O contador do cabeçalho reflete as fotos efetivamente incluídas, não as anexadas.

## Download de imagens

`PdfImageLoader` faz os downloads **em paralelo**, em lotes de
`PdfImageLoader.maxConcurrentDownloads` (5), preservando a ordem original das URLs.

- **Cache em memória** por URL (`_cache`), compartilhado por toda a geração do PDF.
- **Deduplicação de requisições em voo** (`_inFlight`): downloads simultâneos da mesma URL
  compartilham a mesma requisição HTTP.
- O `httpGet` é injetável no construtor (`PdfImageLoader({PdfHttpGet? httpGet})`), o que
  permite testar concorrência e falhas sem rede.

## Exemplos de Uso

```dart
// Padrão: OS + formulários + todas as fotos (até os limites)
final bytes = await PdfService().generateOsPdf(pdfData);

// Somente a OS, sem fotos (PDF leve para envio rápido)
final bytes = await PdfService().generateOsPdf(
  pdfData,
  const OsPdfOptions(includeForms: false, includeOsPhotos: false),
);

// Limitar as fotos da OS
final bytes = await PdfService().generateOsPdf(
  pdfData,
  const OsPdfOptions(maxOsPhotos: 10),
);
```

## PDF sem valores ("Valores e cobrança" desligada)

Quando a empresa desliga "Valores e cobrança" (`Company.useFinancial == false`,
ver `docs/VALUES_AND_BILLING_TOGGLE.md`), o PDF vira um relatório do serviço:

- Sem o card "Resumo" (serviços, produtos, desconto, total, pago); o card do
  cliente ocupa a largura toda.
- Tabela de itens só com Tipo, Descrição e Qtd (sem "Valor unit." e "Total").
- Sem subtotal no cabeçalho de cada equipamento.
- Fotos, checklists, QR Code, termos e assinaturas continuam iguais.

Como é decidido:

| Peça | Regra |
|------|-------|
| `orderPdfShowsValues()` (`pdf_service.dart`) | `company.useFinancial` se gravado; senão o valor resolvido na sessão (`SegmentConfigProvider.useFinancial`, padrão `true`) |
| `OsPdfData.showValues` | usa a regra acima; `showValuesOverride` força um valor |
| `PdfMainOsBuilder(showValues:)` | padrão `true` (comportamento de sempre) |
| `canShareOrderPdf()` | o item "PDF" do menu "…" da OS (nova e antiga) aparece para quem vê preços **ou** quando a empresa desligou a opção (aí todo mundo recebe o PDF sem valores) |

## Recibo (pagamento recebido)

PDF de uma página para mandar ao cliente depois de receber. Arquivo
`lib/services/pdf/receipt_pdf.dart`; quem chama é `shareReceiptPdf`
(`lib/screens/payments/receipt_share.dart`), na tela "Recebimento" e na folha de um pagamento do
Receber da OS.

| Peça | Papel |
|------|-------|
| `ReceiptPdfData.fromReceipt(receipt, orders)` | Recebimento de várias OS; `orders` (atuais) dão o "ainda falta" e a descrição |
| `ReceiptPdfData.fromPayment(order, tx)` | Um pagamento de uma OS, sem documento `Receipt` |
| `buildReceiptPdfContent(data, l10n, format)` | Todos os textos, já traduzidos (`context.l10n`) e formatados (`FormatService`). Puro: é o que os testes verificam |
| `ReceiptPdfService.generate/share` | Desenha (Helvetica, como o PDF da OS) e abre a folha de compartilhar (`Printing.sharePdf`) |

Conteúdo: cabeçalho da empresa (logo, nome, endereço, telefone, e-mail) com "RECIBO" e
"Nº 3F9A1C" (6 primeiros caracteres do id do recebimento/transação); a frase
"Recebemos de {cliente} a quantia de {valor} em {data}."; tabela OS / Descrição (veículos ou
aparelhos da OS, senão o primeiro serviço) / Pago agora / Ainda falta; "Total recebido";
"Falta receber R$ X dessas OS." quando sobra algo; rodapé "Registrado por {nome} · Nº …".
Arquivo `Recibo-3F9A1C.pdf` (no idioma do app).

Diferente do PDF da OS, os textos vêm do `AppLocalizations` com acentos: `pdfSafeText` só tira
o que a Helvetica não desenha (fora do Latin-1, como emoji). Pagamentos do Asaas não geram
recibo aqui (usam o comprovante do próprio Asaas).

## Testes

- `test/services/pdf/pdf_main_os_builder_photos_test.dart` — seção de fotos, ausência de
  regressão sem fotos e quebra do grid entre páginas.
- `test/services/pdf/pdf_image_loader_test.dart` — limite, URLs vazias, paralelismo,
  falhas, cache e deduplicação.
- `test/services/pdf/receipt_pdf_test.dart` — textos do recibo (frase, tabela, total, "falta",
  quem registrou, número, idioma) e geração do PDF sem rede.
