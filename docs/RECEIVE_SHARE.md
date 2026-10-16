# RECEIVE_SHARE.md

## Visão Geral
Receber fotos e PDFs compartilhados de outros apps (Android e iOS). Pergunta "Em qual OS?" e guarda ao tocar na OS. Dá para buscar a OS ou criar uma Nova OS com os arquivos.

## Arquitetura
- `receive_sharing_intent` 1.8.1 (fixada: a 1.9 só suporta Swift Package Manager e quebraria o build iOS via CocoaPods). Iniciado em Android e iOS (`receiveShareSupported` em `received_share.dart`); web/desktop não.
- `lib/services/received_share.dart`: roteia por MIME (fallback extensão): imagem -> foto da OS; PDF -> `OrderDocument`; resto é ignorado. Também normaliza caminhos `file://` e identifica as cópias da Share Extension.
- `lib/screens/share/which_order_sheet.dart`: sheet "Em qual OS?" no padrão de escolher (`PickerScaffold`, "X" no lugar do voltar): as 20 OS em aberto (não concluídas/canceladas) mais novas primeiro, busca e "+" (Nova OS). Devolve `WhichOrderChoice` (uma OS ou "Nova OS").
  - Busca (`orderMatchesSearch`/`searchOrders`): cliente, número ("193" ou "#193") e nome ou placa do veículo/aparelho, sem diferenciar maiúsculas e acentos (placa ignora hífen e espaço). Procura em todas as OS em aberto e nas últimas 300 da empresa (`createdAt` desc, carregadas uma vez na primeira busca; sem índice novo), então acha OS concluída que ainda falta receber. Canceladas ficam de fora. O campo aparece sempre, mesmo com menos de 10 OS na lista, porque alcança OS que não estão nela.
  - Consultor e técnico só leem as OS que criaram (regras do Firestore): uma consulta por `createdBy.id` (igualdade, ordenada no app) serve para a lista e para a busca.
  - "+" aparece com a mesma regra do "+" ao lado das abas (`createOrder`, não técnico).
- `lib/screens/order/order_route.dart` (`openNewOrder(onCreated:)`): o "+" abre a Nova OS de sempre. No "✓" a OS é criada, sobe as fotos da própria Nova OS e então chama `onCreated` com o id; o serviço grava os arquivos compartilhados com `saveToOrder` (depois das fotos, para uma gravação não apagar a outra) e mostra o "Guardado na OS". No "X" nada é criado. Se a OS não for criada em 2 minutos (sem internet), aparece o aviso de falha.
- `lib/screens/share/receipt_question.dart`: "O que é este arquivo?" (`pickOne`), perguntado depois de tocar numa OS existente (não no "+"):
  - Só quando foi compartilhado **um** arquivo (foto ou PDF), a pessoa recebe nessa OS (`AuthorizationService.canReceiveOnOrder`, que já é falso com "Valores e cobrança" desligado) e a OS tem pagamento sem comprovante ou ainda falta receber (`shouldAskWhatFileIs`). Com vários arquivos, não pergunta: guarda como sempre.
  - Uma linha por pagamento sem comprovante (`paymentsWithoutReceipt`: o mesmo critério do "Anexar comprovante" do Receber; fora Asaas com comprovante próprio e parte de recebimento do cliente): "Comprovante do pagamento de R$ 200 · 12/10". Guarda com `OrderStore.attachReceiptToTransaction` (o mesmo do Receber: `OrderDocument` tipo `receipt` com `linkedTransactionId`, e `receiptDocumentId` no pagamento via `updatePayments`) e mostra "Comprovante guardado na OS 193".
  - "Comprovante de um pagamento novo" (só se falta receber): abre o Receber da OS (`/payment_management`, argumentos `receipt` e `onReceiptUsed`) com o arquivo já anexado. Se a pessoa voltar sem registrar o pagamento com ele, o arquivo é guardado como foto/documento comum da OS.
  - "Só guardar na OS" ou voltar: o comportamento de sempre.
- `lib/services/order_saved_elsewhere.dart`: depois do `saveToOrder`, avisa a OS aberta. A `OrderScreenV2` de uma OS existente escuta e chama `OrderStore.mergeAttachments`, que só acrescenta as fotos e documentos que faltam (por `storagePath`/`url`). Os campos de pagamento (comprovante ligado, pagamento novo) também vêm da cópia salva: um salvamento comum nunca os grava. O resto do que está na tela não muda, e o próximo salvamento da tela já inclui os arquivos (antes, a foto só aparecia ao reabrir e podia sumir no próximo salvamento).
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
- Depois de tratar (salvar, cancelar ou ignorar; na Nova OS, só depois de gravar ou fechar sem salvar), o app apaga as cópias que ficaram no container do App Group (`isShareExtensionCopy`). Fotos da biblioteca do iPhone nunca são apagadas.
- Assinatura: ver `docs/IOS_CODE_SIGNING.md` (match assina app e extensão).

## Regras
- Tocar na OS já guarda (sem confirmar). Sem usuário/empresa logada, o compartilhamento é ignorado.
- "+" cria a OS e guarda nela; fechar a Nova OS sem salvar não cria nada (no "+" não se pergunta se é comprovante).
- Comprovante: só com um arquivo compartilhado; nunca registra pagamento sozinho (o pagamento novo é registrado pela pessoa no Receber).
- Fora do escopo: sugestão por IA (`aiMatchOrder`); pôr a foto compartilhada na Nova OS antes de salvar (para a IA "Foto" ler).

## Limitações conhecidas (iOS)
- Imagens que um app entrega só como `UIImage` (sem arquivo) são gravadas pelo plugin sempre como `TempImage.png`; se vierem várias assim no mesmo compartilhamento, só a última sobra. A maioria dos apps (Fotos, Arquivos, WhatsApp) entrega arquivo.
- Dois PDFs com o mesmo nome no mesmo compartilhamento: o plugin copia para o mesmo caminho e só o último sobra.
