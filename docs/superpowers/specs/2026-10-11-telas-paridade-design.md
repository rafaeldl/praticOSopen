# Paridade de funções: app atual × redesenho

Data: 2026-10-10 · Base: código da branch `docs/receber-decisoes` (sem alterações) · Redesenho: 54 pranchas `app-*.dc.html` + specs `docs/superpowers/specs/2026-10-09-telas-*.md`, `2026-10-10-telas-*.md` e `docs/APP_DESIGN_SYSTEM.md`.

> **Aplicado nos protótipos em 2026-10-11** (canvas, página "Telas do app", 57 pranchas): lacunas 1, 2, 3, 5, 6, 7, 10, 11 (como linha "Recebido em outubro"), 12, 13, 14 (gasto no subtítulo e "Mandar extrato em PDF" no "…"), 15, 16/17 (prancha "Receber · OS mudou de valor"), 22 e 23; simplificações 1 (tocar já põe na OS), 2 (uma busca para serviço e peça), 3 (placa no "Quem é o cliente?"), 7 e 8 (menu "…" do Início só com canceladas e contratos) e 9 (sai "Refazer a configuração" do Avançado). Simplificação 4 (cliente com 1 veículo) vale como regra, sem prancha. **Aplicado depois (2026-10-11):** simplificações 10 a 12 (ver mapa, "Revisão 2026-10-11"). **Ainda em aberto:** simplificação 14 e as lacunas restantes (4, 8, 9, 18 a 21), que ficam como regra nesta spec.

Como ler:
- Caminhos de "Hoje" são relativos a `lib/screens/`, salvo quando começam com `lib/`.
- "Redesenho" cita a prancha (`app-xxx`) ou a spec (`spec-<grupo>:linha`, por exemplo `spec-mais:62` = `2026-10-09-telas-mais-equipe-design.md` linha 62). `mapa` = `2026-10-09-telas-mapa-design.md`; `hig` = `2026-10-10-telas-hig-design.md`; `receber` = `2026-10-10-telas-receber-design.md`.
- Status:
  - **COBERTO**: uma prancha ou um trecho de spec mostra onde a função mora.
  - **PARCIAL**: mora em algum lugar, mas falta parte (o que falta está na nota).
  - **FALTANDO**: nenhuma prancha nem spec diz onde fica.
  - **REMOVIDO DE PROPÓSITO**: uma spec decide tirar (a decisão está citada).
  - **OS**: é da tela da OS, que está em outra sessão. Não conta como lacuna.
- Uma linha por função de usuário, não por widget. Comportamentos sem tela (pedido de permissão de push, ATT, reagendar lembretes ao abrir o app) ficam fora da contagem.

---

## (a) Resumo

| Status | Linhas |
|---|---|
| COBERTO | 131 (120 de hoje + 11 funções novas que o redesenho cria) |
| PARCIAL | 19 |
| FALTANDO | 10 |
| REMOVIDO DE PROPÓSITO | 13 |
| OS (outra sessão) | 18 |
| **Total** | **191** |

O que mais importa:

1. **Apagar conta não aparece no redesenho** (`app-conta` não tem). Hoje fica em Meu perfil (`user_profile_edit_screen.dart:250-537`), e a App Store exige isso (diretriz 5.1.1(v)). É a única lacuna que pode travar a revisão da Apple.
2. **Convidar pessoa perdeu o e-mail e o papel Supervisor** (`app-convidar`). Sem o e-mail, a prancha `app-convite-email` nunca dispara: o app só acha convite pendente pelo e-mail de quem entra (`auth_wrapper.dart:267`, `invite_repository.dart:78-90`). Supervisor é um dos 5 papéis (`lib/models/user_role.dart:29`) e a prancha mostra só 4.
3. **Dados da empresa perdeu e-mail, site, país e "Usar termos padrão"** (`app-empresa`). A spec de primeiro acesso manda esses dados "para Ajustes > Empresa", mas a prancha não tem onde. O país muda máscaras e moeda.
4. **Editor de checklist pela metade** (`app-checklist-editar`): faltam descrição, ligar/desligar, "obrigatória", "permite foto", as opções da pergunta e apagar o checklist.
5. **Financeiro e Relatório**: faltam os outros períodos (dia, semana, ano, datas) em prancha, a lista "Recebido", o ranking de clientes e o PDF por cliente.
6. **Duas telas de "Início" dependem de dado que nenhuma tela grava**: "Minhas" (`app-home-tecnico`) e "com Marina" (`app-agenda`) usam `Order.assignedTo`, e hoje nenhuma tela define o responsável da OS. É preciso combinar com a sessão da OS.
7. **Bugs de hoje achados no caminho** (não são de paridade): tocar numa OS no histórico do aparelho quebra o app (rota `/order_detail` inexistente, `devices/device_detail_screen.dart:387`), e tocar numa notificação push não abre a OS (`NotificationService.onNotificationTap` nunca é ligado, `lib/services/notification_service.dart:64`).

---

## (b) Tabela completa por área

### Navegação e abas

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Trocar entre 5 abas | `menu_navigation/navigation_controller.dart:32-85` | mapa "Abas por papel"; `app-home`, `app-home-tecnico` | COBERTO | Ordem fixa (hig:7) |
| Aba Financeiro para quem não tem permissão ("Acesso negado") | `dashboard/financial_dashboard_simple.dart:122-124` | mapa "Cortar" | REMOVIDO DE PROPÓSITO | A aba some sem `viewFinancialReports` |

### Início (lista de OS)

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Ver lista de OS e abrir uma | `menu_navigation/home.dart:766-775` | `app-home` | COBERTO | |
| Criar OS ("+") | `home.dart:293-307` | `app-home` "Nova OS"; `app-home-vazia` | COBERTO | |
| Sino com contador de não lidos | `home.dart:250-291` | spec-inicio:46; `app-avisos` | COBERTO | |
| Buscar por nº, cliente, aparelho ou placa | `home.dart:368-381`, `:587-600` | spec-inicio:46, :66 | COBERTO | A prancha não mostra o campo, mas a spec põe "buscar" no topo |
| Carregar mais / buscar nas mais antigas | `home.dart:135-149`, `:636-697` | spec-inicio:59, :66 | COBERTO | |
| Filtro "Todos" | `home.dart:54` | `app-home` "Em aberto \| Todas" | COBERTO | |
| Filtro "Entrega" (prazo) | `home.dart:55` | `app-home` seções "Atrasadas" e "Para hoje" + próximo passo | COBERTO | |
| Filtros Aprovada / Em andamento / Orçamento | `home.dart:56-58` | spec-inicio:54 (seções por grupo) | COBERTO | Viram seções, não filtros |
| Ver concluídas | `home.dart:59` | `app-home-menu` "Ver concluídas" | COBERTO | |
| Ver canceladas | `home.dart:60` | `app-home-menu` "Ver canceladas" | COBERTO | |
| OS de contrato | `home.dart:64-68` | `app-home-menu` "Contratos" | COBERTO | Só com `useContracts` |
| Filtro "A receber" | `home.dart:71-76` | mapa "Juntar · A receber"; `app-financeiro` | COBERTO | Mudou para o Financeiro |
| Filtro "Pago" | `home.dart:71-76` | spec-financeiro (seção "Recebido") | PARCIAL | A seção "Recebido" está na spec, mas não está em `app-financeiro`, e na spec só vale para o mês |
| Filtrar por cliente (faixa com "Cancelar") | `home.dart:315-366` | `app-home-menu` "Filtrar por cliente"; `app-cliente` "Últimas OS" | COBERTO | |
| Atrasada e Pago na linha | `home.dart:870-885` | `app-home` "Atrasada 2 dias"; spec-inicio:56 | COBERTO | Agora com texto |
| % de execução na linha (`customData.executionPercentage`) | `home.dart:890`, `:1021` | — | FALTANDO | |
| Aparelho na linha (`showDeviceInOrderList`) | `home.dart:855` | `app-home` "OS 184 · Fiat Uno 2015" | COBERTO | |
| Valor só com `viewPrices` | `home.dart:838` | spec-inicio:55 | COBERTO | |
| "Minhas \| Todas" para o técnico | não existe | `app-home-tecnico` | COBERTO | Novo. Depende de `assignedTo`, que nenhuma tela grava (ver OS) |
| Botão e faixa do WhatsApp (bot) | `home.dart:496-574` | spec-inicio:63 | REMOVIDO DE PROPÓSITO | Flag `kWhatsAppBotEnabled=false` |

### Avisos

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Lista de avisos (aprovou, recusou, comentou, pagou, avaliou, mudou status) | `notifications/notification_list_screen.dart`, `notification_list_tile.dart:161-188` | `app-avisos` | COBERTO | |
| Marcar todos como lidos | `notification_list_screen.dart:44-58` | `app-avisos` | COBERTO | |
| Tocar abre a OS (comentário: rola até ele) | `notification_list_screen.dart:137-163` | `app-avisos` | COBERTO | |

### Agenda

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Ver OS do dia e abrir | `agenda/agenda_screen.dart:259-401`, `:311-317` | `app-agenda` | COBERTO | |
| Escolher o dia | `agenda_screen.dart:126-128` | `app-agenda` (faixa da semana) | COBERTO | |
| Calendário do mês e ir para outro mês | `agenda_screen.dart:120-133`, `:129-131` | `app-agenda` mostra só a semana | PARCIAL | Não dá para pular semanas ou meses nem ver o mês inteiro |
| Pontos de OS em cada dia | `agenda_screen.dart:193-222` | — | PARCIAL | Vale a mesma nota da linha anterior |
| Filtrar por técnico (admin, gerente, supervisor) | `agenda_screen.dart:82-100`, `:436-483` | `app-agenda` "Toda a equipe ▾" | COBERTO | |
| Hora marcada ou prazo, conforme `useScheduling` | `agenda_screen.dart:295-297` | mapa "Abas por papel" (Agenda só se usa agendamento) | REMOVIDO DE PROPÓSITO | Quem não agenda perde a visão de prazos por data. Pergunta ainda aberta em spec-inicio:116 |
| Agendar a partir do dia vazio | não existe | spec-inicio:82 | COBERTO | Novo |

### Clientes

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Lista de clientes na aba | `menu_navigation/home_customer_list.dart` | `app-clientes` | COBERTO | |
| Buscar por nome ou telefone | `home_customer_list.dart:55-62`, `:135-141` | `app-clientes`; spec-clientes:40 | COBERTO | E por placa (novo) |
| Novo cliente ("+") | `home_customer_list.dart:43-50` | spec-clientes:37; `app-novo-cliente` | COBERTO | |
| Tocar no cliente | `home_customer_list.dart:230-236` (filtra o Início) | `app-cliente` | COBERTO | Agora abre a tela do cliente |
| Editar cliente (toque longo ou deslizar) | `home_customer_list.dart:191-198`, `:237-243`; `customers/customer_list_screen.dart:210-220` | spec-clientes:47 "…" Editar | COBERTO | |
| Apagar cliente (deslizar) | `home_customer_list.dart:199-224`; `customer_list_screen.dart:221-245` | spec-clientes:47 "…" Apagar | COBERTO | |
| Campos: nome e telefone com máscara | `customers/customer_form_screen.dart:106-122` | `app-novo-cliente` | COBERTO | |
| Campos: e-mail, CPF/CNPJ, endereço e abrir no mapa | `customer_form_screen.dart:123-171` | `app-novo-cliente` "+ Mais dados"; spec-clientes:71 | COBERTO | |
| Campos do segmento | `customer_form_screen.dart:176-241` | spec-clientes:71 | COBERTO | |
| Escolher cliente na OS e cadastrar novo sem sair | `customer_list_screen.dart:34`, `:47-52` | `app-escolher-cliente` | COBERTO | |
| Ligar e WhatsApp | não existe | `app-cliente` | COBERTO | Novo |
| OS do cliente e "Nova OS para Ana" | não existe | `app-cliente` | COBERTO | Novo |

### Veículos e aparelhos

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Escolher veículo na OS | `device_list_screen.dart:42`, `:270-271` | `app-escolher-veiculo` | COBERTO | |
| Buscar por modelo, placa ou marca | `device_list_screen.dart:67-73`, `:165-174` | `app-escolher-veiculo`; `app-clientes` (placa) | COBERTO | |
| Lista de todos os veículos (Mais) | `menu_navigation/settings.dart:198-204` (todos os papéis) | mapa decisão 2; `app-avancado` "Todos os veículos" | PARCIAL | Só com controle de veículos. Sem ele, um veículo sem OS (sem cliente) não tem como ser aberto, editado ou apagado |
| Novo veículo | `device_form_screen.dart` | `app-novo-veiculo` | COBERTO | |
| Telas de categoria, marca e modelo | `device_form_screen.dart:444-519` → `accumulated_value_list_screen.dart` | mapa "Cortar"; `app-novo-veiculo` (sugestão) | REMOVIDO DE PROPÓSITO | A sugestão de modelo já traz marca e tipo |
| Apagar valor salvo errado (marca ou modelo com erro de digitação) | `accumulated_value_list_screen.dart:434-488` | spec-veiculos:55, :66 | PARCIAL | Com a sugestão tirada dos aparelhos (opção a), não existe "apagar sugestão": o erro só sai editando cada aparelho |
| Placa ou série (obrigatória) | `device_form_screen.dart:336-341` | `app-novo-veiculo` | COBERTO | |
| Foto | `device_form_screen.dart:127-163` | `app-novo-veiculo` "+ Foto e mais dados" | COBERTO | |
| Campos do segmento (ano, cor, chassi…) | `device_form_screen.dart:378-442` | `app-novo-veiculo`; spec-veiculos:51 | COBERTO | |
| Status do aparelho (com gestão) | `device_form_screen.dart:346-375` | spec-veiculos:51 | COBERTO | Só no editar |
| Detalhe: histórico de OS | `devices/device_detail_screen.dart:215-230` | `app-veiculo` | COBERTO | Hoje quebra ao tocar (ver seção e) |
| Detalhe: contrato do aparelho | `device_detail_screen.dart:458-568` | `app-veiculo` "Contrato" | COBERTO | |
| Editar e apagar veículo (apagar exige `manageDevices`) | `device_detail_screen.dart:115-128`; `device_list_screen.dart:213-264` | spec-veiculos:58 "…" | COBERTO | |
| Cadastrar outro veículo do cliente | não existe | `app-cliente` | COBERTO | Novo. O vínculo só aparece depois da 1ª OS (spec-veiculos:45) |

### Catálogo

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Lista de serviços e de produtos (Mais) | `service_list_screen.dart`, `product_list_screen.dart`; `settings.dart:207-222` | `app-catalogo` "Serviços \| Produtos" | COBERTO | |
| Buscar por nome | `service_list_screen.dart:60-65` | `app-catalogo` | COBERTO | |
| Novo item: nome, preço, foto, campos do segmento | `service_form_screen.dart`, `product_form_screen.dart` | `app-novo-servico`; spec-catalogo:91 | COBERTO | |
| Editar item | `service_list_screen.dart:197-204`, `:233-245` | spec-catalogo:77 (toque com seta) | COBERTO | |
| Apagar item | `service_list_screen.dart:205-229` | spec-catalogo:88 "…" do formulário | COBERTO | |
| Escolher serviço ou produto na OS | `service_list_screen.dart:39`, `:234-238` | `app-escolher-servico`; spec-catalogo:96 | COBERTO | O que acontece depois do toque é da OS |
| Criar serviço pela busca | não existe | `app-servico-novo-na-busca` | COBERTO | Novo |
| Preço só com `viewPrices` | `service_list_screen.dart:269-272` | spec-catalogo:53 | COBERTO | |

### Financeiro e Relatório

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Recebido e a receber no período | `financial_dashboard_simple.dart:455-585` | `app-financeiro` "Entrou / Falta" | COBERTO | |
| Mês anterior e próximo; voltar a hoje | `financial_dashboard_simple.dart:273-296`, `:322-337` | `app-financeiro` "Outubro de 2026"; spec-financeiro (`PeriodStepper`) | COBERTO | |
| Período: hoje, semana, ano, datas | `financial_dashboard_simple.dart:165-220`, `:343-449` | spec-financeiro "…" "Outro período" | PARCIAL | Sem prancha. O mapa manda os gráficos para o Relatório, e não ficou decidido se o período mora na aba ou no Relatório |
| Faturamento, nº de OS e ticket médio | `financial_dashboard_simple.dart:491-575` | `app-relatorio` | COBERTO | |
| Divisão entre serviços e produtos | `financial_dashboard_simple.dart:675-830` | `app-relatorio` "De onde veio" | COBERTO | |
| Ranking de serviços | `financial_dashboard_simple.dart:1056-1180` | `app-relatorio` "Mais vendidos" | COBERTO | |
| Ranking de produtos (quantidade e valor) | `financial_dashboard_simple.dart:1182-1304` | `app-relatorio` "Mais vendidos" | PARCIAL | A prancha só tem exemplos de serviço. Falta dizer se mistura serviços e produtos ou separa |
| Ranking de clientes (quem mais pagou) | `financial_dashboard_simple.dart:831-935` | — | PARCIAL | Os devedores estão em `app-financeiro`. Quem mais gastou não aparece em nenhum lugar |
| Lista de OS recentes, pagas ou a receber | `financial_dashboard_simple.dart:1360-1452` | spec-financeiro "Recebido" | PARCIAL | Está na spec, não na prancha |
| Filtrar o painel por cliente e gerar PDF por cliente | `financial_dashboard_simple.dart:995-1000`, `:1992-` | spec-clientes:53 (resumo no cliente) | FALTANDO | O extrato em PDF do cliente some. O resumo "Total gasto / Falta receber" da spec não está em `app-cliente` |
| PDF do relatório | `financial_dashboard_simple.dart:134-141`, `:1609-2574` | `app-relatorio` "Mandar relatório em PDF" | COBERTO | |
| Mandar cobrança para quem deve | não existe | `app-financeiro`, `app-cobranca` | COBERTO | Novo |

### Receber (pagamentos da OS)

Esta tela abre pela OS, mas tem pranchas próprias (`receber`).

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Ver total, desconto, pago e quanto falta | `payment_management_screen.dart:137-190` | `app-receber` | COBERTO | |
| Registrar pagamento, inteiro ou parcial | `payment_management_screen.dart:376-595`, `:858-928` | `app-receber` "Recebi R$ 950" | COBERTO | |
| Dar desconto | `payment_management_screen.dart:388-460` | `app-receber-desconto` | COBERTO | |
| Observação no pagamento | `payment_management_screen.dart:521-535` | — | FALTANDO | O desconto tem "Por quê"; o pagamento não tem campo de observação |
| Anexar comprovante ao registrar (câmera, galeria, PDF) | `payment_management_screen.dart:549-580`, `:1084-1163` | `app-receber-anexar`, `app-receber-comprovante` | COBERTO | |
| Anexar comprovante depois | não existe | `app-receber-pagamento` | COBERTO | Novo |
| Ver comprovante (`viewPhotos`) | `payment_management_screen.dart:755-763`, `:1165-1200` | `app-receber-pagamento`, `app-receber-pago-comprovante` | COBERTO | |
| Remover um pagamento | `payment_management_screen.dart:689-697` | `app-receber-pagamento` | COBERTO | |
| Desfazer todos (voltar para "a receber") | `payment_management_screen.dart:949-985` | `app-receber-menu` | COBERTO | |
| Atalho "Pagar valor total" | `payment_management_screen.dart:603-615` | receber:16 | REMOVIDO DE PROPÓSITO | O valor já vem preenchido |
| Bloqueio em orçamento ou OS cancelada | `payment_management_screen.dart:287-328` | spec-financeiro ("Aprove o orçamento…") | COBERTO | |
| Pagamento pelo Asaas não pode ser removido | `payment_management_screen.dart:988-990` | receber "Regras" | COBERTO | |
| Criar cobrança Asaas: valor, vencimento, parcelas 2–12, CPF/CNPJ se faltar | `payments/create_charge_screen.dart:322-427` | `app-cobrar-link` | COBERTO | |
| Status da cobrança: pendente, vencida, paga | `payments/widgets/order_charge_card.dart:18-47` | `app-cobranca-aberta`, `app-receber-pago`; receber "Regras" | COBERTO | |
| Status da cobrança: cancelada, estornada | `order_charge_card.dart:18-47` | — | PARCIAL | Nenhuma prancha nem regra diz como aparecem |
| Mandar de novo, copiar link, cancelar cobrança | `order_charge_card.dart:226-254` | `app-cobranca-opcoes` | COBERTO | |
| Aviso de que o saldo mudou + "Gerar de novo" | `order_charge_card.dart:267-315` | spec-financeiro ("aviso de diferença em `NextStepBlock`") | PARCIAL | Sem prancha |
| Trocar uma cobrança aberta por uma nova | `order_charge_card.dart:340-361` | — | FALTANDO | |
| Lembrar pelo WhatsApp; "Ela pagou de outro jeito" | não existe | `app-cobranca-aberta` | COBERTO | Novo |
| Forma de pagamento manual | não existe | receber, decisão 1 | REMOVIDO DE PROPÓSITO | Não é gravada |

### Mais: conta e preferências

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Abrir o perfil pelo topo da Mais | `settings.dart:79-135` | `app-mais` | COBERTO | |
| Editar nome e foto | `user_profile_edit_screen.dart:48-95` | `app-conta` | COBERTO | |
| Ver e-mail e forma de entrada | `user_profile_edit_screen.dart:234-245` | `app-conta` | COBERTO | |
| **Apagar conta** (2 confirmações, reautenticação, aviso de assinatura) | `user_profile_edit_screen.dart:250-537` | — | FALTANDO | Exigência da App Store |
| Trocar de empresa (com mais de uma) | `settings.dart:140-165`, `:679-702` | `app-conta` | COBERTO | |
| Entrar com código de convite | `settings.dart:475-488`, `:756-770` | `app-conta` | COBERTO | |
| Sair | `settings.dart:489-500`, `:655-677` | `app-conta` | COBERTO | |
| Versão do app | `settings.dart:505-516` | spec-mais:62 (rodapé) | COBERTO | |
| Idioma | `settings.dart:267-283`, `:591-611` | `app-preferencias` | COBERTO | |
| Modo noturno (automático, claro, escuro) | `settings.dart:284-297`, `:564-589` | hig:22 ("Aparência removida") | REMOVIDO DE PROPÓSITO | Segue o ajuste do celular |
| Lembrete antes do horário (desligado, 15 min, 30 min, 1 h, 2 h) | `settings.dart:330-345`, `:620-653` | `app-preferencias` | COBERTO | |
| Resumo do dia | `settings.dart:346-368` | `app-preferencias` | COBERTO | |
| Lembrete de dias sem abrir o app | `settings.dart:369-391` | `app-preferencias` | COBERTO | |
| Lembrete de OS paradas | `settings.dart:392-414` | `app-preferencias` | COBERTO | |
| Ligar e desligar o WhatsApp do bot | `settings.dart:427-473`, `:852-897` | spec-mais:119 | REMOVIDO DE PROPÓSITO | Flag desligada |

### Mais: empresa

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Logo, nome, telefone, endereço | `menu_navigation/company_form_screen.dart:493-528`, `:634-691` | `app-empresa` | COBERTO | |
| E-mail e site da empresa | `company_form_screen.dart:670-677`, `:692-699` | — | PARCIAL | spec-primeiro-acesso manda para "Ajustes > Empresa", mas `app-empresa` não tem |
| País (máscaras e moeda) | `company_form_screen.dart:662-669`, `:397-445` | — | FALTANDO | |
| Termos para o cliente | `company_form_screen.dart:777-804` | `app-empresa` | COBERTO | |
| "Usar termos padrão" do ramo | `company_form_screen.dart:805-821` | — | FALTANDO | |
| Ramo e especialidades | `company_form_screen.dart:643-661` | `app-o-que-usar` | COBERTO | |
| Atendimento fora, agenda, controle de veículos, contratos | `company_form_screen.dart:707-762` | `app-o-que-usar` | COBERTO | |
| Refazer a configuração inicial | `settings.dart:299-322`, `:705-753` | `app-avancado` | COBERTO | Duplica `app-o-que-usar` (ver d) |

### Mais: equipe

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Ver equipe e convites, com validade | `menu_navigation/collaborator_list_screen.dart:171-322` | `app-equipe` | COBERTO | |
| Buscar pessoa | `collaborator_list_screen.dart:67-74` | spec-mais:84 | COBERTO | Só com mais de 8 pessoas |
| Recompartilhar convite | `collaborator_list_screen.dart:324-363` | `app-equipe` "Reenviar convite" | COBERTO | |
| Cancelar convite | `collaborator_list_screen.dart:307-392` | spec-mais:77 | COBERTO | |
| Mudar papel | `collaborator_list_screen.dart:489-599` | spec-mais:78 | COBERTO | |
| Tirar da equipe (com as travas de "único admin" e "você mesmo") | `collaborator_list_screen.dart:493-646` | spec-mais:78 | COBERTO | |
| Convidar: nome e telefone | `menu_navigation/collaborator_form_screen.dart:340-381` | `app-convidar` | COBERTO | |
| Convidar: e-mail | `collaborator_form_screen.dart:350-360` | — | PARCIAL | Sem e-mail, `app-convite-email` não acontece (`auth_wrapper.dart:267`) |
| Convidar: escolher papel (5 papéis) | `collaborator_form_screen.dart:232-281` | `app-convidar` | PARCIAL | Falta Supervisor |
| Convite repetido: reenviar o atual ou cancelar e criar outro | `collaborator_form_screen.dart:191-214` | — | FALTANDO | |
| Mandar convite (WhatsApp, copiar código, outros apps) | `widgets/invite_share_sheet.dart:164-311` | `app-convite-enviar` | COBERTO | |
| Limite do plano ao convidar | `collaborator_form_screen.dart:106-107` | `app-plano` "conta o convite" | COBERTO | |

### Mais: plano

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Ver o plano e a situação (renova, cortesia, pagamento com problema) | `settings.dart:784-819` | `app-plano`; spec-mais:57 | COBERTO | |
| Ver e trocar de plano (paywall) | `settings.dart:821-828` | `app-plano` "Ver planos" | COBERTO | |
| Gerenciar assinatura | `settings.dart:829-834` | `app-plano` | COBERTO | |
| Restaurar compras | `settings.dart:835-841` | `app-plano` | COBERTO | |
| Quem não é admin vê "peça ao administrador" | `settings.dart:842-846` | spec-mais:66 | COBERTO | |
| Uso real × limites | não existe | `app-plano` | COBERTO | Novo |

### Mais: cadastros raros

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Lista de checklists com ligado/desligado | `forms/form_template_list_screen.dart:87-191` | `app-checklists` | COBERTO | |
| Buscar checklist | `form_template_list_screen.dart:59-65` | — | FALTANDO | Uso baixo |
| Modelos prontos: ver as perguntas antes de importar | `form_template_list_screen.dart:521-570` | `app-checklists` só mostra "Usar" | PARCIAL | Não dá para ver as perguntas antes de importar |
| Importar modelo pronto (com limite do plano) | `form_template_list_screen.dart:572-633` | `app-checklists` "Usar" | COBERTO | |
| Novo checklist | `form_template_list_screen.dart:46-52` | `app-checklists` | COBERTO | |
| Editar: nome, perguntas, tipo, adicionar | `forms/form_template_form_screen.dart:193-202`, `:355-378`, `:738-859` | `app-checklist-editar` | COBERTO | |
| Editar: descrição | `form_template_form_screen.dart:203-212` | — | PARCIAL | |
| Editar: ligar e desligar | `form_template_form_screen.dart:220-229` | `app-checklists` mostra "Desligado" | PARCIAL | Não diz onde se desliga |
| Pergunta: obrigatória, permite foto, opções | `form_template_form_screen.dart:748-796` | `app-checklist-editar` (só o tipo) | PARCIAL | |
| Reordenar e apagar pergunta | `form_template_form_screen.dart:324-352`, `:404-440` | spec-mais:94 | COBERTO | |
| Apagar checklist | `form_template_list_screen.dart:289-315` | — | FALTANDO | |
| Contratos ativos, próxima OS, abrir a OS | `contracts/contract_list_screen.dart:78-230` | `app-contratos` | COBERTO | Encerrados é novo |
| Avaliações: média, lista, abrir OS, atualizar | `ratings/ratings_screen.dart:31-318` | `app-avaliacoes`; spec-inicio:84 | COBERTO | |
| Integrações (ChatGPT/Claude): listar, criar (URL mostrada uma vez, copiar), revogar | `integrations/integration_list_screen.dart:99-326` | `app-avancado` "ChatGPT e Claude"; spec-financeiro (correções) | COBERTO | A tela de dentro fica como está, com correções |
| Asaas: conectar com a chave, abrir o painel, desconectar | `integrations/asaas_connection_screen.dart:127-377` | `app-avancado` "Cobrança pelo Asaas"; spec-financeiro | COBERTO | Só no piloto |
| Itens da Mais escondidos conforme o papel | `settings.dart:168-261` | spec-mais:67 | PARCIAL | Ficou em aberto quem vê "Avançado". Ele junta itens só de admin com "Todos os veículos", que hoje todos os papéis veem |

### Primeiro acesso

| Função | Hoje | Redesenho | Status | Nota |
|---|---|---|---|---|
| Entrar com Apple | `login.dart:175`, `:290` | `app-login` | COBERTO | |
| Entrar com Google | `login.dart:214`, `:313` | `app-login` | COBERTO | |
| Entrar com e-mail e senha | `email_login_screen.dart:34` | `app-login`; spec-primeiro-acesso | COBERTO | |
| Esqueci a senha | `email_login_screen.dart:235-255` | spec-primeiro-acesso ("Esqueceu a senha?") | COBERTO | |
| Política de privacidade | `login.dart:283` | `app-login` | COBERTO | |
| Boas-vindas e "Configurar depois" | `onboarding/welcome_screen.dart:43`, `:63` | mapa "Cortar"; spec-primeiro-acesso, pergunta 3 | REMOVIDO DE PROPÓSITO | |
| Nome da empresa e logo | `onboarding/company_info_screen.dart:50-81` | `app-negocio` (nome) | COBERTO | A logo vai para Dados da empresa |
| Contatos (e-mail, endereço, site, país) | `onboarding/company_contact_screen.dart:63-90` | mapa "Cortar" | REMOVIDO DE PROPÓSITO | Mas o destino (`app-empresa`) não tem e-mail, site nem país |
| Ramo | `onboarding/select_segment_screen.dart:59` | `app-ramo` | COBERTO | |
| Especialidades | `onboarding/select_subspecialties_screen.dart:66-76` | `app-especialidades` | COBERTO | |
| Ligar agenda e atendimento fora | `onboarding/confirm_bootstrap_screen.dart:365-375` | spec-primeiro-acesso ("Sai: interruptores") | REMOVIDO DE PROPÓSITO | Fica o padrão do ramo |
| Criar com ou sem OS de exemplo | `confirm_bootstrap_screen.dart:464-475` | `app-negocio` | COBERTO | |
| Questionário (3 passos) | `onboarding/segmentation_onboarding_screen.dart` | mapa, decisão 1 | REMOVIDO DE PROPÓSITO | |
| Convite pendente pelo e-mail: aceitar, recusar, outro código, criar empresa | `onboarding/pending_invites_screen.dart:44-270` | `app-convite-email` | COBERTO | |
| Aceitar convite por código | `onboarding/accept_invite_screen.dart:46-274` | `app-ramo` "Recebi um código de convite" | COBERTO | |
| Erro com "Tentar de novo" | `auth_wrapper.dart:155-203` | `app-erro` | COBERTO | |
| Sair no meio do primeiro acesso | não existe | `app-ramo` "Sair" | COBERTO | Novo |
| WhatsApp no primeiro acesso | `onboarding/whatsapp_onboarding_screen.dart` | spec-primeiro-acesso, "Fora de escopo" | REMOVIDO DE PROPÓSITO | Flag desligada |

### OS (outra sessão)

Listadas só para completar o inventário. Não contam como lacuna.

| Função | Hoje | Status |
|---|---|---|
| Tela da OS (cliente, veículo, itens, total) | `order_form.dart` | OS |
| Mudar status (com permissão) | `order_form.dart:2255`, `:2305` | OS |
| Prazo de entrega | `order_form.dart:2115` | OS |
| Data e hora agendada | `order_form.dart:2140-2226` | OS |
| Endereço do atendimento | `order_form.dart:618` | OS |
| Item de serviço e de produto (valor, quantidade, aparelho) | `order_service_screen.dart`, `order_product_screen.dart` | OS |
| Vários aparelhos na OS | `widgets/device_picker_sheet.dart` | OS |
| Fotos e documentos da OS | `widgets/order_media_widget.dart` | OS |
| Comentários (internos ou para o cliente) | `widgets/order_comments_widget.dart:60` | OS |
| Escolher e preencher checklist | `forms/form_selection_screen.dart`, `form_fill_screen.dart` | OS |
| Contrato recorrente (frequência, início, fim, lembrete) e OS filhas | `order_form.dart:372-485`, `:1036`, `:2928` | OS |
| PDF da OS | `order_form.dart:2830` | OS |
| Link da OS (aprovar, comentar, validade 7/14/30, gerar novo, revogar) | `widgets/share_link_sheet.dart` | OS |
| Pedir para compartilhar depois de mudar o status | `order_form.dart:2368` | OS |
| Apagar OS | `order_form.dart:2577` | OS |
| Abrir Receber | `order_form.dart:2431` | OS |
| Seção de cobrança na OS | `payments/widgets/order_charge_section.dart` | OS |
| Responsável da OS (`assignedTo`) | sem tela hoje (só leitura: `lib/mobx/agenda_store.dart:100`) | OS. Ver nota abaixo |

**Para a sessão da OS:** `app-home-tecnico` ("Minhas", "4 com você hoje") e `app-agenda` ("com Marina", filtro por técnico) dependem de `Order.assignedTo`, que nenhuma tela grava hoje. Sem uma linha "Quem faz" na OS, "Minhas" sempre fica vazio.

---

## (c) Lacunas com proposta

Cada proposta segue o padrão: uma pergunta por tela, um botão azul, mostrar só o que existe, raro no "…" ou atrás de link.

| # | Lacuna | Onde encaixar | Por que assim |
|---|---|---|---|
| 1 | **Apagar conta** (FALTANDO) | `app-conta`, no fim: `DestructiveAction` "Apagar minha conta" abaixo de "Sair". Abre o fluxo de hoje (2 confirmações e reautenticação) | Sem tela nova. É exigência da Apple. Vermelho é certo porque apaga dado (hig:25) |
| 2 | **E-mail no convite** (PARCIAL) | `app-convidar`: `MoreFieldsLink` "+ E-mail (para ele entrar direto)" abaixo do WhatsApp | Mantém a tela curta e religa o caminho `app-convite-email` |
| 3 | **Papel Supervisor** (PARCIAL) | `app-convidar`: 5ª linha "Supervisor · organiza a equipe, não vê valores" (frase de spec-mais:78) | Mesma lista do `RolePickerSheet` da Equipe |
| 4 | **Convite repetido** (FALTANDO) | Ao "Criar convite" para alguém que já tem convite: action sheet "Já tem um convite para o Lucas" → "Mandar o mesmo convite" / "Cancelar e criar outro" | Mesmo diálogo de hoje, em formato nativo |
| 5 | **E-mail, site e país da empresa** (FALTANDO/PARCIAL) | `app-empresa`: `MoreFieldsLink` "+ Mais dados (e-mail, site, país)" abaixo do endereço | Aparecem na OS do cliente e definem máscara e moeda. Ficam escondidos, mas existem |
| 6 | **Usar termos padrão** (FALTANDO) | `app-empresa`, com o campo Termos vazio: `TextLink` "Usar o texto padrão do ramo" | Só aparece quando há padrão e o campo está vazio |
| 7 | **Editor de checklist** (PARCIAL) | Tocar numa pergunta abre um sheet "Pergunta": texto, tipo, opções (só em escolha), interruptores "Obrigatória" e "Pode pôr foto". "…" do checklist: "Desligar checklist", "Mudar descrição", `DestructiveAction` "Apagar checklist" | A tela principal continua só com a lista de perguntas |
| 8 | **Ver as perguntas do modelo pronto** (PARCIAL) | `app-checklists`: tocar na linha do modelo (fora do "Usar") abre um sheet com as perguntas e o botão "Usar este checklist" | Prévia sem tela nova |
| 9 | **Buscar checklist** (FALTANDO) | `AppSearchField` só com mais de 8 checklists (mesma regra da Equipe) | Mostra só o que existe |
| 10 | **Outro período no Financeiro** (PARCIAL) | Decidir um lugar só: o "…" do Relatório, com "Este mês / Esta semana / Este ano / Escolher datas" (action sheet). A aba fica só no mês | A aba responde "quem me deve?", e período é análise |
| 11 | **Lista "Recebido"** (PARCIAL) | Pôr na prancha `app-financeiro`, abaixo de "Falta receber", com no máximo 5 linhas e `TextLink` "Ver todos" | Repõe o filtro "Pago" do Início |
| 12 | **Ranking de clientes** (PARCIAL) | `app-relatorio`: seção "Clientes que mais gastaram" (top 5), abaixo de "Mais vendidos" | O PDF já tem; só falta na tela |
| 13 | **Produtos no "Mais vendidos"** (PARCIAL) | `app-relatorio`: uma lista só, em que cada linha diz "serviço" ou "produto" e a quantidade | Evita uma segunda seção |
| 14 | **Extrato do cliente** (FALTANDO) | `app-cliente`: pôr a `SummaryLine` da spec ("Total gasto · Falta receber") e, no "…", "Mandar extrato em PDF" (reusa o PDF por cliente do painel) | O dado já existe (spec-clientes:53) |
| 15 | **Observação do pagamento** (FALTANDO) | Sheet `app-receber-pagamento`: linha "Observação" editável depois. No registro, sem campo (fica limpo) | Uso raro: anotar depois, como o comprovante |
| 16 | **Cobrança com valor desatualizado** (PARCIAL) | `app-cobranca-aberta`: no lugar da frase do Asaas, `NextStepBlock` `warning` "A OS mudou para R$ X. O link ainda cobra R$ Y." + `TextLink` "Gerar link novo" | Uma frase só, e só quando acontece |
| 17 | **Trocar cobrança aberta** (FALTANDO) | Entra no mesmo "Gerar link novo" da #16, que cancela o antigo com confirmação | Sem tela nova |
| 18 | **Cobrança cancelada ou estornada** (PARCIAL) | Linha em "Já recebido" ou no link: ponto cinza + "Link cancelado em 12/10" e ponto âmbar + "Estornado em 12/10" | Completa a regra de status do `receber` |
| 19 | **Agenda: outros meses** (PARCIAL) | `app-agenda`: tocar em "Outubro de 2026" abre um sheet com o calendário do mês (com pontos). Deslizar a faixa troca de semana | Mantém a semana na frente e o mês a um toque |
| 20 | **Veículo sem OS, sem controle de veículos** (PARCIAL) | A busca por placa da aba Clientes também acha veículo sem cliente e abre `app-veiculo` (com "…" Editar/Apagar) | Sem linha nova na Mais |
| 21 | **Valor salvo errado** (PARCIAL) | Na sugestão do modelo (`app-novo-veiculo`), deslizar ou "…" na sugestão: "Não sugerir mais" | Resolve na hora em que o erro aparece |
| 22 | **% de execução** (FALTANDO) | Na linha 2 do Início: "Em andamento · 60%", só quando existe | Mostra só o que existe |
| 23 | **Quem vê "Avançado"** (PARCIAL) | A linha aparece se houver pelo menos 1 item permitido. Dentro dela, cada item mantém a regra de hoje | Técnico com controle de veículos vê só "Todos os veículos" |

---

## (d) Simplificações extras sem perder função

Ordem: impacto × uso (uso em 28 dias, dados do mapa).

| # | O que muda | Por que nenhuma função se perde | Evidência | Uso afetado |
|---|---|---|---|---|
| 1 | **Tocar no serviço já põe na OS**, sem abrir `/order_service`. Valor e quantidade se ajustam na própria linha da OS | O ajuste continua, só que na linha da OS. A prancha "criar pela busca" já assume isso ("O preço você coloca na própria OS") | `app-servico-novo-na-busca`; spec-catalogo:57, :125; mapa (`/order_service` 1.041) | 1.773 + 1.041 views. É o maior ganho do app. Decidir junto com a sessão da OS |
| 2 | **Uma busca só para serviço e produto** na OS ("O que vai na OS?"), com cada linha marcada "serviço" ou "produto" | O mapa já diz que "na OS, uma busca acha os dois", mas `app-escolher-servico` só mostra serviço. As coleções continuam separadas | mapa "Juntar · Serviços + produtos"; `app-escolher-servico` | 613 views de `/product_list` deixam de ser uma tela à parte |
| 3 | **Achar o cliente pela placa no "Quem é o cliente?"**: digitar a placa traz o cliente e já escolhe o veículo | A busca por placa já existe na aba Clientes (`app-clientes`). No seletor ela pula a tela do veículo | `app-escolher-cliente` (busca só por nome e telefone); `app-clientes` | 657 + 597 views. Na oficina, o carro chega antes do nome |
| 4 | **Cliente com 1 veículo: escolher sozinho** e mostrar "VW Gol 2018 · trocar" na OS | A troca continua a um toque | `app-escolher-veiculo` ("Veículos da Ana" com 1) | Parte das 597 views de `/device_list` |
| 5 | **Novo veículo sem pedir tipo**: categoria vem da sugestão ou do ramo, e só aparece em "+ Foto e mais dados" | Já está atrás do link, mas a spec ainda prevê preencher a categoria. Pode ser inferida do ramo | spec-veiculos:51; mapa (`/accumulated_value_list` 413) | 705 views de `/device_form` |
| 6 | **Tirar "Criar serviço novo" do fim da lista** e deixar só o "Criar “X” e pôr na OS" que aparece ao digitar | Os dois criam serviço. O da busca já traz o nome | `app-escolher-servico` + `app-servico-novo-na-busca` | 1.773 views (menos ruído) |
| 7 | **"Em aberto \| Todas" + "Ver concluídas/canceladas" se repetem**: tirar "Ver concluídas" do "…" porque "Todas" já tem a seção "Concluídas" (ou o contrário: tirar "Todas") | O mesmo conjunto de OS continua a um toque | `app-home`, `app-home-menu` | Tela diária |
| 8 | **Tirar "Filtrar por cliente" do "…" do Início**, porque a tela do cliente já lista as OS dele | `app-cliente` "Últimas OS" cobre | `app-home-menu`, `app-cliente` | Tela diária |
| 9 | **"Refazer a configuração inicial" sai do Avançado** | Ramo e especialidades já estão em `app-o-que-usar` | `app-avancado` ("Ramo e especialidades") × `app-o-que-usar` | ≤3 |
| 10 | **Preferências vira "Lembretes"**: o idioma também segue o celular (iOS tem idioma por app nos Ajustes), pela mesma lógica que tirou "Aparência" | Idioma continua mudável pelos Ajustes do iPhone. No Android, manter a linha | hig:22; `app-preferencias` | ≤3. A Mais fica com 1 conceito a menos |
| 11 | **Contratos só no "…" do Início**, não na Mais | O contrato nasce na OS. A lista já está a um toque no Início | `app-home-menu`; mapa "Aba Mais depois" | ≤3 |
| 12 | **Juntar "Dados da empresa" e "O que usar no app" numa linha "Sua empresa"**, com duas seções ("Aparece na OS" e "Recursos") | Nenhum campo sai, só a linha a mais da Mais. Com ≤3 visitas por mês, dividir não paga a linha extra | mapa "Dividir · Dados da empresa"; uso ≤3 | ≤3 |
| 13 | **"Toda a equipe ▾" na Agenda só com 2 ou mais pessoas** | Sozinho, não há o que filtrar | `app-agenda` | Diário para quem agenda |
| 14 | **Convidar sem nome obrigatório**: só papel e WhatsApp. O nome vem quando a pessoa entra | O nome da conta substitui o do convite | `app-convidar` | ≤3 |
| 15 | **"Mais usados" e "Usados por último" sem campo novo**: derivar das últimas ~50 OS (opção b das specs) | Não mexe em modelo compartilhado (risk:low). Sem dado, a seção some | spec-catalogo:141; spec-clientes:101 | 1.773 + 657 |

Duas notas soltas:

- **Nome único para "mandar cobrança"**: `app-financeiro` diz "Mandar cobrança" e `app-receber` diz "Mandar link para a Ana pagar". Sem Asaas, os dois abrem o mesmo `ShareLinkSheet`. Vale um nome só.
- `app-mais` tem 10 linhas na prancha (11 com Contratos). Com as propostas 9 a 12, ficam 8.

---

## (e) Código morto e bugs achados

### Código morto (sem rota ou sem chamada)

| O quê | Prova |
|---|---|
| `lib/screens/modal_menu.dart`, `modal_status.dart`, `modal_bottom_sheet.dart` | Ninguém importa |
| `lib/screens/info_form_screen.dart` + rota `/info_form` | `lib/routes.dart:41`; nenhum `pushNamed('/info_form')` |
| `lib/screens/pdf_preview_screen.dart` | Ninguém importa (o PDF vai direto para compartilhar) |
| `lib/screens/order_item_row.dart` | Ninguém importa |
| `lib/screens/customers/customer_os_list.dart` | Ninguém importa. Além disso, o código está quebrado (`onPressed: customerStore.retrieveCustomers()` em `:39`, `:48`) |
| Rota `/financial_dashboard_simple` | `routes.dart:46`. A tela é usada direto como aba, nunca pelo nome |
| `lib/widgets/feature_gate_limit_modal.dart`, `feature_gate_warning.dart`, `upgrade_prompt_modal.dart` | Só citados entre si ou em comentário |
| Partes de `lib/widgets/permission_widgets.dart` (`PermissionGuard`, `MultiPermissionGuard`, `RoleGuard`, `PermissionBuilder`, `RoleBuilder`, `ProtectedValue`, `ProtectedCurrency`, `ProtectedRouteByRole`) | Sem uso fora do arquivo. Ficam `ProtectedRoute` e `AccessDeniedScreen` (spec-mais:117) |
| `lib/services/deep_link_service.dart` (`praticos://upgrade`, `subscription`, `restore`) | `init()` nunca é chamado e o canal nativo não existe no iOS nem no Android. O esquema `praticos://` está registrado, então o app abre, mas nada é roteado |
| `NotificationStore.requestPermissionAgain` | `lib/mobx/notification_store.dart:136`, sem chamada |
| Chave l10n `signUp` | Sem uso. Não existe cadastro por e-mail |
| Ponto cinza de "contrato inativo" | `contracts/contract_list_screen.dart:165-168`. A lista já filtra só os ativos |
| Telas do bot WhatsApp (`whatsapp_onboarding_screen.dart`, `link_whatsapp_sheet.dart`, `whatsapp_setup_banner.dart`, linhas na Mais e no Início) | Não são mortas, mas ficam inalcançáveis com `kWhatsAppBotEnabled=false`. Manter até decidir o bot (spec-mais:119) |

### Bugs de hoje (fora da paridade, mas afetam pranchas do redesenho)

| Bug | Onde | Pranchas afetadas |
|---|---|---|
| Tocar numa OS do histórico do aparelho quebra o app: a rota `/order_detail` não existe e não há `onGenerateRoute` | `devices/device_detail_screen.dart:387` | `app-veiculo` |
| Tocar na notificação push ou local não abre a OS: `onNotificationTap` nunca é ligado | `lib/services/notification_service.dart:64`, `:278-300` | `app-avisos` (o sino funciona; o push não) |
| Não há link universal para `/q/{token}`: o link da OS sempre abre no navegador, nunca no app | `lib/models/order.dart:240`; nenhum `app_links` | Nenhuma (é comportamento esperado do link do cliente). Só registro |
| Catálogo, cliente e valores salvos podem ser criados, editados e apagados sem checar `manage*`. Só apagar aparelho checa | `service_list_screen.dart:197-229`; `customer_list_screen.dart:210-245`; `accumulated_value_list_screen.dart:434-488` | `app-catalogo`, `app-novo-servico`, `app-cliente`. Decidir na implementação se o "…" Apagar respeita `manage*` (spec-catalogo, pergunta 3) |
| No detalhe do aparelho, o total da OS aparece sem checar `viewPrices` | `device_detail_screen.dart:428-436` | `app-veiculo` |
