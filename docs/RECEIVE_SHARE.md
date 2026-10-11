# RECEIVE_SHARE.md

## Visão Geral
Receber fotos e PDFs compartilhados de outros apps (Android e iOS). Pergunta "Em qual OS?" e guarda ao tocar na OS.

## Arquitetura
- `receive_sharing_intent` 1.8.1 (fixada: a 1.9 só suporta Swift Package Manager e quebraria o build iOS via CocoaPods). Iniciado em Android e iOS (`receiveShareSupported` em `received_share.dart`); web/desktop não.
- `lib/services/received_share.dart`: roteia por MIME (fallback extensão): imagem -> foto da OS; PDF -> `OrderDocument`; resto é ignorado. Também normaliza caminhos `file://` e identifica as cópias da Share Extension.
- `lib/screens/share/which_order_sheet.dart`: sheet "Em qual OS?" com as OS em aberto (não concluídas/canceladas), mais novas primeiro.
- `lib/services/receive_share_service.dart`: fotos via `PhotoService.uploadOrderPhoto` (`tenants/{companyId}/orders/{orderId}/photos/`, conta na cota); PDFs via `uploadOrderDocument`; grava com `TenantOrderRepository.updateItem`.

### Android
- `AndroidManifest.xml`: `intent-filter` `SEND` e `SEND_MULTIPLE` para `image/*` e `application/pdf`.

### iOS (Share Extension)
- Target `ShareExtension` (`ios/ShareExtension/`), bundle id `br.com.rafsoft.praticos.ShareExtension`. O plugin deriva o id do app tirando o último componente do id da extensão, então o sufixo tem que continuar sendo um componente só.
- `ShareViewController` herda de `RSIShareViewController`: copia os arquivos para o container do App Group e abre o app pelo esquema `ShareMedia-br.com.rafsoft.praticos:share`.
  - PDFs que chegam só como dados (`com.adobe.pdf` sem `public.file-url`, ex.: Mail, Safari) são gravados num arquivo temporário antes de passar para o plugin, que só lê arquivos por URL.
- `Info.plist` da extensão: `NSExtensionActivationRule` (SUBQUERY) aceita só `public.image` e `com.adobe.pdf`; `CFBundleVersion`/`CFBundleShortVersionString` vêm do `Generated.xcconfig` do Flutter (mesma versão do app, exigência da App Store).
- App Group `group.br.com.rafsoft.praticos` nos dois entitlements (`Runner.entitlements` e `ShareExtension.entitlements`) e no build setting `CUSTOM_GROUP_ID` (lido via `AppGroupId` nos Info.plist).
- `Runner/Info-*.plist`: esquema `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` e `AppGroupId`. O plugin se registra como delegate do app, então o `AppDelegate` não muda.
- Build: fase "Embed Foundation Extensions" antes de "Thin Binary" no Runner; `Podfile` com `target 'ShareExtension'` (`inherit! :search_paths`); os `ShareExtension/*.xcconfig` incluem o xcconfig do Pods e o `Generated.xcconfig`, e limitam `OTHER_LDFLAGS` ao `receive_sharing_intent` (a extensão não carrega Firebase etc.).
- Depois de tratar (salvar, cancelar ou ignorar), o app apaga as cópias que ficaram no container do App Group (`isShareExtensionCopy`). Fotos da biblioteca do iPhone nunca são apagadas.
- Assinatura: ver `docs/IOS_CODE_SIGNING.md` (match assina app e extensão).

## Regras
- Tocar na OS já guarda (sem confirmar). Sem usuário/empresa logada, o compartilhamento é ignorado.
- Fora do escopo: sugestão por IA (`aiMatchOrder`), "Criar OS nova com isto", busca.

## Limitações conhecidas (iOS)
- Imagens que um app entrega só como `UIImage` (sem arquivo) são gravadas pelo plugin sempre como `TempImage.png`; se vierem várias assim no mesmo compartilhamento, só a última sobra. A maioria dos apps (Fotos, Arquivos, WhatsApp) entrega arquivo.
- Dois PDFs com o mesmo nome no mesmo compartilhamento: o plugin copia para o mesmo caminho e só o último sobra.
