# Ajustes PraticOS - Implementacoes Futuras

Este documento detalha funcionalidades planejadas e ajustes desejados.
Cada item descreve objetivo, comportamento esperado e pontos de atencao.

## Backlog

### Padronizar a edicao/exclusao nas listagens (swipe)
- Objetivo: mover acoes de editar/excluir para gesto de arrastar esquerda/direita.
- Comportamento: gesto revela acoes; menus/context menus nao exibem essas acoes.
- Telas: listagens de Customer, Device, Product, Service, Order.
- Observacoes: alinhar com estilo Cupertino e evitar acao duplicada.

### Cliente sem imagem de perfil
- Objetivo: permitir envio de imagem de perfil do cliente.
- Comportamento: adicionar campo de foto no formulario e exibir na lista/detalhe.
- Telas: `lib/screens/customers/customer_form_screen.dart`, `lib/screens/customers/customer_list_screen.dart`.
- Observacoes: salvar em Storage no tenant correto.

### Busca na lista de OS
- Objetivo: pesquisar OS por numero, cliente ou dispositivo.
- Comportamento: campo de busca com debounce e filtro em tempo real.
- Telas: lista de OS (home).
- Observacoes: avaliar impacto em offline/cache.

### Status pago promove para Autorizado
- Objetivo: se status atual for Orcamento e usuario marcar como pago, mover para Autorizado.
- Comportamento: regra de negocio aplicada no fluxo de pagamento.
- Telas: `lib/screens/payment_form_screen.dart`, `lib/mobx/order_store.dart`.

### Listagem de Devices: placa alinhada a direita
- Objetivo: melhorar leitura da lista mostrando placa alinhada a direita.
- Comportamento: layout com placa em coluna da direita.
- Telas: `lib/screens/device_list_screen.dart`.

### Filtro de cliente na OS e tema escuro
- Objetivo: corrigir contraste/cores do indicador de filtro.
- Comportamento: usar cores do tema atual (dark/light).
- Telas: `lib/screens/order_form.dart`, widgets relacionados.

### Lista de clientes: acoes adicionais
- Objetivo: adicionar acoes "Filtrar OS" e "Nova OS" por cliente.
- Comportamento: acoes rapidas no item da lista ou menu contextual.
- Telas: `lib/screens/customers/customer_list_screen.dart`.
- Observacoes: definir fluxo para pre-selecionar cliente.

### Agenda de entrega/instalacao
- Objetivo: calendario para entregas e instalacoes.
- Comportamento: criar eventos a partir de OS com data/horario.
- Telas: nova tela de agenda + integracao com OS.
- Observacoes: definir permissao e notificacoes.

### Criar cliente a partir dos contatos do telefone
- Objetivo: importar contato como cliente.
- Comportamento: picker de contatos e mapeamento de campos.
- Observacoes: solicitar permissao e tratar duplicidade.

### Atualizar Termos de Uso / link no app
- Objetivo: apontar para termos atualizados.
- Comportamento: atualizar URL e texto na tela de configuracoes.
- Telas: `lib/screens/menu_navigation/settings.dart`.
- Observacoes: manter versoes pt-BR e en.

### Criar usuario e enviar link por email ao adicionar colaborador
- Objetivo: fluxo de convite via email com link de acesso.
- Comportamento: ao criar colaborador, gerar usuario e enviar email.
- Telas: `lib/screens/menu_navigation/collaborator_form_screen.dart`, `lib/services/auth_service.dart`.
- Observacoes: garantir claims/roles no tenant.

### Dados offline
- Objetivo: leitura e escrita basicas sem conexao.
- Comportamento: cache local e fila de sincronizacao.
- Observacoes: definir estrategia de conflitos.

### Categorias de empresas e campos
- Objetivo: ajustar categorias (ex: instalacao de ar, eletronica) e descrever campos.
- Comportamento: atualizar labels e opcoes no cadastro da empresa.
- Telas: `lib/screens/menu_navigation/company_form_screen.dart`.

### Acumular Marcas e Modelos do device
- Objetivo: sugestao/autocomplete com marcas/modelos usados.
- Comportamento: historico agregando entradas anteriores por tenant.
- Observacoes: manter lista pequena e ordenada por uso.

### Etapas do servico
- Objetivo: definir pipeline de etapas para OS/servico.
- Comportamento: exibir progresso e permitir avancar etapas.
- Observacoes: alinhar com status atual de OS.

### Perfil do tecnico (sem acesso a valores)
- Objetivo: papel de tecnico com restricoes financeiras.
- Comportamento: limitar campos de valores e dashboards.
- Observacoes: ajustar roles/claims e rules.

### Tela de novidades do sistema
- Objetivo: exibir changelog/noticias no app.
- Comportamento: lista de novidades com destaque para versao atual.
- Observacoes: fonte de dados (statico vs remoto).

## Concluidos

### Alterar dados do usuario
- Status: concluido.

### Imagens das entidades na tela da OS
- Status: concluido.
