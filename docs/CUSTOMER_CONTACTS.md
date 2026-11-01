# CUSTOMER_CONTACTS.md

## Visão Geral
Cadastrar cliente pelo celular e abrir a conversa certa no WhatsApp. O telefone é o único vínculo com o WhatsApp: não existe API que ligue um cliente a um contato, e nenhum id externo é guardado. Spec: `docs/superpowers/specs/2026-11-01-contatos-do-cliente-design.md`.

## Arquitetura
- `lib/utils/customer_utils.dart`
  - `whatsappNumber(phone, {country})`: regra única do número do `wa.me`.
  - `phoneMatchKey` e `findCustomerByPhone`: comparação de telefones para o aviso de repetido.
- `lib/utils/vcard.dart`: `ContactCard` (nome, telefones, e-mail) e `parseVCards`.
- `lib/services/contact_picker_service.dart`: abre o seletor do sistema pelo canal `br.com.rafsoft.praticos/contacts`.
  - iOS: `ContactPicker` em `ios/Runner/AppDelegate.swift`, com `CNContactPickerViewController`.
  - Android: `MainActivity.kt`, com `ACTION_PICK` do tipo `Phone.CONTENT_TYPE`.
- `lib/screens/customers/customer_form_screen.dart`: link "Escolher dos contatos", `askContactPhone` ("Qual número?") e aviso "Já cadastrado".
- `lib/services/received_share.dart` e `receive_share_service.dart`: contato compartilhado (ver `docs/RECEIVE_SHARE.md`).

Sem campo novo no Firestore e sem migração: `Customer.phone` continua como está.

## Fluxo de Dados

```
Seletor do sistema ──┐
                     ├─> ContactCard ─> "Qual número?" ─> formulário preenchido ─> ✓ ─> "Já cadastrado"? ─> salva
Contato compartilhado┘
```

## Regras de Negócio

### Número do WhatsApp
- Com `+`, mantém o próprio país.
- Sem `+`, recebe o DDI do país da empresa (`Global.companyAggr?.country`, ou `country`). Sem país ou com país desconhecido, BR.
- Número válido para o país: DDI + número nacional. O parser não confunde o DDD 55 com o DDI (`55999990000` vira `5555999990000`).
- Inválido: volta só com dígitos. A exceção é o celular antigo do Brasil, com 8 dígitos depois do DDD, que o parser considera inválido e o WhatsApp ainda usa: 10 ou 11 dígitos sem `+` numa empresa do Brasil recebem o 55.

Usam a função: `share_link_service`, `collaborator_form_screen`, `invite_share_sheet`, `Invite.getWhatsAppLink` e `customer_detail_screen`. O WhatsApp das Functions é da issue #479.

### Escolher dos contatos
- Só em cliente novo, inclusive no "+" de "Qual cliente?", e só em iOS e Android.
- Nenhuma permissão de contatos é declarada ou pedida. Não há `READ_CONTACTS`, `CNContactStore` nem `NSContactsUsageDescription`.
- Sobrescreve nome e telefone do formulário com os do contato, e o e-mail se houver. O que o contato não tem continua como está.
- E-mail preenchido abre o cartão "Mais dados", para não ficar escondido.
- Nada é salvo sem o "✓".

**Diferença entre plataformas.** No Android, sem `READ_CONTACTS`, o sistema só libera a linha escolhida. Por isso o seletor é o de telefones: a pessoa escolhe o número na lista do sistema e o app recebe nome e número. Não vem e-mail, e contato sem número não aparece. Escolher o contato inteiro (`Contacts.CONTENT_TYPE`) daria só o nome, sem telefone. No iOS vêm todos os telefones e o primeiro e-mail, e "Qual número?" aparece no app.

### Telefone repetido
- Só ao salvar cliente novo com telefone. Editar não avisa.
- Compara `phoneMatchKey` com os clientes da empresa. No Brasil, tira o nono dígito do celular (`5548984087801` e `554884087801` são o mesmo).
- "Abrir cliente" fecha o formulário devolvendo o cliente que já existe: a lista abre o detalhe, e "Qual cliente?" o escolhe para a OS.
- "Salvar mesmo assim" cria o novo, porque há números compartilhados.
- Falha ou demora de mais de 5 segundos ao carregar a lista não impede salvar.
- Perfis: as regras do Firestore deixam todo membro da empresa ler os clientes, então a comparação vale para quem pode cadastrar, sem filtro.

### Receber contato
- Abre o formulário preenchido, com as mesmas regras acima. Sem login, é ignorado.
- `.vcf` com vários contatos usa o primeiro e avisa.
- Sem `manageCustomers` ou com arquivo ilegível, avisa em alerta.
- O parser lê vCard 2.1, 3.0 e 4.0: linhas dobradas, prefixo de grupo (`item1.TEL`) e quoted-printable. Nome vem de `FN`, depois `N`, depois `ORG`.

## Exemplos de Uso

```dart
whatsappNumber('55999990000');                  // 5555999990000
whatsappNumber('(202) 555-0123', country: 'US'); // 12025550123
whatsappNumber('+351 912 345 678');              // 351912345678

final duplicate = findCustomerByPhone(customers, '(48) 8408-7801');
```

## Para testar em aparelho real
- O WhatsApp entrega o cartão de contato de uma conversa a outro app, no iPhone e no Android?
- Com WhatsApp e WhatsApp Business no mesmo aparelho, qual abre o `wa.me`?
