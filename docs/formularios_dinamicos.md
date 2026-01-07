# Formulários Dinâmicos por Empresa e Segmento

Documento de solução para formulários dinâmicos no PraticOS, seguindo as diretrizes de UX em `docs/UX_GUIDELINES.md` (Cupertino-first, simplicidade, status claros e validação inline).

## Objetivo
- Permitir que cada empresa crie formulários dinâmicos (checklist, questionário, etc.) e os anexe a Ordens de Serviço (OS).
- Habilitar formulários globais por segmento, reutilizáveis por todas as empresas do segmento.
- Garantir captura de fotos por item e vínculo das imagens à OS e ao item do formulário.
- Controlar obrigatoriedade por serviço/produto e bloquear fechamento da OS se pendências existirem.

## Modelagem (conceito)
- Templates (definição):
  - `FormTemplate`: `id`, `name`, `segmentId?`, `company`, `type` (checklist/questionário/outro), `items` (lista ordenada).
  - `FormItemTemplate`: `id`, `label`, `type` (boolean/text/number/date/photo/select/multi), `options?`, `required`, `allowPhotos` (default true), `maxPhotos?`, `helpText?`, `repeatable?`, `notApplicableAllowed?`, `serviceBinding?`, `productBinding?`.
- Instâncias (snapshot do template na OS):
  - `FormInstance`: `id`, `orderId`, `templateRef` (id + origem: tenant ou segmento), `status` (`pending` | `in_progress` | `completed` | `not_applicable`), `items` (lista de `FormItemInstance`), `company`.
  - `FormItemInstance`: `templateItemId`, `value`, `photos` (lista com `path`, `url`, `createdAt`, `createdBy`).

## Estrutura no Firestore/Storage (tenant-aware)
- Templates da empresa: `/companies/{companyId}/form_templates/{formId}`.
- Templates globais por segmento: `/segments/{segmentId}/form_templates/{formId}`.
- Instâncias vinculadas à OS:
  - Preferencial via TenantRepository/RepositoryV2: `/companies/{companyId}/orders/{orderId}/forms/{formId}` (coleção `forms` para instâncias).
- Fotos de itens: Storage em `tenants/{companyId}/orders/{orderId}/forms/{formInstanceId}/items/{itemId}/{uuid}.jpg`.

## Regras de obrigatoriedade
- Templates podem declarar `serviceBinding` e/ou `productBinding`.
- Serviços/Produtos podem ter campos `requiredFormTemplateRefs` (lista de refs de template) e, opcionalmente, `optionalFormTemplateRefs` para sugerir formulários.
- Ao adicionar `OrderService` ou `OrderProduct`, o sistema auto-anexa instâncias dos templates obrigatórios que ainda não existirem.
- Bloquear finalização da OS se existir formulário obrigatório com status diferente de `completed`.

## Fluxos principais
1. **Criar template (empresa ou segmento)**: UI de administração cria/edita `FormTemplate`; usa RepositoryV2/TenantRepository.
2. **Configurar formulários em Serviços/Produtos**:
   - No cadastro/edição de Serviço/Produto, permitir selecionar templates (tenant + globais do segmento) para `requiredFormTemplateRefs` e opcionais.
   - Persistir essas refs no documento do serviço/produto para uso automático ao compor a OS.
3. **Selecionar e anexar a uma OS**:
   - Listar templates do tenant + globais do segmento (marcar origem).
   - Ao anexar, criar `FormInstance` com snapshot dos itens (`status=pending`).
4. **Preencher formulário**:
   - Ao primeiro input/foto, mudar `status` para `in_progress`.
   - Validar obrigatórios inline; ao completar todos os obrigatórios, setar `status=completed`.
   - Permitir `not_applicable` apenas se `notApplicableAllowed` no template.
5. **Fotos por item**:
   - Botão “Adicionar foto” no item; upload via PhotoService com path tenant-aware.
   - Armazenar refs no `photos` do item, sem duplicar em `OrderPhoto`.
6. **Fechamento da OS**: validar que todos os formulários obrigatórios estão `completed`.

## UX (seguir `docs/UX_GUIDELINES.md`)
- Tela de OS: seção “Formulários” com lista e chips de status (pending/in_progress/completed/not_applicable).
- Tela de preenchimento:
  - `CupertinoPageScaffold` + `CupertinoSliverNavigationBar`.
  - Lista agrupada (`CupertinoListSection.insetGrouped`) com itens ordenados e label + badge “Obrigatório” quando aplicável.
  - Tipos de entrada respeitam HIG (switch para boolean, `CupertinoTextField`/`CupertinoPicker`/`CupertinoDatePicker` conforme tipo).
  - Ação “Adicionar foto” inline no item com pré-visualização e indicador de upload.
  - Botão “Marcar como não aplicável” (quando permitido).
  - Status atualizado em tempo real; feedback de validação leve e consistente com iOS.

## Componentes e serviços
- Novos modelos em `lib/models/`: `form_template.dart` (templates) e `form_instance.dart` (instâncias).
- Repositórios: usar `TenantRepository`/`RepositoryV2` para templates e instâncias.
- Stores MobX:
  - `FormTemplateStore`: lista templates do tenant + globais do segmento (merge e distinção por origem).
  - `FormInstanceStore`: CRUD por OS, atualização incremental de status e itens.
  - Ajustes em `ServiceStore` e `ProductStore` para lidar com `requiredFormTemplateRefs`/opcionais.
- Serviço auxiliar:
  - `FormService`: criar instância, validar obrigatórios, anexar forms por binding, subir fotos via PhotoService, checar bloqueio de fechamento da OS.

## Regras de segurança
- Firestore: validar `companyId` e claims nas paths tenant-aware; impedir acesso cruzado.
- Storage: regras para `tenants/{companyId}/orders/{orderId}/forms/**` respeitando claims e vínculo com a OS.

## Próximos passos
1) Criar modelos e rodar `fvm flutter pub run build_runner build --delete-conflicting-outputs`.  
2) Implementar repositórios (templates/instâncias) com TenantRepository/RepositoryV2.  
3) Implementar stores e integrar UI na OS seguindo `docs/UX_GUIDELINES.md`.  
4) Ajustar fluxo de serviços/produtos para auto-anexar formulários obrigatórios e bloquear fechamento.  
5) Atualizar regras de Firestore/Storage para os novos caminhos.  
