# Animações de conclusão (estilo Duolingo, na medida)

**Data:** 2026-10-10 · **Status:** direção aprovada pelo Rafael, pranchas prontas, implementação não começou.
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página **"Animações de conclusão"** (4 pranchas: antes → durante → depois).
**Base:** `docs/APP_DESIGN_SYSTEM.md`; HIG *Motion*, *Feedback*, *Playing haptics* e *Accessibility* (Reduce Motion), pela skill `apple-hig`.

## Ideia

O Duolingo comemora cada passo porque o hábito é o produto. No PraticOS, o hábito é **fechar a OS e receber**. Uma comemoração curta nesses momentos dá a sensação de "trabalho feito" e empurra para o próximo passo: receber, mandar o link para o cliente. Esse próximo passo também alimenta o efeito de rede (ver `2026-10-10-app-cliente-design.md`).

A HIG pede o contrário do exagero: movimento com propósito, breve, e nunca em interação repetida toda hora ("avoid animation on frequently repeated custom interactions"). Por isso há dois níveis.

## Momentos

| Momento | Vale? | Nível | O que acontece |
|---|---|---|---|
| **OS concluída** | Sim | Pequeno | O botão "Concluir OS" encolhe e vira o check verde (0,6 s). O bloco troca para "Pronta · Falta receber" com fade. Háptico de sucesso |
| **Pagamento recebido** (manual ou pelo link Asaas) | Sim | Pequeno | O "falta" conta até R$ 0 e a barra de recebido enche (0,8 s); depois, o check e "Tudo recebido!". Parcial: só a barra anda, com háptico leve e sem check |
| **Orçamento aprovado pelo cliente** (pelo link) | Sim | Pequeno | Com o app aberto, o aviso desce no topo, em vidro (camada de navegação), e some em 4 s; o ponto da OS passa de cinza a azul com "Aprovada pela Ana". Com o app fechado, só a notificação do sistema, que já existe |
| **Primeira OS concluída** | Sim, uma vez por empresa | Marco | Check + 26 papéis nas cores da marca caindo uma vez (1,2 s) e uma sheet média: "Primeira OS concluída! Mande para a Ana" → abre o link do cliente |
| **Primeiro pagamento pelo link** | Sim, uma vez por empresa | Marco | O mesmo padrão: "Primeiro pagamento pelo link!" |
| Salvar OS, adicionar item, cada resposta de checklist, cada foto | **Não** | — | Acontecem dezenas de vezes por dia, e animação aí vira ruído. Basta o retorno do sistema (háptico de seleção quando já existe) |
| Confete em toda OS concluída | **Não** | — | Cansa na terceira vez e atrapalha quem fecha 20 OS por dia |
| Som | **Não** | — | Oficina barulhenta, cliente do lado; o háptico basta |
| Sequência ("5 dias seguidos") | **Não agora** | — | Pressiona o usuário. Reavaliar com dados de retenção |

## Regras

1. **Menos de 1,2 s no total.** A parte principal dura até 0,6 s.
2. **Nunca bloqueia.** A animação roda por cima do estado já salvo. Tocar em qualquer lugar segue normalmente, e o próximo botão já está ativo.
3. **O texto conta a história.** "Concluída", "Tudo recebido!", "Aprovada pela Ana" aparecem também para quem não vê a animação (VoiceOver anuncia o texto, a cor nunca vai sozinha).
4. **Háptico com o significado do sistema** (nada de `heavyImpact` para comemorar): usar o de sucesso (no iOS, `UINotificationFeedbackGenerator.success` por canal nativo; o Flutter só expõe impactos e seleção) uma vez por momento. Recebimento parcial: `lightImpact`.
5. **Reduzir movimento:** `MediaQuery.disableAnimationsOf(context)` (no iOS, vem do "Reduzir movimento"). Com ele ligado, sem escala, mola, contagem ou papéis: o estado final entra com fade de 0,2 s. O háptico continua.
6. **Marcos uma vez por empresa,** guardados em `companies/{id}.milestones` (`firstOrderDone`, `firstOnlinePayment`), para não repetir em outro aparelho nem para outro membro da equipe. Só o dono vê a sheet do marco.
7. **Sem nova cor.** Verde `success` no check, azul da marca no botão, papéis em azul, `#67AAED`, verde e o amarelo `marker`.

## Técnica no Flutter

| Opção | Peso | Manutenção | Veredito |
|---|---|---|---|
| **Implícita / `AnimationController` puro** (`AnimatedSwitcher`, `TweenAnimationBuilder`, `CustomPainter` para o check e os papéis) | Zero | Código Dart, revisável no PR, tokens de cor do `AppColors` | **Escolhida** |
| Lottie (`lottie`) | ~1 MB de pacote + JSON por animação | Arquivo feito fora (After Effects), cores fixas no JSON: o modo escuro e os tokens não chegam lá | Não |
| Rive (`rive`) | ~2–3 MB de runtime | Editor externo, máquina de estados; bom para personagem, o que não temos | Não |

As quatro animações são simples (escala, traço do check, contagem, partículas). O pacote `flutter_animate` encurtaria a escrita, mas é dependência nova para ganho pequeno: só entra se a contagem de código passar de ~300 linhas.

**Componentes** (em `lib/screens/widgets/celebration/`):
- `SuccessCheck` — círculo verde com o traço do check (`CustomPainter`, 0,5 s, curva `Curves.easeOutBack` curta).
- `CountDownAmount` — `TweenAnimationBuilder<double>` com `FormatService().formatCurrency` a cada quadro.
- `ConfettiBurst` — 26 partículas, uma queda só, `CustomPainter`, 1,2 s, desligado com Reduzir movimento.
- `Celebration.play(context, kind)` — decide o nível, toca o háptico e respeita `disableAnimations`.

**Onde ligar** (sem mudar a lógica, só disparar depois do sucesso):
- OS concluída: `OrderStore.setStatus` (`lib/mobx/order_store.dart:727`), chamado por `_trySetStatus` (`lib/screens/order_form.dart:2305`). A comemoração entra antes do `_promptShareAfterStatusChange` (`order_form.dart:2330,2343`); no marco, a sheet substitui esse prompt.
- Pagamento: `OrderStore.addPayment` (`order_store.dart:1505`) e `markAsFullyPaid` (`order_store.dart:1577`). Pagamento pelo link chega por push: `notifyAsaasPaymentReceived` (`firebase/functions/src/services/notification.service.ts:236`).
- Aprovado pelo cliente: push `notifyOrderApproved` (`notification.service.ts:271`), recebido em primeiro plano por `FirebaseMessaging.onMessage` (`lib/services/notification_service.dart:83`), que mostra o aviso no topo.
- Checklist concluído: hoje já tem `HapticFeedback.mediumImpact` em `_finishForm` (`lib/screens/forms/form_fill_screen.dart:253`). Fica só com o háptico, sem animação nova.

**Medição:** `AnalyticsService.logCelebration(kind)` só para os marcos (`first_order_done`, `first_online_payment`) e o toque em "Mandar para a Ana" na sheet. Com isso dá para ver se o marco leva a mais links compartilhados.

## Ordem de implementação

| # | Etapa | Risco |
|---|---|---|
| 1 | `SuccessCheck` + OS concluída + teste de widget (com e sem `disableAnimations`) | `risk:low` |
| 2 | Pagamento recebido (`CountDownAmount`) | `risk:low` |
| 3 | Aviso no topo do orçamento aprovado (primeiro plano) | `risk:low` |
| 4 | Marcos + `companies/{id}.milestones` + sheet | `risk:high` (campo novo em documento compartilhado e regras do Firestore) |
| 5 | Háptico de sucesso nativo no iOS (canal) | `risk:low` |

Depende do redesenho da OS (`2026-10-11-telas-os-ia-design.md`) estar no código: as animações usam o bloco "próximo passo" novo.
