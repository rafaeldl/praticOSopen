# Formulários Dinâmicos por Empresa e Segmento

Documento de solução para formulários dinâmicos no PraticOS, seguindo as diretrizes de UX em `docs/UX_GUIDELINES.md` (Cupertino-first, simplicidade, status claros e validação inline).

## Objetivo
- Permitir que cada empresa crie formulários dinâmicos (checklist, questionário, etc.) e os anexe a Ordens de Serviço (OS).
- Habilitar formulários globais por segmento, reutilizáveis por todas as empresas do segmento.
- Garantir captura de fotos por item e vínculo das imagens à OS e ao item do formulário.
- Controlar obrigatoriedade por serviço/produto e bloquear fechamento da OS se pendências existirem.

## Modelagem (implementada no app)
Hoje o app usa `FormDefinition` como template e `OrderForm` como instância vinculada à OS.

- Templates (definição): `FormDefinition` (`id`, `title`, `description?`, `isActive`, `items`).
- Itens do template: `FormItemDefinition` (`id`, `label`, `type`, `options?`, `required`, `allowPhotos`).
- Instâncias (snapshot do template na OS): `OrderForm` (`formDefinitionId`, `title`, `items`, `status`, `responses`).
- Respostas: `FormResponse` (`itemId`, `value`, `photoUrls[]`).

### Tipos suportados (atual)
`text`, `number`, `select`, `checklist`, `boolean`, `photo_only`.

> Campos como `date`, `multi`, `repeatable`, `not_applicable` e bindings por serviço/produto ficam como evolução futura (mantemos o design aqui como referência).

## Estrutura no Firestore/Storage (tenant-aware)
- Templates globais por segmento (seed): `/segments/{segmentId}/forms/{formId}`.
- Templates da empresa (V2): `/companies/{companyId}/forms/{templateId}`.
- Templates da empresa (legado, ainda usado em partes do app): `/companies/{companyId}/forms/{formId}`.
- Instâncias vinculadas à OS: `/companies/{companyId}/orders/{orderId}/forms/{formId}`.
- Fotos por item (atual): `tenants/{companyId}/orders/{orderId}/forms/{orderFormId}/{itemId}_{timestamp}.jpg`.

## Regras de obrigatoriedade
O core atual cobre a criação e preenchimento de formulários na OS. As regras de “obrigatórios por serviço/produto” continuam como diretriz de evolução (ver seção “Próximos passos”).

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
- Modelos: `lib/models/form_definition.dart`, `lib/models/order_form.dart`.
- Repositórios:
  - Globais (segmento): `lib/repositories/segment/segment_form_template_repository.dart` (path `segments/{segmentId}/forms`).
  - Empresa (V2): `lib/repositories/v2/form_template_repository_v2.dart` (path `companies/{companyId}/forms`).
- Serviço: `lib/services/forms_service.dart` (instâncias em `orders/{orderId}/forms` e upload de fotos).
- Store: `lib/mobx/form_template_store.dart` (lista templates da empresa + globais do segmento e importação).

## Catálogo global (seed) — procedimentos “mundo real”
Os templates globais são “padrões de mercado” para aumentar qualidade, reduzir retorno e melhorar evidência do serviço (fotos, medições, aceite do cliente).

- Automotivo: `termo_autorizacao_automotive`, `checklist_seguranca_final_auto`
- HVAC: `checklist_seguranca_hvac`, `comissionamento_pos_servico_hvac`
- Smartphones: `termo_autorizacao_smartphones`, `teste_pos_reparo_cel`
- Computadores: `termo_privacidade_pc`, `checklist_qualidade_pos_servico_pc`
- Eletrodomésticos: `checklist_seguranca_appliances`, `teste_pos_reparo_appliances`
- Genérico: `termo_autorizacao_generico`, `pesquisa_satisfacao_nps`
- Elétrica: `checklist_seguranca_eletrica`, `laudo_servico_eletrico`, `checklist_qualidade_eletrica`
- Hidráulica: `checklist_seguranca_hidraulica`, `teste_estanqueidade`, `entrega_hidraulica`
- Segurança eletrônica: `vistoria_pre_instalacao_seguranca`, `comissionamento_seguranca`, `termo_privacidade_seguranca`
- Energia solar: `checklist_seguranca_solar`, `comissionamento_solar`, `entrega_solar`
- Impressoras: `checklist_entrada_printers`, `manutencao_preventiva_printers`, `teste_pos_servico_printers`

Fonte: `firebase/scripts/seed_forms.js`.

## Regras de segurança
- Firestore: validar `companyId` e claims nas paths tenant-aware; impedir acesso cruzado.
- Storage: regras para `tenants/{companyId}/orders/{orderId}/forms/**` respeitando claims e vínculo com a OS.

## Próximos passos
1) Criar modelos e rodar `fvm flutter pub run build_runner build --delete-conflicting-outputs`.  
2) Implementar repositórios (templates/instâncias) com TenantRepository/RepositoryV2.  
3) Implementar stores e integrar UI na OS seguindo `docs/UX_GUIDELINES.md`.  
4) Ajustar fluxo de serviços/produtos para auto-anexar formulários obrigatórios e bloquear fechamento.  
5) Atualizar regras de Firestore/Storage para os novos caminhos.  
