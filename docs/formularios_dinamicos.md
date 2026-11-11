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
- Itens do template: `FormItemDefinition` (`id`, `label`, `type`, `options?`, `required`, `allowPhotos`, `reading?`).
- Instâncias (snapshot do template na OS): `OrderForm` (`formDefinitionId`, `title`, `items`, `status`, `responses`).
- Respostas: `FormResponse` (`itemId`, `value`, `photoUrls[]`).
- Observações: `OrderForm.notes` (`Map<String, FormItemNote>`, por `itemId`) e `OrderForm.aiFilled` (perguntas cuja resposta veio da IA e não foi mexida). Ver "Observação" abaixo.

### Observação (#685)
Campo novo do checklist da OS, **fora de `responses`**:

```json
// companies/{companyId}/orders/{orderId}/forms/{instanceId}
{
  "responses": [{ "itemId": "body", "value": ["Porta"], "photoUrls": ["https://…/1.jpg"] }],
  "notes": {
    "body": {
      "text": "Amassado na porta traseira esquerda",
      "ai": false,
      "options": [{ "option": "Porta", "text": "perto da maçaneta", "ai": false }],
      "photos": [{ "url": "https://…/1.jpg", "text": "Risco no para-lama", "ai": false }]
    }
  },
  "aiFilled": []
}
```

- **Por que fora de `responses`:** o app 1.56, o app web (`firebase/webapp/src/lib/forms/data.ts`) e o app atual regravam cada resposta só com `itemId`, `value` e `photoUrls`, e a gravação sem internet do app atual tira a resposta com `arrayRemove` do objeto exato. Um campo a mais na resposta seria apagado ou duplicaria a resposta. Campo novo no documento passa intacto por todos, que gravam com `update` de campos fixos.
- **Três níveis, todos opcionais:** da pergunta (toda pergunta), da opção marcada (só em várias escolhas, `checklist`; chave = valor gravado da opção, o texto original do modelo, o mesmo de `value`) e da foto (chave = URL, a mesma de `photoUrls`). Na pergunta Sim/Não e na de uma opção, a observação da pergunta basta.
- **Gravação:** `FormsService.saveNote` grava só `notes.{itemId}` (e `updatedAt`), com `FieldPath`; sem internet a escrita fica na fila. Salvar uma resposta (`FormsService.answerWrite`) nunca escreve `notes`.
- **Foto apagada leva a observação junto**, na mesma escrita da resposta (`notes.{itemId}` sem aquela foto; se não sobrar texto, o campo é apagado). Vale no app (online e na fila) e no web.
- **Opção desmarcada:** a observação fica guardada e só aparece de novo se a opção voltar a ser marcada. PDF, web e link do cliente mostram só as das opções marcadas e das fotos que ainda existem.
- **`ai`:** `true` enquanto o texto é o da IA; a primeira edição da pessoa grava `false`. `aiFilled` lista as perguntas cuja resposta veio da IA. Os dois já existem no modelo, mas nesta etapa nada grava `true` (a IA entra nas etapas 3 e 4 da spec `docs/superpowers/specs/2026-11-10-checklist-ia-foto-design.md`).
- **Onde aparece:** sheet da pergunta (“+ Observação” como link embaixo da resposta; com texto, a linha “Observação” e o texto, tocar edita), resumo do checklist (embaixo da resposta, em `textTertiary`), PDF do app e do web (embaixo da resposta: o texto, “Porta: …” e “Foto 2: …”), link do cliente (`note`, `optionNotes` e `photoNotes` em cada item de `forms`, sem a marca `ai`) e app web (só leitura nesta etapa; edição na etapa 5).
- Tipos: Dart (`FormItemNote`, `FormOptionNote`, `FormPhotoNote` em `lib/models/order_form.dart`), Functions (`firebase/functions/src/models/types.ts`) e web (`firebase/webapp/src/lib/forms/model.ts`).

### Pergunta ligada à leitura do equipamento (#646)
Uma pergunta numérica com `reading: true` é a leitura do equipamento (km, horímetro; ver `docs/DEVICE_READING.md`). Só vale para `number` e em ramo com campo de leitura; fora disso é uma pergunta normal.

- **Responder** (à mão; pela IA, #688, pelo mesmo caminho) grava também `orders/{id}.deviceReadings.{deviceId}` e, se a pessoa pode cadastrar equipamentos e o número não volta, a última leitura do equipamento. A OS deixa de mostrar "+ Quilometragem".
- **OS que já tem a leitura**: a pergunta vazia já vem respondida com ela ao abrir o checklist (gravada como texto, igual às respostas digitadas). Checklist concluído não muda.
- **Menor que a última visita**: aviso opaco (`showAppToast`, 5 s) "Menor que os 102.000 km da última visita. Está certo?". Não trava nem desfaz.
- **Qual equipamento**: o do checklist (`OrderForm.deviceId`) ou, sem ele, o único da OS. OS sem equipamento, ou com vários e checklist "de todos": pergunta normal.
- **Onde fica**: `reading` vai no item do modelo e no snapshot da OS (só é gravado quando `true`). Modelos do seed: `km_atual` em `checklist_entrada_auto` (automotive) e `horas_operacao` em `checklist_entrada_asset` (asset_maintenance, modelo novo). O editor de modelo do app preserva a marca ao editar a pergunta, mas ainda não liga nem desliga; o web não usa a marca.
- Código: `lib/utils/checklist_reading.dart` (`ChecklistReadingLink`, regras puras), `FormFillScreen.readingLink` (`_prefillReading`, `_syncReading`), `_readingLinkFor` em `order_screen_v2.dart`.

### Tipos suportados (atual)
`text`, `number`, `select`, `checklist`, `boolean`, `photo_only`.

> Campos como `date`, `multi`, `repeatable`, `not_applicable` e bindings por serviço/produto ficam como evolução futura (mantemos o design aqui como referência).

## Estrutura no Firestore/Storage (tenant-aware)
- Templates globais por segmento (seed): `/segments/{segmentId}/forms/{formId}`.
- Templates da empresa (V2): `/companies/{companyId}/forms/{templateId}`.
- Templates da empresa (legado, ainda usado em partes do app): `/companies/{companyId}/forms/{formId}`.
- Instâncias vinculadas à OS: `/companies/{companyId}/orders/{orderId}/forms/{formId}`.
- Fotos por item (atual): `tenants/{companyId}/orders/{orderId}/forms/{orderFormId}/{itemId}_{timestamp}.jpg`. O app web grava no mesmo lugar (`{itemId}_{timestamp}_{n}.{ext}`); `storage.rules` só libera um nível abaixo do checklist.
- App web: telas e regras em `docs/WEB_APP.md`, seção "Checklists".

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

## UX (seguir `docs/APP_DESIGN_SYSTEM.md`)
- Tela de OS: seção “Checklists” com uma linha por checklist, ponto + texto de status (“Faltam 3 perguntas”, “Completo”).
- **Resumo do checklist** (`lib/screens/forms/form_fill_screen.dart`, `FormFillScreen`):
  - Fundo cinza agrupado, título grande e voltar em vidro.
  - Cabeçalho: aparelho/veículo, status (ponto + texto: âmbar “Faltam N perguntas”, verde “Completo” ou, se foi concluído com perguntas sem resposta, verde “Concluído · N sem resposta”) e o único botão azul: “Começar”, “Continuar” ou “Concluir checklist”. Faltando só perguntas opcionais, “Concluir assim mesmo” aparece como link. No checklist concluído, “Reabrir” aparece como link logo abaixo do status (só para quem pode reabrir).
  - “Perguntas”: cartão branco com cada pergunta, a resposta em palavras (“Sim”, a opção, “Óleo, Filtro”, o texto, “2 fotos”) ou “Sem resposta · Obrigatória”, e as miniaturas das fotos (tocar abre a galeria em tela cheia, com lixeira enquanto não estiver concluído). Tocar na linha abre aquela pergunta. Com o checklist concluído, o toque mostra um alerta “Checklist concluído” que oferece “Reabrir” (ou, para quem não pode, diz que quem gerencia a equipe reabre). O texto do status vem de `completedChecklistLabel` (`form_question_sheet.dart`) e, no web, de `completedStatus` (`lib/forms/model.ts`); a linha do checklist na OS usa o mesmo texto (#588).
  - Checklist sem nenhuma resposta abre direto na primeira pergunta.
- **Uma pergunta por vez** (`lib/screens/forms/form_question_sheet.dart`, `FormQuestionSheet`, aberta em sheet grande):
  - Topo: “Fechar” (X em vidro), nome do checklist, barra de progresso em segmentos (um por pergunta, azul quando respondida) e “Faltam N” (nunca “2 de 5”), pergunta em letra de título.
  - `boolean`: “Sim”/“Não” em botões grandes (64 de altura, crescem com o texto). **Tocar já salva e passa.**
  - `select`: opções em botões grandes com ✓ na resposta atual; tocar salva e passa. Salva a opção original do modelo e mostra a traduzida.
  - `checklist` (várias): os mesmos botões, ✓ em cada marcada, “Pronto” salva e passa.
  - `text`/`number`: campo grande com teclado aberto (numérico para `number`); “Próxima” (botão ou teclado) salva e passa. Voltar ou fechar mantém o que foi digitado.
  - `photo_only`: “Tirar foto” abre a câmera; “Escolher da galeria” é link. Com foto, o botão vira “Próxima” e aparece “Tirar outra foto”.
  - Qualquer item com `allowPhotos`: botão “Foto” em vidro embaixo, sempre no mesmo lugar (Câmera/Galeria).
  - Embaixo da resposta (e das fotos): “+ Observação” como link. Abre a sheet pequena “Observação” (`lib/screens/forms/form_note_sheet.dart`) com um campo para a pergunta, um por opção marcada (várias escolhas) e um por foto; “Pronto” grava. Com texto, a linha mostra “Observação” e o texto; tocar edita.
  - Embaixo: “Voltar à anterior” (a partir da 2ª) e “Pular por agora” em toda pergunta. Obrigatória não trava: a pulada continua em “Faltam N”.
  - Depois da última pergunta a sheet fecha; se não faltar nada, o checklist é concluído (`status=completed`) e volta para a OS. Faltando algo, volta ao resumo.
  - Upload e caminhos de Storage não mudaram (`tenants/{companyId}/orders/{orderId}/forms/{formId}/{itemId}_{timestamp}.jpg`).
- Fora deste passo: sugestão automática do checklist na OS, IA (“Falar as respostas”, leitura da foto) e câmera abrindo sozinha na pergunta de foto (ver `docs/superpowers/specs/2026-10-10-checklists-design.md`).

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
- Manutenção de ativos: `checklist_entrada_asset` (horímetro ligado à leitura)
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
