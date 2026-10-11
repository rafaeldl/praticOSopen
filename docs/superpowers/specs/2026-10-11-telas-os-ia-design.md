# OS e assistente nas telas do app (revisão HIG + simplificação)

**Data:** 2026-10-11 · Complementa `2026-10-09-os-ai-assistant-design.md` (fases, operações, cota e arquitetura continuam valendo).
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app", linha **"Nova OS e a OS"** (9 pranchas, ligadas ao resto do app pelo Play). A antiga página "OS com IA" foi retirada do canvas em 2026-10-11.

## O que mudou em relação às pranchas E1–E4 e N1–N3

Conferido contra `docs/APP_DESIGN_SYSTEM.md` (regras 1–11) e a auditoria HIG (`2026-10-10-telas-hig-design.md`).

| Antes | Problema | Agora |
|---|---|---|
| E1: barra de baixo opaca com borda; topo sem vidro; título 30 | Regra 11 (vidro só na navegação); HIG "Prefer scroll-edge effects to solid backgrounds beneath controls" | Foto e "Falar o que fazer" flutuam (foto em vidro, Falar em grafite `assistantFill`); topo em vidro; título grande do sistema |
| E1: foto de capa no título | Placeholder grande mesmo sem foto (regra 4) | Fotos aparecem em "Nesta OS" só quando existem |
| "…" da OS com 13 itens soltos (spec §3.1) | Menu longo, sem grupos; destrutivo misturado | Menu do iOS em 3 grupos: **Adicionar à OS ›** (abre a lista do que é raro), Mandar para o cliente · PDF, **Cancelar OS / Apagar OS** em vermelho. Pranchas `app-os-menu`, `app-os-adicionar` |
| E2: "Fechar" à direita; ícones + e ✓ à esquerda em círculo | Regra 9/10: sheet com Cancelar à esquerda, escolha com ✓ à direita | Sheet "Assistente" com Cancelar; cada proposta tem ✓ à direita e pode ser desmarcada (spec §3.2) |
| **E3: tela com 3 opções** (Tirar foto, Falar, Preencher eu mesmo) e **E4: tela de conferir** | Duas telas a mais só para começar e para salvar; a opção azul era um cartão preenchido | **"Nova OS" abre a própria OS em branco** (`app-os-nova`): Cliente e "O que vai ser feito" para preencher à mão, e Foto / "Falar o que fazer" embaixo. A IA preenche **a mesma tela**, com marca-texto no que ela pôs (`app-os-nova-preenchida`); o usuário confere ali e toca **"Salvar OS"**. A câmera (`app-os-captura`) só abre se tocar em Foto |
| N1: roxo, botão "Montar" | Roxo proibido (cores); "Montar" é jargão | Controles em vidro sobre a câmera; "Pronto" (azul da marca) junta fotos e fala numa OS só, como a spec pede |
| N2: dois botões ("Criar orçamento" / "Criar e aprovar") | Dois botões principais | Um botão só, "Salvar OS", na Nova OS preenchida |
| E4: item sem valor obrigava preencher | Trava quando o usuário não sabe o valor | O item sem valor vira pergunta na própria Nova OS, com "Tirar"; cliente e veículo são tocáveis para trocar |
| N3: só fotos do WhatsApp; roxo; botão "Pôr nesta OS" | Documentos ficavam de fora; um toque a mais | **Receber de qualquer app** (ver abaixo) |

## Ligações com o resto do app

- Linhas de OS (Início, Agenda, cliente, veículo, avaliações) → a OS (`app-os`).
- "Nova OS" (Início e "Nova OS para Ana" no cliente) → **Nova OS em branco** (`app-os-nova`).
  - **Com IA (2 passos):** Foto e/ou Falar → Nova OS preenchida → Salvar OS.
  - **À mão (3 passos):** Cliente (buscar pela placa já escolhe o veículo; com 1 veículo, escolhe sozinho) → + Serviço ou peça (tocar já põe) → Salvar OS.
- OS pronta com falta a receber: o próximo passo vira **"Receber R$ 950"** (`app-os-pronta`) → `app-receber`; voltar do Receber leva à OS.
- Compartilhar de qualquer app → `app-recebido` → tocar numa OS (guarda na hora) ou "Criar OS nova com isto" → Nova OS preenchida.

## Receber de qualquer app (fotos e documentos)

Vale para WhatsApp, Arquivos, e-mail, galeria: o usuário toca em Compartilhar → PraticOS.

- **Uma pergunta: "Em qual OS guardar?"** Aparece o que chegou (miniaturas e "2 fotos e 1 PDF"), depois:
  1. "Criar OS nova com isto" → Nova OS preenchida (a IA lê as fotos; documentos vão anexados).
  2. As OS em aberto, com a **sugestão da IA** em primeiro e marcada ("sugestão" + o porquê: "a placa da foto é a mesma"). Sem sugestão, a lista aparece sozinha.
  3. Busca por número, cliente ou placa.
- **Tocar na OS já guarda**: sem botão de confirmar (o "Cancelar" está no topo). Prancha `app-recebido`.
- Confirmação curta: "Guardado na OS 186 · 2 fotos e 1 PDF" com **"Abrir a OS"** e "Voltar ao WhatsApp" (nome do app de origem). Prancha `app-recebido-ok`.
- Fotos vão para as fotos da OS; PDF e outros arquivos vão para os documentos da OS (`OrderDocument`, o mesmo de hoje). Fotos contam na cota como hoje.
- Implementação (spec original §4.3): Android por `intent-filter` (`image/*` e `application/pdf`, `SEND` e `SEND_MULTIPLE`); iOS por Share Extension (`risk:high`, assinatura). A sugestão usa `aiMatchOrder`.

## Regras novas

1. **Nova OS é a própria OS em branco.** Sem tela de escolha e sem tela de conferir: preencher, conferir e salvar acontecem no mesmo lugar. A permissão de câmera e de microfone só é pedida quando a pessoa toca em Foto ou Falar, com a frase que já está na tela ("Tire foto da placa e fale o serviço").
2. **Item sem valor não trava o salvar**: o usuário informa o valor ou tira o item.
3. **O "…" da OS tem no máximo 3 grupos**; o que é raro mora em "Adicionar à OS" (e pode ser pedido falando).

## Decisões (Rafael, 2026-10-11)

1. Foto de capa sai do topo da OS; fotos aparecem em "Nesta OS" quando existem.
2. A explicação antes da permissão é a própria frase da Nova OS em branco.
3. Simplificar a abertura da OS ao máximo: daí a Nova OS em branco no lugar de captura + conferir.

Impacto na spec `2026-10-09-os-ai-assistant-design.md`: as seções 3.3 (E3/E4) passam a ser a Nova OS em branco/preenchida; `capture/capture_screen.dart` só abre a partir de Foto, e a proposta da IA na OS nova é mostrada na própria tela (marca-texto) em vez de `proposal_sheet.dart`.
