# Resumo da matriz de paridade

Base: commit `e6644792`, 2026-11-03. Fonte da verdade: [`parity-matrix.yaml`](parity-matrix.yaml).

## Contagem

- 667 linhas: 561 capacidades de usuário e 106 de lógica ou componente (`kind: logic|component`, fora da meta de 100%).
- Revisão de 2026-11-03: a arqueologia por fatia (entrada, OS, clientes e aparelhos, mandar e receber, agenda e catálogo, financeiro e notas, checklists, contratos, equipe e configurações) acrescentou 92 linhas e corrigiu 283. Cada achado foi conferido no código antes de entrar; o que não se confirmou ficou de fora. Defeito do app que a web não deve repetir está no fim do `note`, depois de "Não copiar:".
- 144 de 144 arquivos de `lib/screens/` têm linha. As 23 rotas de `lib/routes.dart` e as 7 rotas só nomeadas (`/home`, `/agenda`, `/financial`, `/nfse_list`, `/nfse_invoice`, `/receipt_detail`, `/receive_customer`) estão cobertas.
- Todas as linhas estão com `web_status: todo`.

| Área | Linhas | | Área | Linhas |
|---|---:|---|---|---:|
| OS (`order`, `contract`) | 183 | | Equipe (`team`) | 19 |
| Receber e cobrar (`pay`, `charge`, `receipt`, `share`) | 62 | | Aparelhos e valores salvos (`device`, `values`) | 37 |
| Checklists | 37 | | Catálogo | 16 |
| Nota fiscal (`nfse`) | 33 | | Empresa, plano, lembretes | 29 |
| Financeiro (`fin`) | 29 | | Perfil, conta, avançado | 28 |
| Clientes | 38 | | Agenda | 12 |
| Primeiro acesso | 26 | | Entrada (`auth`) | 24 |
| Início e navegação (`home`, `nav`) | 51 | | Avisos, avaliações, integrações, Asaas | 17 |
| Componentes (`ui`) | 18 | | Compartilhar para o app | 8 |

## Telas por tamanho (`lib/screens`, 47.915 linhas)

| Faixa | Arquivos |
|---|---:|
| 1000 ou mais | 7 |
| 500 a 999 | 18 |
| 200 a 499 | 54 |
| Menos de 200 | 65 |

Maiores: `order/order_screen_v2.dart` (4241), `dashboard/financial_report_screen.dart` (2405), `payment_management_screen.dart` (1255), `payments/receive_customer_screen.dart` (1160), `menu_navigation/home_content.dart` (1151), `order/new_order_form.dart` (1058), `forms/form_fill_screen.dart` (1009).

## Hardware e recursos do aparelho (linhas)

`share_sheet` 15, `camera` 14, `gallery` 13, `whatsapp` 11, `external_browser` 9, `local_notifications` 9, `share_intent` 8, `clipboard` 7, `mic` 7, `pdf_generation` 7, `iap` 6, `file` 5, `push` 3, `contacts` 2, `maps` 2, `native_sign_in` 2, `att` 1, `phone` 1, `qr_display` 1. Sem NFC, leitor de código ou assinatura na tela.

## Exceções propostas (60, nenhuma aprovada)

| Grupo | Linhas | Motivo |
|---|---:|---|
| Bot WhatsApp | 7 | `kWhatsAppBotEnabled=false`, nunca aparece |
| Sheet nativa de compartilhar | 8 | Troca por copiar, baixar, WhatsApp web |
| Lembretes locais | 8 | "Valem só neste celular"; Web Push seria decisão à parte. Inclui a dica ao marcar a visita |
| Assinatura na loja | 8 | Compra é IAP; cobrança web fica fora desta matriz. Inclui aviso de cortesia e "Ver planos" da IA |
| Share intent do aparelho | 7 | Troca por arrastar e soltar; contato recebido vira digitação. Inclui as três saídas do arquivo recebido (comprovante de pagamento já registrado, pagamento novo, só guardar) |
| Código sem chamador | 11 | Modo seleção do catálogo, `/order_service`, `/order_product` e as telas de valor e aparelho do item (7), e as 4 linhas de `/accumulated_value_list`. Nada navega para elas; remover do app ou não portar |
| Câmera e voz | 4 | Upload e texto cobrem; dispositivo entra onde o navegador permitir |
| Contatos do aparelho | 2 | Contact Picker API tem suporte desigual; digitar cobre a ação |
| Outras | 5 | ATT (só iOS), push nativo, pedido de notificação do iPhone, barra de abas vira navegação lateral, ícone em código morto |

## Telas antigas e redesenhadas

Sinal mecânico: `CupertinoColors` direto em vez de `AppColors`.

- Antigas de fato: `menu_navigation/widgets/link_whatsapp_sheet.dart`, `widgets/whatsapp_setup_banner.dart`, `payments/widgets/payment_transaction_icon.dart`, `payments/widgets/receipt_image_viewer.dart`.
- Mistas: `forms/form_fill_screen.dart` (8 usos), `menu_navigation/home.dart` (só no ramo do bot), `user_profile_edit_screen.dart`, `order/order_screen_v2.dart` (1 uso cada). `login.dart` e `widgets/login_hero.dart` usam branco e preto fixos sobre o azul-marinho do site, de propósito.
- Texto ou diálogo no padrão antigo: `forms/form_template_list_screen.dart`, `menu_navigation/more/account_deletion.dart`, `menu_navigation/collaborator_form_screen.dart`, `onboarding/whatsapp_onboarding_screen.dart`.
- As demais usam os papéis de `AppColors`. O sinal mede cor, não revisão de UX: Financeiro, Avisos e Contratos ainda não passaram pela segunda revisão.

## Armadilhas

**Papéis**

1. Não existe papel de recepção. Consultor só vê as próprias OS; supervisor não vê preço. O público "recepção" precisa de decisão de produto antes da web.
2. `owner` é gravado e lido como `admin`, mas a API de equipe protege o dono. A matriz lista os dois.
3. Técnico só abre OS que criou. `viewAssignedOrders` não é usada, e "Responsável" grava `assignedTo` sem dar acesso. O comentário em `firestore.rules` que diz que `assignedTo` não está na UI está velho.
4. Técnico tem `createOrder`, mas o "+" é escondido; a regra agora é `AuthorizationService.canCreateOrder`, usada também em "Abrir OS" da manutenção e na apresentação da IA. "Nova OS" em cliente, aparelho e contratos continua sem checar: gerente vê o botão e a gravação é negada.
5. Técnico pode editar itens em `quote`, mas não tem `viewServices` nem `viewProducts`: a busca de itens fica vazia.
6. Editar e apagar aparelho aparecem para todos no menu; a negação vem depois.
7. Gerente abre e grava checklist sem `fillForms`. É gap conhecido em `firestore-matrix.ts`.
8. As regras por ação vivem em `AuthorizationService` e em getters de tela. A web precisa portar exatamente essas condições, inclusive status e criador da OS. Desde #484 o servidor aplica o mesmo fluxo de situação, valores, criação e exclusão, então papel errado na web vira gravação recusada: toda ação de OS precisa tratar `denied`.

**Web**

9. Só `/financial_report` e `/payment_management` têm guarda de rota. As demais confiam em quem mostra a entrada. Na web, URL direta exige guarda em toda rota.
10. `paidPlansEnabled` é `false` em `kIsWeb`: sem portar, os limites de plano somem. Contador de fotos só grava para admin (#458).
11. Muita regra está em Dart no cliente: total, transações, distribuição de recebimento (`payment_allocation`, `receipt_plan`, `receipt_undo`), `BootstrapService`, PDFs e relatório. Cada uma precisa de porte ou de ir para a API. Mudar contrato de API exige aprovação.
12. Contrato recorrente é gerado no cliente, ao abrir o app (`checkAndGenerateDueOrders`), sem função no servidor. Se a web gerar também, precisa de proteção contra duplicar; se não gerar, quem só usa a web fica sem OS nova.
13. Busca da Início só olha OS carregadas. Relatório financeiro baixa as OS do período e soma no cliente. Nenhum dos dois atende às metas de 10 mil OS e busca em menos de 200 ms.
14. `dart:io` aparece em 29 arquivos de `lib/` (fotos, `Platform`, base da API). Reaproveitar código Dart na web esbarra nisso.
15. Só 10 linhas têm estado offline explícito; o resto depende do cache do Firestore no celular. No navegador esse cache é opcional.
16. Estado só local (`SharedPreferences`): adiamento da próxima cobrança, lembretes, idioma, empresa selecionada, recusas de checklist e de próxima manutenção, apresentação da IA e "Agora não" da cortesia.
17. Gestos sem botão equivalente: arrastar para apagar em aparelho, checklist, valor salvo e pergunta; arrastar para reordenar perguntas.
18. Depois de aceitar convite é preciso esperar a claim da empresa e recarregar usuário e empresa antes de seguir, ou a pessoa cai no primeiro acesso. Quem tem várias empresas manda `X-Company-Id` nas chamadas.
19. `firebase/web` já é um app Nuxt com `/admin`, `/pro` e `/q`. Definir host e rotas antes de criar outro.
20. i18n completo: 1752 chaves nos 3 idiomas. Fora disso, `FeatureGateResult.message` está em português no código e ainda há "procedimento" misturado com "checklist".
21. Segmentos: 15 raízes mais `global`, 35 subcategorias. O impacto maior vem de rótulos, máscaras e `customFields`. Só `automotive` e `bicycles` têm "O que o cliente pediu"; `public_works` tem 8 campos de OS próprios.
22. `/order_service`, `/order_product`, o modo seleção do catálogo e `/accumulated_value_list` não têm chamador: as duas primeiras só são abertas pelo modo seleção, que nenhuma tela usa, e a última só existe em `lib/routes.dart`. `payment_transaction_icon.dart` não tem import.
23. `onHold` e `nextMaintenance*` não vão no save completo: o app os grava em `update` próprio, para uma cópia velha não trazer de volta o que foi tirado. A web precisa fazer igual. O dia da manutenção é texto `AAAA-MM-DD`, não data com hora.
24. "Orçamentos" e "Paradas" filtram no cliente, sobre as OS abertas carregadas. Tirar aparelho com contrato ativo faz uma leitura por aparelho, e técnico e consultor não leem contratos. Ver a armadilha 13.
25. Regras novas que a web precisa portar: valor digitado como valor (`MoneyInputFormatter`), número do WhatsApp por país (`whatsappNumber`), comparação de telefone sem o nono dígito (`phoneMatchKey`), busca sem acento (`HomeRules.searchKey`) e peça sem total calculada por valor × quantidade.
26. `Device.serial` pode vir vazio: aparelho salva só com o modelo. Rótulo de série vem do segmento (placa, série, IMEI). No Financeiro, cada OS conta em um lugar: com sinal, sai de Em andamento e entra em A receber.
27. Apagar orçamento com dinheiro recebido é negado pelas regras, salvo admin, mas `canDeleteOrder` não olha isso: o botão aparece e a gravação falha.

## Defeitos do app sem linha própria (não copiar)

Os demais estão no `note` de cada linha, depois de "Não copiar:".

- Tema: o app ainda aplica a preferência claro/escuro salva por versões antigas, mas nenhuma tela deixa trocar. A web segue o sistema e oferece claro/escuro.
- Estado global mutável (empresa e usuário atuais preenchidos em vários pontos). A web usa um estado de sessão único, derivado da conta.
- Busca da Início só nas OS carregadas; "Buscar nas mais antigas" traz uma página por vez. A web busca no servidor (armadilha 13).
- Contratos geram OS no aparelho ao abrir o app, sem transação; app e web juntos duplicariam OS. Gerar uma vez no servidor (armadilha 12).
- Sucesso e erro em alerta modal em várias telas de checklist, contratos e empresa. A web usa aviso que some sozinho, e erro junto do campo.

## Checagem de CI

`node scripts/check_parity_matrix.mjs`, em `.github/workflows/parity_check.yml`, roda sem dependências. Falha quando:

- arquivo de `lib/screens/**/*.dart` não aparece em `screen`, ou `screen` aponta para arquivo que não existe;
- chave de `appRoutes` não aparece em `route`;
- `id` se repete;
- `web_status` falta ou sai de `todo`, `in_progress`, `done`, `excepted`;
- `web_status: done` vem sem `e2e`;
- `web_exception.status` é diferente de `proposed` ou `approved`.

Ela só vê arquivo e rota: ação nova em tela que já tem linha não é pega. Ainda dá para acrescentar:

- Comparar `RouteSettings(name:)` com `route`.
- Falhar se `EmptyState`, `ErrorState` ou `LoadingState` existir no arquivo sem o estado na linha.
- Comparar o `PermissionType` citado no arquivo com `permission`, ignorando arquivos de ponte como `order_screen_services.dart`.
- Avisar quando `showPullDownMenu` ou `PullDownItem` crescer num arquivo, para pegar ação nova em menu.
