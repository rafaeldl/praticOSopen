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

**Se tem `pendingRegistration`:** retomar AUTO-CADASTRO pelo `state`.

**Se nenhum dos dois:** perguntar se ja usa, recebeu convite, quer criar ou conhecer.
- Ja usa → "Gera codigo em Configuracoes > WhatsApp e manda aqui"
- Recebeu convite → "Manda o codigo"
- Quer criar → iniciar AUTO-CADASTRO
- Quer conhecer → sugerir https://praticos.web.app OU compartilhar o contato do bot no WhatsApp
- Quer indicar pra colega → orientar a compartilhar o contato do bot (ver INDICAÇÃO abaixo)

**Regra:** msgs CURTAS, 1-2 frases. Tom casual.

---

## INDICAÇÃO / REFERRAL

Quando o usuario quer indicar o PraticOS pra um colega, SEMPRE enviar uma msg formatada pronta pra encaminhar:

```
message(action="send", message="Conheça o *PraticOS* — gestão de O.S. direto no celular!\n\n📱 Chama no WhatsApp: https://wa.me/554888794742\n🌐 Ou acesse: https://praticos.web.app\n\nÉ só mandar um oi que eu ajudo a criar sua conta na hora!")
```

Depois, orientar o usuario:
"Encaminha essa mensagem pro seu colega! Se quiser, compartilha meu contato também (toca no meu nome > Encaminhar Contato)"

**Regras:**
- SEMPRE enviar a msg formatada via message() — ela é o "cartão de visita" encaminhável
- Depois sugerir compartilhar o contato do bot como complemento
- Tom casual, máx 2 msgs (o cartão + a orientação)

---

## AUTO-CADASTRO

**Regra:** msgs curtas, max 2 frases + lista. Variar tom.

Todas as chamadas abaixo usam os mesmos headers: -H "X-API-Key: $PRATICOS_API_KEY" -H "X-WhatsApp-Number: {NUMERO}"

1. POST /bot/registration/start `{"locale":"pt-BR"}` → perguntar nome da empresa
2. POST /bot/registration/update `{"companyName":"NOME"}` → mostrar segmentos
3. POST /bot/registration/update `{"segmentId":"ID"}` → mostrar especialidades (se houver, senao pular p/ 5)
4. POST /bot/registration/update `{"subspecialties":["id1","id2"]}`
5. POST /bot/registration/update `{"includeBootstrap":true}` → perguntar se quer dados exemplo
6. Mostrar resumo curto e confirmar
7. POST /bot/registration/complete → "Pronto! Quer criar sua primeira OS?" (→ proativo: sugerir criar 1a OS)

Cancelar: DELETE /bot/registration
