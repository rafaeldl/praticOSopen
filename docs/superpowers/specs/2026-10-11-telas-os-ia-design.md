# OS e assistente nas telas do app (revisão HIG + simplificação)

**Data:** 2026-10-11 · Complementa `2026-10-09-os-ai-assistant-design.md` (fases, operações, cota e arquitetura continuam valendo).
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app", linha **"OS e assistente"** (8 pranchas, ligadas ao resto do app pelo Play). A página "OS com IA" fica como histórico.

## O que mudou em relação às pranchas E1–E4 e N1–N3

Conferido contra `docs/APP_DESIGN_SYSTEM.md` (regras 1–11) e a auditoria HIG (`2026-10-10-telas-hig-design.md`).

| Antes | Problema | Agora |
|---|---|---|
| E1: barra de baixo opaca com borda; topo sem vidro; título 30 | Regra 11 (vidro só na navegação); HIG "Prefer scroll-edge effects to solid backgrounds beneath controls" | Foto e "Falar o que fazer" flutuam (foto em vidro, Falar em grafite `assistantFill`); topo em vidro; título grande do sistema |
| E1: foto de capa no título | Placeholder grande mesmo sem foto (regra 4) | Fotos aparecem em "Nesta OS" só quando existem |
| "…" da OS com 13 itens soltos (spec §3.1) | Menu longo, sem grupos; destrutivo misturado | Menu do iOS em 3 grupos: **Adicionar à OS ›** (abre a lista do que é raro), Mandar para o cliente · PDF, **Cancelar OS / Apagar OS** em vermelho. Pranchas `app-os-menu`, `app-os-adicionar` |
| E2: "Fechar" à direita; ícones + e ✓ à esquerda em círculo | Regra 9/10: sheet com Cancelar à esquerda, escolha com ✓ à direita | Sheet "Assistente" com Cancelar; cada proposta tem ✓ à direita e pode ser desmarcada (spec §3.2) |
| **E3: tela com 3 opções** (Tirar foto, Falar, Preencher eu mesmo) | Uma tela a mais antes de começar; a opção azul era um cartão preenchido | **"Nova OS" abre direto a câmera com fala** (`app-os-captura`). "Preencher sem foto" no topo leva ao fluxo manual (Quem é o cliente?). O caminho com IA economiza um toque; o manual fica com o mesmo número de toques |
| N1: roxo, botão "Montar" | Roxo proibido (cores); "Montar" é jargão | Controles em vidro sobre a câmera; "Pronto" (azul da marca) junta fotos e fala numa OS só, como a spec pede |
| N2: dois botões ("Criar orçamento" / "Criar e aprovar") | Dois botões principais | Já trocado pela E4 na spec; mantido: um botão "Salvar OS" (`app-os-conferir`) |
| E4: "Voltar"; item sem valor obrigava preencher | Sheet sem Cancelar; trava quando o usuário não sabe o valor | Sheet com Cancelar; o item sem valor vira pergunta com "Tirar da OS"; cliente e veículo mostram "parecido:" para trocar |
| N3: roxo, cabeçalhos em caixa alta | Cores e tipografia fora do padrão | Sugestão da IA em bloco de próximo passo com um botão ("Pôr nesta OS"); busca e lista das OS em aberto; "Criar OS nova com estas fotos" |

## Ligações com o resto do app

- Linhas de OS (Início, Agenda, cliente, veículo, avaliações) → a OS (`app-os`).
- "Nova OS" (Início e "Nova OS para Ana" no cliente) → câmera com fala (`app-os-captura`); "Preencher sem foto" → `app-escolher-cliente` → veículo → "O que vai na OS?".
- OS pronta com falta a receber: o próximo passo vira **"Receber R$ 950"** (`app-os-pronta`) → `app-receber`; voltar do Receber leva à OS.
- Fotos compartilhadas do WhatsApp → `app-os-fotos-recebidas` → OS sugerida ou conferir.

## Regras novas

1. **Sem tela de escolha para começar a OS.** A câmera abre direto; se a permissão de câmera for negada, abre "Quem é o cliente?" (manual) com um aviso de uma linha para ligar a câmera nos Ajustes.
2. **Item sem valor não trava o salvar** da conferência: o usuário informa o valor ou tira o item.
3. **O "…" da OS tem no máximo 3 grupos**; o que é raro mora em "Adicionar à OS" (e pode ser pedido falando).

## Perguntas em aberto

1. Foto de capa no topo da OS: some (proposta) ou aparece pequena quando houver foto?
2. Na primeira vez, a câmera pede permissão logo ao tocar "Nova OS". Vale mostrar antes uma frase explicando ("Tire foto da placa e fale o serviço")?
