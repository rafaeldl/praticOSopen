# Contatos do cliente: cadastro pelo celular e WhatsApp certo

Doc técnica a criar na implementação: `docs/CUSTOMER_CONTACTS.md`. Base existente: `docs/RECEIVE_SHARE.md`.

## Problema

Cadastrar cliente exige digitar nome e telefone, embora o contato quase sempre já esteja no celular ou numa conversa do WhatsApp. Depois, o número digitado à mão pode abrir a conversa errada ao mandar a OS ou a cobrança.

## Decisões

1. **O telefone é o vínculo.** Não existe API para ligar um cliente a um contato do WhatsApp. Com o número certo, o `wa.me` abre a conversa da pessoa. Nenhum id externo é guardado.
2. **Uma regra só para o número.** App, link da OS e convites usam a mesma função, que considera o país da empresa.
3. **Sem acesso à agenda inteira.** O app não usa `READ_CONTACTS` nem pede permissão de contatos. O cadastro usa o seletor do sistema e recebe só o contato que a pessoa escolher.
4. **Compartilhar contato abre o cadastro.** Reaproveita a Share Extension e o `ReceiveShareService` que já recebem fotos e PDFs. Vira mais um destino, antes do "Em qual OS?".
5. **Duplicado não bloqueia sozinho.** O app avisa e deixa a pessoa decidir, porque há números compartilhados (família, empresa).
6. **Sempre revisar antes de salvar.** Contato escolhido ou recebido abre o formulário preenchido, nunca grava direto.

## Como funciona

### Número normalizado

`whatsappNumber` (`lib/utils/customer_utils.dart`) passa a ser a função única. Ela usa `phone_numbers_parser` e `Global.companyAggr?.country`, como `formatPhone`. Regras:

- Número com `+` mantém o próprio país.
- Número sem DDI recebe o DDI do país da empresa.
- Sem país, o padrão é BR. Empresa fora do Brasil não pode ganhar 55.
- Número inválido volta só com dígitos, sem quebrar a tela.

`Customer.phone` continua como está. Nada de campo novo ou migração nesta fase: a comparação é feita com a função acima, sobre a lista que o `CustomerStore` já carrega.

### Escolher dos contatos

Botão "Escolher dos contatos" ao lado do telefone no `customer_form_screen`, só em cliente novo. Vale também para o cadastro dentro de "Qual cliente?", que usa o mesmo formulário.

- iOS: `CNContactPickerViewController`, que não pede permissão.
- Android: `ACTION_PICK`, que não exige `READ_CONTACTS` e devolve um contato. O novo `ACTION_PICK_CONTACTS` só existe no Android 17; o app está em `targetSdk` 36.
- Contato com vários números: pergunta qual usar. Sem número: preenche só o nome.

### Receber contato

- iOS: `NSExtensionActivationRule` passa a aceitar `public.vcard`. Se o vCard vier só como dados, sem `public.file-url`, grava em arquivo temporário antes do plugin, como já é feito com PDF.
- Android: `intent-filter` `SEND` para `text/x-vcard` e `text/vcard`.
- Flutter: `classifyReceived` ganha o tipo contato (`.vcf`). O serviço lê o arquivo, abre o formulário preenchido e apaga a cópia.
- Sem usuário logado, o contato é ignorado, como já acontece com fotos e PDFs.
- `.vcf` com mais de um contato: usa o primeiro e avisa. Importar vários é outra entrega.

### Duplicado

Ao salvar cliente novo com telefone, compara com os clientes da empresa. No Brasil, a comparação ignora o nono dígito, porque o WhatsApp ainda traz números antigos com 8 dígitos. Se achar, mostra "Já cadastrado" com "Abrir cliente" e "Salvar mesmo assim".

### Mandar para a pessoa certa

Link da OS, cobrança e aviso já usam `wa.me` com mensagem pronta. Só mudam para a função única. Arquivo não vai direto, porque o `wa.me` só leva texto: PDF continua pela folha de compartilhar.

## Dúvidas para testar em aparelho real

- O WhatsApp entrega o cartão de contato de uma conversa para outro app? Pelo app Contatos deve funcionar. Pelo WhatsApp não foi confirmado.
- Em que formato chega no iOS: arquivo ou dados?
- Com WhatsApp e WhatsApp Business no mesmo aparelho, qual abre o `wa.me`?
- O iOS exige `NSContactsUsageDescription` só por usar o seletor? Hoje a chave não existe no projeto.

Se o WhatsApp não entregar o contato, a entrega continua valendo pelo app Contatos e pelo seletor.

## Fora do escopo

- Ler ou enviar a agenda inteira ao servidor.
- Sincronizar edições entre agenda e cliente.
- Importar vários clientes de uma vez (issue própria, depois da primeira entrega).
- Mandar arquivo direto para um contato do WhatsApp.

## Ordem

1. Número único no app, com a correção do DDD 55 no link da OS.
2. Mesma correção nas Functions.
3. Escolher dos contatos.
4. Aviso de duplicado.
5. Receber contato compartilhado.
6. Importar vários clientes.

## Referências

- [Política de contatos do Google Play](https://support.google.com/googleplay/android-developer/answer/16909972), em vigor desde 28/10/2026.
- [Perguntas frequentes da política](https://support.google.com/googleplay/android-developer/answer/16935362).
