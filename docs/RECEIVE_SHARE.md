# RECEIVE_SHARE.md

## Visão Geral
Receber fotos e PDFs compartilhados de outros apps (Android). Pergunta "Em qual OS?" e guarda ao tocar na OS. iOS (Share Extension) fica fora: exige assinatura (`risk:high`).

## Arquitetura
- `AndroidManifest.xml`: `intent-filter` `SEND` e `SEND_MULTIPLE` para `image/*` e `application/pdf`.
- `receive_sharing_intent` 1.8.1 (fixada: a 1.9 só suporta Swift Package Manager e quebraria o build iOS via CocoaPods). Só é iniciado em Android (`ReceiveShareService.isSupported`); em iOS nada muda.
- `lib/services/received_share.dart`: roteia por MIME (fallback extensão): imagem -> foto da OS; PDF -> `OrderDocument`; resto é ignorado.
- `lib/screens/share/which_order_sheet.dart`: sheet "Em qual OS?" com as OS em aberto (não concluídas/canceladas), mais novas primeiro.
- `lib/services/receive_share_service.dart`: fotos via `PhotoService.uploadOrderPhoto` (`tenants/{companyId}/orders/{orderId}/photos/`, conta na cota); PDFs via `uploadOrderDocument`; grava com `TenantOrderRepository.updateItem`.

## Regras
- Tocar na OS já guarda (sem confirmar). Sem usuário/empresa logada, o compartilhamento é ignorado.
- Fora do escopo: sugestão por IA (`aiMatchOrder`), "Criar OS nova com isto", busca, iOS.
