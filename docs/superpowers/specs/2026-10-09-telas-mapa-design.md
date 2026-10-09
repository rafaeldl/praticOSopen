# Telas do app: mapa (o que corta, junta e divide)

Status: proposta, esperando aprovação · 2026-10-09 · base: `2026-10-09-telas-inventario-design.md` · componentes: `2026-10-09-telas-componentes-design.md`

As outras specs melhoram cada tela no lugar onde ela está. Esta spec decide **onde cada coisa fica**: o que sai, o que junta com outra tela e o que vira duas. Ela vem antes das outras: se uma decisão daqui mudar, a spec do grupo segue o que estiver aqui.

Canvas: https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página **"Mapa do app"**. Ela tem três pranchas: "Mapa · hoje" (cada lugar com a etiqueta do que acontece com ele), "Mapa · proposto" e "Mapa · decisões".

**Fora de escopo:** a OS, que está em outra sessão. No mapa ela aparece como um bloco cinza.

## Resultado

| | Hoje | Proposto |
|---|---|---|
| Lugares fora da OS (telas + linhas de menu) | 42 | 27 |
| Linhas na aba Mais | ~23 (`settings.dart`) | 11 |
| Telas para cadastrar um veículo | 4 (formulário + marca + modelo + categoria) | 1 |
| Telas no primeiro acesso | 10 | 3 ou 4 |

## Princípio

Cada aba responde uma pergunta só:

| Aba | Pergunta |
|---|---|
| Início | O que tem para fazer? |
| Clientes | Quem é esse cliente e o que já fiz para ele? |
| Agenda | Quando? |
| Financeiro | Quem me deve? |
| Mais | Como a empresa está configurada? |

O que não responde à pergunta da aba sai da aba.

## Cortar

| O quê | Onde está hoje | Por que sai | Para onde vai |
|---|---|---|---|
| Filtros de ícone na Início (7 a 10) | `home.dart:41`, `:383-467` | Ficam escondidos, são só ícone e têm alvo de 36 | `SegmentToggle` "Em aberto \| Todas"; o resto vai para o "…" |
| Telas de marca, modelo e categoria | `device_form_screen.dart:444-519` → `accumulated_value_list_screen.dart` | São 3 idas e voltas antes da placa | `SuggestField` de modelo, que já traz marca e tipo (spec de veículos) |
| Boas-vindas, Contatos, "Quase lá!" | `onboarding/welcome_screen.dart`, `company_contact_screen.dart`, `confirm_bootstrap_screen.dart` | Não pedem nenhuma decisão. O código já trata os dados delas como opcionais ou tem padrão para eles | Dados da empresa, depois do primeiro acesso (spec de primeiro acesso) |
| Questionário (3 passos) | `onboarding/segmentation_onboarding_screen.dart` | Só grava a resposta no usuário; não muda nada no app | **Depende do Rafael:** o dado é usado em algum lugar (marketing)? |
| "Acesso negado" no Financeiro | `navigation_controller.dart:30-37`, `permission_widgets.dart:298` | Técnico toca a aba todo dia e cai numa tela sem saída | A aba só aparece com `viewFinancialReports` |
| Código morto | Lista em `telas-inventario` | Não aparece na tela | Remoção em PR próprio |

## Juntar

| O quê | Hoje | Proposto | Muda dado? |
|---|---|---|---|
| **Cliente + veículo** | Veículos é um item da aba Mais (`settings.dart:198-204`) e não tem ligação com o cliente (`Device` não tem cliente, `device.dart:9-18`) | Os veículos aparecem dentro da tela do cliente. A aba Clientes busca também por placa. O detalhe do veículo abre a partir do cliente | Não. Os veículos de cada cliente saem das OS dele (`customer` + `deviceIds`), como na spec de veículos |
| **Serviços + produtos** | 2 itens em Mais e 4 telas copiadas (`service_*`, `product_*`) | Um "Catálogo" com "Serviços \| Produtos". Na OS, uma busca acha os dois | Não. As coleções continuam separadas; só a tela é uma (`CatalogListScreen`) |
| **"A receber"** | É um filtro na Início (`home.dart:53-76`) e um bloco no Financeiro | Fica só no Financeiro, como "Quem me deve" | Não |
| **Escolher cliente + aba Clientes** | 2 arquivos (`customer_list_screen.dart`, `home_customer_list.dart`) | Uma lista com dois modos: escolher (na OS) e ver (na aba) | Não |
| **Sua conta** | Perfil, Trocar empresa, "Aceitar" e Sair espalhados em 3 seções de Mais | Uma tela: perfil, trocar empresa, entrar com código e sair | Não |
| **Preferências** | Idioma, Modo noturno e 4 lembretes soltos em Mais (`settings.dart:267-414`) | Uma tela: idioma, aparência e lembretes | Não |
| **Avançado** | Integrações e Configurações iniciais misturadas com o dia a dia | Uma tela: integrações (links do ChatGPT/Claude), Asaas, refazer a configuração inicial | Não |
| **Plano** | 4 linhas (plano, ver planos, gerenciar, restaurar) | Uma tela Plano com o uso e os limites reais (`SubscriptionLimits.defaults`) | Não |

## Dividir

| O quê | Hoje | Proposto |
|---|---|---|
| **Financeiro** | Um painel de 2.859 linhas: 7 blocos, 2 gráficos, 4 filtros (`financial_dashboard_simple.dart`) | A aba **"Quem me deve"** (spec do financeiro) e uma tela **"Relatório"** pelo "…": gráficos, serviços e produtos mais vendidos, PDF |
| **Dados da empresa** | 834 linhas que misturam o que o cliente vê, as funções do app e os termos (`company_form_screen.dart`) | **Dados da empresa**: tudo o que aparece na OS do cliente (nome, logo, contato, endereço, termos). **O que usar no app**: ramo, especialidades, agenda, atendimento fora, contratos, controle de veículos |

## Abas por papel

| Papel | Abas |
|---|---|
| Dono, administrador, gerente | Início · Clientes · Financeiro · Mais (+ Agenda se a empresa usa agendamento) |
| Técnico, supervisor, consultor | Início · Agenda (se usa) · Clientes · Mais. Sem Financeiro |

Hoje as abas são fixas e a navegação é por índice (`navigation_controller.dart:104-110`, `home_customer_list.dart:235`). Passa a ser uma lista de abas visíveis (enum), conforme a spec da Início.

## Aba Mais depois

```
[Rafael · Oficina Exemplo · Administrador]  → Sua conta
Sua empresa:  Dados da empresa · O que usar no app · Equipe · Plano
Cadastros:    Catálogo · Checklists · Contratos (se usa) · Avaliações
Você:         Preferências · Avançado
```

São 11 linhas, contra ~23 hoje.

## Antes de cortar: confirmar com dados

O app manda as telas visitadas para o Firebase Analytics (`FirebaseAnalyticsObserver`, `lib/main.dart:98`). Isso vale para telas abertas por rota com nome; as abas provavelmente não entram. Um relatório de 30 dias de `screen_view` confirma ou derruba as estimativas de uso. Os pontos que mais dependem desse dado:

- quantas empresas abrem Veículos pelo menu Mais (decide se vale manter um atalho "Todos os veículos" em Avançado ou no Catálogo);
- uso de Integrações e Avaliações;
- uso dos filtros da Início além de "Em aberto".

## Ordem de implementação

1. **Abas por papel** (risk:low): o Financeiro some para quem não pode ver e o índice passa a ser enum. É pequeno e acaba com o "Acesso negado" diário.
2. **Mais reorganizada** (risk:low): Sua conta, Preferências, Avançado e Plano. Só move itens, nenhuma tela nova de dado.
3. **Catálogo** (risk:low): `CatalogListScreen` + `CatalogItemForm` com "Serviços | Produtos".
4. **Cliente + veículo** (risk:low): a tela do cliente com os veículos dele e a busca por placa. Depende da tela do cliente (spec de clientes).
5. **Financeiro dividido** (risk:low): aba "Quem me deve" + Relatório.
6. **Dados da empresa dividido** (risk:low na tela; **risk:high** se mexer em ramo/segmento, que muda rótulos e formulários).
7. **Primeiro acesso curto** (**risk:high**: auth e criação de empresa).

## Perguntas em aberto

1. O dado do questionário do primeiro acesso é usado em algum lugar? Se não for, ele sai.
2. Empresas que usam controle de veículos (`useDeviceManagement`) ainda precisam de uma lista de todos os veículos fora do cliente? A sugestão é um atalho em Avançado, se o Analytics mostrar uso.
3. O técnico vê a aba Clientes? Hoje vê. A proposta mantém, porque ele precisa achar o telefone do cliente.
