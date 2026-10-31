# Resumo da matriz de paridade

Base: commit `fd9e64da`, 2026-10-31. Fonte da verdade: [`parity-matrix.yaml`](parity-matrix.yaml).

## Contagem

- 514 linhas: 463 capacidades de usuário e 51 de lógica ou componente (`kind: logic|component`, fora da meta de 100%).
- 134 de 134 arquivos de `lib/screens/` têm linha. As 23 rotas de `lib/routes.dart` e as 7 rotas só nomeadas (`/home`, `/agenda`, `/financial`, `/nfse_list`, `/nfse_invoice`, `/receipt_detail`, `/receive_customer`) estão cobertas.
- Todas as linhas estão com `web_status: todo`.

| Área | Linhas | | Área | Linhas |
|---|---:|---|---|---:|
| OS (`order`, `contract`) | 146 | | Equipe (`team`) | 18 |
| Receber e cobrar (`pay`, `charge`, `receipt`) | 51 | | Aparelhos e valores salvos (`device`, `values`) | 21 |
| Checklists | 30 | | Catálogo | 13 |
| Nota fiscal (`nfse`) | 29 | | Empresa, plano, lembretes | 24 |
| Financeiro (`fin`) | 24 | | Perfil, conta, avançado | 27 |
| Clientes | 23 | | Agenda | 9 |
| Primeiro acesso | 22 | | Entrada (`auth`) | 12 |
| Início e navegação (`home`, `nav`) | 29 | | Avisos, avaliações, integrações, Asaas | 15 |
| Componentes (`ui`) | 18 | | Compartilhar para o app | 3 |

## Telas por tamanho (`lib/screens`, 44.573 linhas)

| Faixa | Arquivos |
|---|---:|
| 1000 ou mais | 6 |
| 500 a 999 | 17 |
| 200 a 499 | 53 |
| Menos de 200 | 58 |

Maiores: `order/order_screen_v2.dart` (3876), `dashboard/financial_report_screen.dart` (2386), `payment_management_screen.dart` (1254), `payments/receive_customer_screen.dart` (1159), `order/new_order_form.dart` (1038), `forms/form_fill_screen.dart` (1009).

## Hardware e recursos do aparelho (linhas)

`share_sheet` 13, `camera` 13, `gallery` 12, `whatsapp` 9, `external_browser` 7, `clipboard` 6, `file` 5, `mic` 5, `local_notifications` 5, `pdf_generation` 5, `iap` 4, `share_intent` 3, `native_sign_in` 2, `maps` 2, `phone` 1, `push` 1, `att` 1, `qr_display` 1. Sem NFC, leitor de código ou assinatura na tela.

## Exceções propostas (34, nenhuma aprovada)

| Grupo | Linhas | Motivo |
|---|---:|---|
| Bot WhatsApp | 7 | `kWhatsAppBotEnabled=false`, nunca aparece |
| Sheet nativa de compartilhar | 7 | Troca por copiar, baixar, WhatsApp web |
| Lembretes locais | 5 | "Valem só neste celular"; Web Push seria decisão à parte |
| Assinatura na loja | 4 | Compra é IAP; cobrança web fica fora desta matriz |
| Share intent do Android | 3 | Troca por arrastar e soltar |
| Câmera e voz | 4 | Upload e texto cobrem; dispositivo entra onde o navegador permitir |
| Outras | 4 | ATT (só iOS), push nativo, barra de abas vira navegação lateral, ícone em código morto |

## Telas antigas e redesenhadas

Sinal mecânico: `CupertinoColors` direto em vez de `AppColors`.

- Antigas de fato: `menu_navigation/widgets/link_whatsapp_sheet.dart`, `widgets/whatsapp_setup_banner.dart`, `payments/widgets/payment_transaction_icon.dart`, `payments/widgets/receipt_image_viewer.dart`.
- Mistas: `forms/form_fill_screen.dart` (8 usos), `menu_navigation/home.dart` (só no ramo do bot), `user_profile_edit_screen.dart`, `order/order_screen_v2.dart` (1 uso cada).
- Texto ou diálogo no padrão antigo: `forms/form_template_list_screen.dart`, `menu_navigation/more/account_deletion.dart`, `menu_navigation/collaborator_form_screen.dart`, `onboarding/whatsapp_onboarding_screen.dart`.
- As demais usam os papéis de `AppColors`. O sinal mede cor, não revisão de UX: Financeiro, Avisos e Contratos ainda não passaram pela segunda revisão.

## Armadilhas

**Papéis**

1. Não existe papel de recepção. Consultor só vê as próprias OS; supervisor não vê preço. O público "recepção" precisa de decisão de produto antes da web.
2. `owner` é gravado e lido como `admin`, mas a API de equipe protege o dono. A matriz lista os dois.
3. Técnico só abre OS que criou. `viewAssignedOrders` não é usada, e "Responsável" grava `assignedTo` sem dar acesso. O comentário em `firestore.rules` que diz que `assignedTo` não está na UI está velho.
4. Técnico tem `createOrder`, mas o "+" é escondido. "Nova OS" em cliente, aparelho e contratos não checa permissão: gerente vê o botão e a gravação é negada.
5. Técnico pode editar itens em `quote`, mas não tem `viewServices` nem `viewProducts`: a busca de itens fica vazia.
6. Editar e apagar aparelho aparecem para todos no menu; a negação vem depois.
7. Gerente abre e grava checklist sem `fillForms`. É gap conhecido em `firestore-matrix.ts`.
8. As regras por ação vivem em `AuthorizationService` e em getters de tela. A web precisa portar exatamente essas condições, inclusive status e criador da OS.

**Web**

9. Só `/financial_report` e `/payment_management` têm guarda de rota. As demais confiam em quem mostra a entrada. Na web, URL direta exige guarda em toda rota.
10. `paidPlansEnabled` é `false` em `kIsWeb`: sem portar, os limites de plano somem. Contador de fotos só grava para admin (#458).
11. Muita regra está em Dart no cliente: total, transações, distribuição de recebimento (`payment_allocation`, `receipt_plan`, `receipt_undo`), `BootstrapService`, PDFs e relatório. Cada uma precisa de porte ou de ir para a API. Mudar contrato de API exige aprovação.
12. Contrato recorrente é gerado no cliente, ao abrir o app (`checkAndGenerateDueOrders`), sem função no servidor. Se a web gerar também, precisa de proteção contra duplicar; se não gerar, quem só usa a web fica sem OS nova.
13. Busca da Início só olha OS carregadas. Relatório financeiro baixa as OS do período e soma no cliente. Nenhum dos dois atende às metas de 10 mil OS e busca em menos de 200 ms.
14. `dart:io` aparece em 27 arquivos de `lib/` (fotos, `Platform`, base da API). Reaproveitar código Dart na web esbarra nisso.
15. Só 5 linhas têm estado offline explícito; o resto depende do cache do Firestore no celular. No navegador esse cache é opcional.
16. Estado só local: adiamento da próxima cobrança, lembretes, idioma, empresa selecionada (`SharedPreferences`).
17. Gestos sem botão equivalente: arrastar para apagar em aparelho, checklist, valor salvo e pergunta; arrastar para reordenar perguntas.
18. Depois de aceitar convite é preciso esperar a claim da empresa. Quem tem várias empresas manda `X-Company-Id` nas chamadas.
19. `firebase/web` já é um app Nuxt com `/admin`, `/pro` e `/q`. Definir host e rotas antes de criar outro.
20. i18n completo: 1616 chaves nos 3 idiomas. Fora disso, `FeatureGateResult.message` está em português no código e ainda há "procedimento" misturado com "checklist".
21. Segmentos: 15 raízes mais `global`, 35 subcategorias. O impacto maior vem de rótulos, máscaras e `customFields`. Só `automotive` e `bicycles` têm "O que o cliente pediu"; `public_works` tem 8 campos de OS próprios.
22. `/order_service` e `/order_product` são rotas antigas ainda usadas pelo catálogo em modo seleção. `payment_transaction_icon.dart` não tem import.

## Como a checagem pode achar telas novas

Sem script por enquanto. Uma checagem de CI poderia:

- Listar todo `lib/screens/**/*.dart`, não só `*_screen.dart`: só 50 dos 134 arquivos têm esse sufixo, e sheets, pickers e `*_view.dart` ficariam de fora. Falhar se `screen` não aparecer na matriz.
- Comparar as chaves de `appRoutes` e todo `RouteSettings(name:)` com `route`.
- Falhar se `EmptyState`, `ErrorState` ou `LoadingState` existir no arquivo sem o estado na linha.
- Comparar o `PermissionType` citado no arquivo com `permission`, ignorando arquivos de ponte como `order_screen_services.dart`.
- Avisar quando `showPullDownMenu` ou `PullDownItem` crescer num arquivo, para pegar ação nova em menu.
- Conferir `id` único e `web_exception.status` diferente de aprovado sem revisão.
