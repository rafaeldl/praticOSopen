# WhatsApp Adoption

Sistema de nudges e incentivos para aumentar a adoção do WhatsApp entre usuários do app. Implementa 4 estratégias complementares que capturam o usuário em diferentes momentos da jornada.

## Visão Geral

O sistema incentiva a vinculação do WhatsApp e o uso de compartilhamento de OS com clientes através de:

1. **Botão WhatsApp na Navbar** — Acesso rápido sempre visível na Home
2. **Prompt Pós-Mudança de Status** — Sugestão contextual ao atualizar status de uma OS
3. **Banner de Setup na Home** — Card dismissível com reapari\u00e7ão após 7 dias
4. **Tela Pós-Onboarding** — Passo opcional após criar empresa

## Arquitetura

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                      ESTRATÉGIA 1 - Navbar                      │
│  Home (leading button)  →  WhatsAppLinkStore (isLinked)         │
│    Se vinculado: abre wa.me/{botNumber}                         │
│    Se não: abre LinkWhatsAppSheet                               │
├─────────────────────────────────────────────────────────────────┤
│                  ESTRATÉGIA 2 - Prompt Status                   │
│  OrderForm (_trySetStatus)  →  _promptShareAfterStatusChange    │
│    Guards: status, shareLink, dismiss, phone                    │
│    Ação: abre ShareLinkSheet com statusContext                  │
├─────────────────────────────────────────────────────────────────┤
│                  ESTRATÉGIA 3 - Banner Home                     │
│  Home (SliverToBoxAdapter)  →  WhatsAppSetupBannerStore         │
│    SharedPreferences: dismiss date, 7-day reappear              │
│    Ação: abre LinkWhatsAppSheet                                 │
├─────────────────────────────────────────────────────────────────┤
│                  ESTRATÉGIA 4 - Onboarding                      │
│  ConfirmBootstrapScreen  →  WhatsAppOnboardingScreen            │
│    "Vincular agora": abre LinkWhatsAppSheet                     │
│    "Talvez depois": navega para Home                            │
└─────────────────────────────────────────────────────────────────┘
```

### Arquivos Principais

| Componente | Arquivo | Descrição |
|------------|---------|-----------|
| **Store** | `lib/mobx/whatsapp_link_store.dart` | Estado de vinculação WhatsApp (isLinked, loadStatus, generateToken) |
| **Store** | `lib/mobx/whatsapp_setup_banner_store.dart` | Visibilidade do banner (dismiss, 7-day reappear) |
| **Service** | `lib/services/whatsapp_link_service.dart` | Cliente HTTP para API de vinculação + constante `botNumber` |
| **Service** | `lib/services/share_link_service.dart` | Mensagens contextuais por status (`_buildStatusMessage`) |
| **UI** | `lib/screens/menu_navigation/home.dart` | Botão navbar (Estratégia 1) + Banner (Estratégia 3) |
| **UI** | `lib/screens/widgets/whatsapp_setup_banner.dart` | Widget do banner dismissível |
| **UI** | `lib/screens/onboarding/whatsapp_onboarding_screen.dart` | Tela pós-onboarding (Estratégia 4) |
| **UI** | `lib/screens/order_form.dart` | Prompt pós-status (Estratégia 2) |
| **UI** | `lib/screens/widgets/share_link_sheet.dart` | Sheet de compartilhamento (recebe `statusContext`) |
| **Backend** | `firebase/functions/src/routes/user/link.routes.ts` | API de vinculação (token, status, unlink) |
| **i18n** | `lib/l10n/app_pt.arb`, `app_en.arb`, `app_es.arb` | Strings localizadas |

## Estratégia 1 — Botão WhatsApp na Navbar

Ícone WhatsApp no `leading` da `CupertinoSliverNavigationBar` da Home, com comportamento dinâmico:

- **Não vinculado**: Ícone cinza (`secondaryLabel`) + badge vermelho (dot 8px) → abre `LinkWhatsAppSheet`
- **Vinculado**: Ícone verde (#25D366) → abre `wa.me/{botNumber}` via `url_launcher`

O estado reativo é gerenciado por `Observer` que observa `_whatsappStore.isLinked`.

O `botNumber` é uma constante fixa definida em `WhatsAppLinkService.botNumber`, correspondendo ao `BOT_WHATSAPP_NUMBER` do backend.

### Carregamento do Status

```dart
// home.dart — didChangeDependencies
if (!_whatsappStatusLoaded) {
  _whatsappStatusLoaded = true;
  _whatsappStore.loadStatus().then((_) {
    _bannerStore.updateLinkStatus(_whatsappStore.isLinked);
    _bannerStore.checkVisibility();
  });
}
```

A flag `_whatsappStatusLoaded` garante que `loadStatus()` é chamado apenas uma vez, evitando chamadas repetidas quando `didChangeDependencies` é invocado por rebuilds do Provider.

## Estratégia 2 — Prompt Pós-Mudança de Status

Após mudar o status de uma OS para `approved`, `progress` ou `done`, um `CupertinoAlertDialog` pergunta se o usuário quer notificar o cliente via WhatsApp.

### Condições (Guards)

O prompt só aparece quando **todas** as condições são verdadeiras:

1. Status novo é `approved`, `progress` ou `done`
2. OS está salva (tem `id`)
3. Cliente **não** tem share link ativo (não expirado)
4. Usuário **não** dispensou o prompt para esta OS na sessão atual
5. Cliente tem telefone (`customer.phone` não nulo/vazio)

### Controle de Dismiss

```dart
final Set<String> _dismissedSharePrompts = {};
```

Tracking por sessão (in-memory). Ao clicar "Agora não", o `order.id` é adicionado ao Set. O prompt não reaparece para aquela OS até o usuário fechar e reabrir o formulário.

### Mensagens Contextuais

O `statusContext` é propagado pela cadeia: `OrderForm` → `ShareLinkSheet` → `ShareLinkService.buildShareMessage()`.

O `_buildStatusMessage` gera mensagens específicas por status em 3 idiomas:

| Status | Português | English | Español |
|--------|-----------|---------|---------|
| `approved` | "O orçamento da sua OS #N foi aprovado!" | "The quote for your SO #N has been approved!" | "El presupuesto de tu OS #N fue aprobado!" |
| `progress` | "Sua OS #N está em andamento!" | "Your SO #N is now in progress!" | "Tu OS #N está en progreso!" |
| `done` | "O serviço da sua OS #N foi concluído!" | "Your SO #N has been completed!" | "El servicio de tu OS #N fue completado!" |

### Títulos do Dialog (i18n)

| Status | Key | pt | en | es |
|--------|-----|----|----|-----|
| `approved` | `statusUpdateApproved` | Orçamento aprovado! | Quote approved! | ¡Presupuesto aprobado! |
| `progress` | `statusUpdateProgress` | Serviço em andamento! | Service in progress! | ¡Servicio en progreso! |
| `done` | `statusUpdateDone` | Serviço concluído! | Service completed! | ¡Servicio completado! |

## Estratégia 3 — Banner de Setup na Home

Card dismissível entre os filter chips e a lista de OS na Home.

### Lógica de Visibilidade (`WhatsAppSetupBannerStore`)

```
WhatsApp vinculado?  ──Yes──→  Banner OCULTO (permanente)
        │ No
        ▼
Já dispensou?  ──No──→  Banner VISÍVEL
        │ Yes
        ▼
Faz 7+ dias?  ──No──→  Banner OCULTO
        │ Yes
        ▼
Banner VISÍVEL
```

### Persistência

- **Key**: `whatsapp_banner_dismissed_at` (SharedPreferences)
- **Valor**: `DateTime.now().millisecondsSinceEpoch`
- **Reapari\u00e7ão**: 7 dias após dismiss (`_reappearDays = 7`)

### Interações

- **Tap no banner** → abre `LinkWhatsAppSheet` → se vincular, banner some permanentemente
- **Tap no X** → `dismiss()` → salva timestamp, banner some → reaparece após 7 dias

## Estratégia 4 — Tela Pós-Onboarding

Após completar o bootstrap (criar empresa), em vez de ir direto para a Home, o usuário vê uma tela intermediária incentivando vincular WhatsApp.

### Fluxo

```
ConfirmBootstrapScreen (_saveCompany)
        │
        ▼
WhatsAppOnboardingScreen
    ├── "Vincular agora" → LinkWhatsAppSheet
    │       ├── Vinculou → loadStatus() → isLinked == true → Home
    │       └── Não vinculou → Permanece na tela
    └── "Talvez depois" → Home
```

### Layout

- Ícone: `CupertinoIcons.chat_bubble_2` (64px, verde #25D366)
- 3 benefícios com ícones e checkmarks
- Botão primário: `CupertinoButton.filled` ("Vincular agora")
- Botão secundário: texto cinza ("Talvez depois")

## Chaves i18n

| Key | pt | en | es |
|-----|----|----|-----|
| `notifyCustomerQuestion` | Notificar cliente? | Notify customer? | ¿Notificar al cliente? |
| `notifyCustomerDescription` | Deseja enviar a atualização para {customerName} via WhatsApp? | Do you want to send the update to {customerName} via WhatsApp? | ¿Desea enviar la actualización a {customerName} vía WhatsApp? |
| `notNow` | Agora não | Not now | Ahora no |
| `statusUpdateApproved` | Orçamento aprovado! | Quote approved! | ¡Presupuesto aprobado! |
| `statusUpdateProgress` | Serviço em andamento! | Service in progress! | ¡Servicio en progreso! |
| `statusUpdateDone` | Serviço concluído! | Service completed! | ¡Servicio completado! |
| `connectWhatsApp` | Conecte seu WhatsApp | Connect your WhatsApp | Conecta tu WhatsApp |
| `connectWhatsAppBannerDescription` | Receba notificações, gerencie OS e envie atualizações... | Receive notifications, manage work orders... | Recibe notificaciones, gestiona órdenes... |
| `whatsappOnboardingTitle` | Conecte seu WhatsApp | Connect your WhatsApp | Conecta tu WhatsApp |
| `whatsappOnboardingSubtitle` | Aproveite ao máximo o PraticOS... | Get the most out of PraticOS... | Aprovecha al máximo PraticOS... |
| `whatsappBenefitNotifications` | Receba notificações de novas OS | Receive notifications for new work orders | Recibe notificaciones de nuevas OS |
| `whatsappBenefitManage` | Gerencie OS diretamente pelo chat | Manage work orders directly via chat | Gestiona OS directamente por chat |
| `whatsappBenefitClients` | Envie atualizações para clientes | Send updates to customers | Envía actualizaciones a clientes |
| `linkNow` | Vincular agora | Link now | Vincular ahora |
| `maybeLater` | Talvez depois | Maybe later | Quizás después |
| `sendViaWhatsApp` | Enviar via WhatsApp | Send via WhatsApp | Enviar vía WhatsApp |

## Padrões Reutilizados

- `LinkWhatsAppSheet.show(context, store)` — Sheet existente de vinculação com QR code
- `ShareLinkSheet.show(context, order)` — Sheet existente de compartilhamento de OS
- `WhatsAppLinkStore` — Store MobX existente para estado de vinculação
- `SharedPreferences` — Mesmo padrão de persistência local usado por `ThemeStore`
- `url_launcher` — Já usado em `share_link_service.dart` para abrir URLs `wa.me/`
- `font_awesome_flutter` — Já no pubspec, usado para ícone WhatsApp na navbar

## Verificação

1. **Estratégia 1**: Na Home, verificar que botão WhatsApp aparece na navbar. Sem vínculo: badge vermelho + abre LinkWhatsAppSheet. Com vínculo: ícone verde + abre WhatsApp
2. **Estratégia 2**: Abrir OS com cliente que tem telefone → mudar status para "aprovado" → verificar dialog com título contextual → clicar "Enviar via WhatsApp" → verificar que share sheet abre. Dispensar → mudar status novamente → verificar que dialog NÃO reaparece
3. **Estratégia 3**: Logar com conta sem WhatsApp vinculado → verificar banner na Home → dispensar → verificar que some → reabrir app → verificar que não aparece (antes de 7 dias)
4. **Estratégia 4**: Criar conta nova → completar onboarding → verificar tela WhatsApp → clicar "Talvez depois" → verificar que chega na Home
5. Testar dark mode em todas as novas telas/componentes
6. Verificar i18n nos 3 idiomas (pt, en, es)
