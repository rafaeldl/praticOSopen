# PRIMEIRO CONTATO & AUTO-CADASTRO

## Passo 1: Verificar se usuario esta vinculado
exec(command="curl -s -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" \"$PRATICOS_API_URL/bot/link/context\"")

Se `linked:true` → usuario ja vinculado, ir para fluxo normal.

## Passo 2: Usuario NAO vinculado

**Se enviou CODIGO (LT_, INV_):**
exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"token\":\"CODIGO_AQUI\"}' \"$PRATICOS_API_URL/bot/link\"")
- Sucesso → boas-vindas com nome/empresa
- INVALID_TOKEN → pedir verificar codigo
- ALREADY_LINKED → orientar desconectar no app

**Se tem `pendingInvites` (array não vazio):**
O admin da empresa já convidou esse número. Aceitar automaticamente via endpoint existente.

- **1 convite:** Informar no idioma do usuario que [invitedByName] da empresa [companyName] adicionou como [role] e perguntar se aceita. (pt-BR: "[invitedByName] da empresa [companyName] te adicionou como [role]. Aceita o convite?")
  - Sim → aceitar:
    exec(command="curl -s -X POST -H \"X-API-Key: $PRATICOS_API_KEY\" -H \"X-WhatsApp-Number: {NUMERO}\" -H \"Content-Type: application/json\" -d '{\"inviteCode\":\"TOKEN_AQUI\",\"whatsappNumber\":\"{NUMERO}\"}' \"$PRATICOS_API_URL/bot/invite/accept\"")
  - Não → responder no idioma do usuario de forma casual (pt-BR: "Sem problemas! Qualquer coisa é só mandar mensagem.")
- **Múltiplos convites:** listar todos com numero (1, 2, 3...) e perguntar qual aceitar. Aceitar o escolhido com o mesmo endpoint acima.

**Se tem `pendingRegistration`:** retomar AUTO-CADASTRO pelo `state`.

**Se nenhum dos anteriores:** perguntar (no idioma do usuario) se ja usa, recebeu convite, quer criar ou conhecer.
- Ja usa → orientar no idioma do usuario a gerar codigo em Configuracoes > WhatsApp e enviar (pt-BR: "Gera codigo em Configuracoes > WhatsApp e manda aqui")
- Recebeu convite → pedir o codigo no idioma do usuario (pt-BR: "Manda o codigo")
- Quer criar → iniciar AUTO-CADASTRO
- Quer conhecer → sugerir https://praticos.web.app OU compartilhar o contato do bot no WhatsApp
- Quer indicar pra colega → orientar a compartilhar o contato do bot (ver INDICAÇÃO abaixo)

**Idioma:** para usuarios NAO vinculados, detectar o idioma da primeira mensagem. Responder nesse idioma durante todo o fluxo. Ao vincular, chamar `PATCH /api/bot/user/language {"preferredLanguage":"[codigo]"}` para persistir.

**Regra:** msgs CURTAS, 1-2 frases. Tom casual.

---

## INDICAÇÃO / REFERRAL

Quando o usuario quer indicar o PraticOS pra um colega, gerar uma msg formatada NO IDIOMA DO USUARIO pronta pra encaminhar. Links sao universais, manter sempre.

Exemplo pt-BR (adaptar ao idioma do usuario):
```
message(action="send", message="Conheça o *PraticOS* — gestão de O.S. direto no celular!\n\n📱 Chama no WhatsApp: https://wa.me/554888794742\n🌐 Ou acesse: https://praticos.web.app\n\nÉ só mandar um oi que eu ajudo a criar sua conta na hora!")
```

Depois, orientar o usuario NO SEU IDIOMA a encaminhar a mensagem e compartilhar o contato do bot.
(pt-BR: "Encaminha essa mensagem pro seu colega! Se quiser, compartilha meu contato também (toca no meu nome > Encaminhar Contato)")

**Regras:**
- SEMPRE enviar a msg formatada via message() — ela é o "cartão de visita" encaminhável
- Depois sugerir compartilhar o contato do bot como complemento
- Tom casual, máx 2 msgs (o cartão + a orientação)

---

## AUTO-CADASTRO

**Regra:** msgs curtas, max 2 frases + lista. Variar tom.

Todas as chamadas abaixo usam os mesmos headers: -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}"

1. POST /bot/registration/start `{"locale":"[idioma-detectado]"}` → usar idioma detectado da primeira mensagem do usuario (ex: "fr-FR", "en-US"). Se nao detectou, usar "pt-BR". Perguntar nome da empresa
2. POST /bot/registration/update `{"companyName":"NOME"}` → mostrar segmentos
3. POST /bot/registration/update `{"segmentId":"ID"}` → mostrar especialidades (se houver, senao pular p/ 5)
4. POST /bot/registration/update `{"subspecialties":["id1","id2"]}`
5. POST /bot/registration/update `{"includeBootstrap":true}` → perguntar se quer dados exemplo
6. Mostrar resumo curto e confirmar
7. POST /bot/registration/complete → responder no idioma do usuario celebrando e sugerindo criar a primeira OS (pt-BR: "Pronto! Quer criar sua primeira OS?")

Cancelar: DELETE /bot/registration
