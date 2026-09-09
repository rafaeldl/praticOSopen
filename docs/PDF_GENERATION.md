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

## Testes

- `test/services/pdf/pdf_main_os_builder_photos_test.dart` — seção de fotos, ausência de
  regressão sem fotos e quebra do grid entre páginas.
- `test/services/pdf/pdf_image_loader_test.dart` — limite, URLs vazias, paralelismo,
  falhas, cache e deduplicação.
