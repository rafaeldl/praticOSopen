# Nota fiscal de serviço direto no governo (NFS-e nacional)

Data: 2026-11-05. Status: proposta, aguardando aprovação.
Base: [`NFSE_DIRECT_DISCOVERY.md`](../../NFSE_DIRECT_DISCOVERY.md) (regras, spike em produção, APIs, guarda do certificado), [`NFSE_ASAAS.md`](../../NFSE_ASAAS.md) (o que já existe e é reaproveitado).

## 1. Problema

Dono de oficina emite a nota de cada OS à mão no portal do governo. A oficina piloto emite cerca de 30 por mês assim, e cancela 7% delas por erro de digitação. Ela faz isso por uma empresa do Simples e por vários MEIs, cada um com o seu certificado. A nota pelo Asaas está pronta, mas exige uma conta Asaas por CNPJ, e o PraticOS só aceita uma conexão por empresa.

Desde 01/11/2026, MEI e Simples emitem obrigatoriamente pelo Emissor Nacional, e o spike provou que o PraticOS consegue emitir e cancelar uma nota real por lá com o A1 do próprio prestador.

## 2. Objetivo

Com um toque na OS, sai a nota certa, pelo CNPJ certo, para o cliente certo, sem digitar nada que o sistema já sabe. Subir o certificado uma vez configura quase tudo sozinho.

### Fora desta entrega (anotado para depois)

| Item | Quando |
|---|---|
| **Notas recebidas → despesas (NFS-e)**: o servidor lê as notas emitidas contra o CNPJ (guincho, retífica, contador) e o Financeiro mostra "3 notas recebidas para lançar"; um toque vira despesa com fornecedor, valor e data. Nada vira despesa sozinho | Etapa posterior A. A primeira entrega já guarda o ponto de leitura (NSU) e um registro mínimo das recebidas (§5.6), para a etapa A começar sem reler tudo |
| **NF-e de peças recebidas (SEFAZ)**: exige manifestar a "ciência da operação" (registro oficial) e só cobre ~90 dias | Etapa posterior B, quando houver uma oficina que compra peças com nota e queira testar |
| "✦ Reescrever" a descrição com a IA no estilo das últimas notas | Se a regra fixa (§4.4) ficar longe do que o dono escreve |
| Emitir sozinha "quando receber" ou "quando aprovar"; regra por tipo de serviço | Se algum cliente pedir |
| Substituição de nota (evento de substituição) | Depois do piloto; hoje cancela e emite outra |
| Comparar o Simples com o teto (R$ 360 mil / R$ 4,8 mi) | Depois da etapa B: sem as notas de peças a soma engana |
| Tirar o código da nota pelo Asaas | Quando ficar claro que ninguém vai ligar |

## 3. Decisões

| # | Decisão | Escolha | Por quê |
|---|---|---|---|
| 1 | Motor | **O direto substitui o Asaas na nota fiscal.** Telas e `invoices` continuam; nota nova leva `provider: 'direct'`. A nota pelo Asaas fica desligada e sai depois. A cobrança pelo Asaas não muda | Dois motores dobram teste e suporte; o Asaas não atende vários CNPJs e cobra por nota; a nota dele nunca foi ligada em produção |
| 2 | Guarda do certificado | Proposta do discovery, com **uma chave do Cloud KMS por emitente** (§6) | Apagar um certificado não pode depender do backup expirar nem afetar os outros |
| 3 | Emitente marcado na folha | O **último usado para aquele cliente**; sem histórico, o **padrão da empresa** | Aprende com o uso, nada para configurar. Nunca sugere emitente pelo teto do MEI |
| 4 | Faturamento por emitente | Todos mostram "Notas este ano · este mês". Só o MEI compara com o teto e avisa | No Simples, sem as notas de peças a comparação daria falsa segurança |
| 5 | Quem recebe a nota | Dados da nota **no próprio cliente**; **CNPJ único** na empresa; campo opcional **"Nota fiscal para"** aponta outro cliente | Na piloto, 1 CNPJ recebeu notas de 4 lojas e nenhuma loja usou 2 CNPJs. Cada filial é um cliente |
| 6 | Importação | **Tela de resumo + "Importar"**, com casamentos duvidosos confirmados e "Desfazer" por 30 dias | Mexe em dezenas de clientes de uma vez: aplicar sem tela é arriscado |
| 7 | Notas antigas × OS | Ligar só as que casam com segurança; ligar e desligar à mão no detalhe da nota | Evita nota em dobro e lembrete cheio de OS que já têm nota |
| 8 | Descrição | **Regra fixa** dos serviços, estilo aprendido por emitente, campo aberto na folha. Sem IA na primeira versão | Previsível, sem cota de IA. Quase ninguém deve precisar editar |
| 9 | Informações complementares | Sempre "OS 182 · Emitida pelo PraticOS (praticos.app)" | A revenda acha a OS; o app aparece em cada nota |
| 10 | Emissão automática | "Emitir sozinha quando concluir a OS": **Nunca** (padrão) / **Para os clientes escolhidos** / **Para todas as OS** | Começa desligada; cada dono escolhe o alcance; o interruptor do cliente resolve as exceções |
| 11 | Como o certificado chega | iPhone (Arquivos), app web e **"Pedir ao contador"** (link de uso único) | O A1 costuma estar com o contador |
| 12 | Permissões | Certificado: **dono e admin** (por enquanto). Emitir: dono, admin, gerente | Igual à nota pelo Asaas, mais o certificado |
| 13 | Planos | Free: sem nota. **Starter: notas ilimitadas, 1 CNPJ. Pro e Business: CNPJs ilimitados** | Nota sem custo por unidade; vários CNPJs puxam para o Pro. Revê a tabela de 02/11, que punha a nota no Pro |

## 4. Como funciona para quem usa

Telas seguem `docs/APP_DESIGN_SYSTEM.md`: uma pergunta por tela, um botão azul, escolher é tela (`PickerScaffold`), cadastro novo em sheet grande com "X" e "✓", sem botão "Editar".

### 4.1 Configuração da nota

A atual `NfseSetupScreen` vira (Financeiro → Notas fiscais → "…" → "Configurar nota fiscal", e o "…" da OS quando ainda não há emitente):

- **Frase no topo**: "Notas saem pelo CNPJ que você escolher na hora" ou, sem emitente, "Envie o certificado digital para emitir notas".
- **Seus CNPJs**: uma linha por emitente (razão social · "Simples" ou "MEI" · "Certificado vence em 03/2027"), ✓ no padrão. "+" no topo → Adicionar CNPJ. No Starter, o segundo "+" abre a tela do plano: "Para emitir por mais de um CNPJ, passe para o Pro".
- **Emitir sozinha quando concluir a OS**: linha que abre a tela de escolher com Nunca / Para os clientes escolhidos / Para todas as OS. Em "clientes escolhidos", a tela tem o link "Ligar para todos os clientes com CNPJ" (liga o interruptor em cada um; cliente novo não liga sozinho).

### 4.2 Adicionar CNPJ e enviar o certificado

Sheet grande. Título: "Como você quer enviar o certificado?"

1. **Escolher o arquivo** (.pfx/.p12, de Arquivos no iPhone ou arrastado no web) + campo da senha + texto do termo ("O PraticOS usa o certificado só para emitir e ler as suas notas. Você pode apagar quando quiser." com link para o termo). ✓ fica azul com arquivo e senha.
2. **Pedir ao contador**: gera o link de uso único (48 h) e abre a folha de compartilhar do iPhone com a mensagem pronta para o WhatsApp (§6.3).

Depois do envio, o servidor confere o certificado (CNPJ, validade, ICP-Brasil), busca na Receita e no cadastro nacional (razão social, regime, cidade, inscrição municipal, se está habilitado a emitir) e começa a importação. A tela mostra "Lendo suas notas no governo…" e depois o resumo (§4.3). Erros em frase simples: senha errada, certificado vencido, não é ICP-Brasil, CNPJ já cadastrado em outro emitente, cidade fora do Emissor Nacional.

### 4.3 Resumo da importação

Tela empurrada, com o botão azul "Importar":

- **Frase**: "Achamos 167 notas para 18 clientes. Vamos preencher seus clientes e o serviço da nota."
- **Emitente**: razão social, regime, inscrição municipal, serviço mais usado (vira o padrão, com a alíquota da cidade), série que vamos usar.
- **Clientes**: "12 novos · 6 completam clientes que você já tem". Os casamentos certos (CNPJ igual, ou nome igual com OS de mesmo valor e data) vão sem perguntar.
- **Este é o mesmo cliente?**: lista curta dos duvidosos, cada um com "Sim" / "Não, criar outro". Sem resposta, vira cliente novo.
- **Lojas que faturam em outro CNPJ**: quando várias lojas casam com o mesmo CNPJ, o CNPJ fica no cliente mais usado e as outras ganham "Nota fiscal para" apontando para ele.
- **Emitir sozinha**: "Estes 4 clientes tiveram nota em quase todas as OS. Ligar a nota sozinha para eles?" (nada vem ligado).
- **Notas**: "111 ligadas às suas OS · 56 só no histórico".

Regras: só preenche o que está vazio, nunca troca o que a pessoa digitou. "Desfazer importação" fica no "…" do emitente por 30 dias: apaga os clientes criados (os que ainda não têm OS), esvazia os campos preenchidos, desfaz os "Nota fiscal para" e desliga as notas das OS. As notas antigas continuam no histórico.

### 4.4 Descrição e informações complementares

- **Regra fixa**: cada serviço vira o nome do catálogo + o detalhe, sem repetir palavra que já está no nome ("Conserto/Pintura de Capô" + "Capo" → "Conserto/Pintura de Capô"); serviços juntados pelo separador do emitente. Várias OS: uma linha por OS.
- **Estilo por emitente** (`descriptionStyle`): maiúsculas ou não e separador, aprendidos na importação (a piloto: maiúsculas e " - "); muda no emitente.
- **Folha**: o texto vem pronto num campo aberto; mudar ali vale só para aquela nota.
- **Informações complementares** (`xInfComp`), sempre, sem opção de desligar: "OS 182 · Emitida pelo PraticOS (praticos.app)" ("OS 182, 190" com várias).

### 4.5 Cliente: dados para nota

Grupo "Dados para nota" no cliente (só quando a empresa tem nota direta ligada):

- **CPF/CNPJ** (`taxId`, já existe). Digitado um CNPJ, o app busca na Receita e preenche razão social e endereço (confere antes de salvar).
- **Razão social**, **endereço com CEP** (estruturado: CEP, rua, número, complemento, bairro, cidade, UF; o CEP preenche rua/bairro/cidade) e **e-mail da nota** (o e-mail do cliente, se vazio).
- **CNPJ único na empresa**: salvar um CNPJ que outro cliente já tem é bloqueado com "A REVENDA EXEMPLO LTDA já tem este CNPJ" e a ação "Mandar as notas desta loja para ela", que preenche o "Nota fiscal para". CPF segue a mesma regra.
- **Nota fiscal para** (opcional): linha que só aparece quando preenchida; adicionar pelo "…" do cliente ("Mandar a nota para outro cliente"), que abre a tela de escolher clientes. Sem ela, a nota vai para o próprio cliente.
- **Emitir nota sozinha** (interruptor do sistema): aparece quando a configuração é "clientes escolhidos" (vem desligado) ou "todas as OS" (vem ligado e serve para tirar o cliente da regra). Vale para a loja, porque é a OS dela que é concluída.
- **Oferta na 3ª nota**: na terceira nota emitida à mão para o mesmo cliente, em "clientes escolhidos" ou "Nunca", aviso opaco uma vez só: "Quer que as notas da REVENDA EXEMPLO saiam sozinhas quando concluir a OS?" com "Sim". Em "Nunca", o "Sim" também muda a configuração para "clientes escolhidos".

### 4.6 Emitir a nota

OS: mesmos pontos de hoje (`order_screen_v2.dart`): botão azul "Emitir nota fiscal" na OS concluída e paga, link "Emitir" na linha "Nota fiscal", "…" → "Emitir nota fiscal" nos outros casos (OS com serviço, fora de orçamento/cancelada, sem nota ativa). No Free, abre a tela do plano.

Folha de emissão (`NfseIssueSheet`), de cima para baixo:

- **Emitir por**: emitente marcado pela decisão 3; toque abre a tela de escolher (só com mais de um emitente). No Starter com mais de um emitente (plano baixou), só o padrão emite; os outros aparecem com "Disponível no Pro".
- **Para**: "REVENDA EXEMPLO LTDA · CNPJ 00.000.000/0001-00" (o "Nota fiscal para" do cliente, ou o próprio cliente). Toque troca só nesta nota: outro cliente ou digitar um CNPJ. Faltando documento, endereço ou e-mail, os campos aparecem ali para completar (gravam no cliente, só onde está vazio, como hoje).
- **Valor**: regra de hoje (`invoiceValueOfOrder`: serviços − parte do desconto), com serviços, peças fora da nota e desconto.
- **Descrição**: campo aberto (§4.4).
- **Aviso do MEI** (sem bloquear): "Com esta nota, o MEI passa de 80% do teto do ano" / "Com esta nota, o MEI passa do teto do ano. Fale com o seu contador."
- ✓ emite. A resposta do governo vem na hora (~0,5 s): a nota abre já "Emitida · nº 29" ou com o motivo da recusa em frase simples e o que abrir para corrigir.

### 4.7 Notas, detalhe e emitente

- **Lista de notas** (`NfseListScreen`): igual, mais a etiqueta "Emitida fora do PraticOS" nas importadas e nas feitas no portal, e o filtro por emitente quando há mais de um. "Precisa de atenção" junta também as automáticas que não saíram por falta de dado.
- **Detalhe** (`NfseInvoiceScreen`): emitente, destinatário, PDF (gerado por nós, §5.5) e XML. Nota sem OS: linha "OS · Ligar a uma OS" (tela de escolher com as OS do mesmo cliente, as de valor e data parecidos primeiro); se a OS já tem nota ativa, avisa e não liga. "…" → "Desligar da OS" e "Cancelar nota" (vermelho, com o motivo: "Erro na nota" ou "Serviço não prestado"). Nota importada também pode ser cancelada pelo PraticOS (mesmo certificado), se a cidade ainda aceitar.
- **Emitente** (tela empurrada a partir de "Seus CNPJs"): razão social, CNPJ, regime; frase "Notas este ano: R$ 214 mil · este mês: R$ 31 mil" e, no MEI, "Faturou R$ 52 mil de R$ 81 mil este ano (pelas notas)"; linhas que abrem o seu editor: serviço da nota, inscrição municipal, estilo da descrição, certificado ("Vence em 12/03/2027 · enviado por Fulano em 05/11/2026"). "…": Usar como padrão, Trocar certificado, Desfazer importação (30 dias), Apagar CNPJ (vermelho, confirma: apaga o certificado; as notas ficam).
- **Avisos de vencimento**: 30 e 7 dias antes, no sino e por push, para dono e admin: "O certificado da OFICINA EXEMPLO vence em 7 dias. Peça um novo ao contador." com o atalho "Pedir ao contador". Vencido: o emitente mostra "Certificado vencido" em vermelho e a folha não emite por ele.

### 4.8 App web

Mesmas rotas. Entram: lista e detalhe com emitente, folha com "Emitir por" e "Para", envio do certificado arrastando o arquivo, e a página pública do contador. A configuração dos emitentes e a importação ficam no app e no web.

## 5. Servidor

### 5.1 Onde roda

Uma Function nova, `nfseApi` (HTTP, Node 22, região de São Paulo), com **conta de serviço própria**, a única com `cloudkms.cryptoKeyDecrypter` nas chaves `nfse-certs/*`. Ela serve `/v1/app/nfse/*` para `provider: 'direct'` e faz tudo que usa o certificado: envio, emissão, cancelamento, importação, leitura periódica. O gatilho da OS (`onOrderUpdated…`) não decifra: quando a OS pede nota automática, ele grava um pedido e a `nfseApi` (Cloud Task) emite. A rotina diária (vencimentos, sincronização com o governo) chama a mesma função.

### 5.2 Montar, assinar e enviar a DPS

- **Leiaute por ambiente**: produção usa o pacote 20260209 (sem `finNFSe`), testes o 20261020. Um módulo por pacote (`layouts/v20260209`, `layouts/v20261020`, depois `v2027`), escolhido por configuração do servidor (`config/nfse.layoutByEnvironment`), para trocar sem soltar app.
- **Por regime**: Simples `opSimpNac=3` + `regApTribSN`, `tribFed` (PIS/COFINS), `pTotTribSN`; MEI `opSimpNac=2`, sem `regApTribSN` nem `tribFed`, `indTotTrib=0`.
- **Campos que aprendemos no spike**: `dhEmi` em Brasília com recuo de 5 s (E0008); inscrição municipal só se o cadastro nacional tiver (E0116 × E0120); código de serviço da lista da cidade na data (E0312); `verAplic` até 20 caracteres ("PraticOS-{versão}").
- **Assinatura**: XMLDSig enveloped, RSA-SHA1, C14N (`xml-crypto`), igual ao spike.
- **mTLS**: chave + cadeia em PEM no `https.Agent`. O PFX "legacy" é aberto com `node-forge` só no envio do certificado; o que fica guardado já é PEM.
- **Envio**: `POST {sefin}/nfse` com a DPS em GZip + Base64. Autorizada: grava chave de acesso, número (`nNFSe`), XML no Storage (`tenants/{cid}/invoices/{id}/nfse.xml`) e gera o PDF.
- **Testes automáticos**: montagem validada contra os XSD oficiais (cópia sem as âncoras `^…$` para o `xmllint`), assinatura conferida, respostas do governo gravadas como fixtures. Nunca enviar ao governo nos testes.

### 5.3 Numeração e idempotência

- **Dois números**: o **número da nota** (`nNFSe`, o que aparece no PDF) é do governo, sequencial por CNPJ, e continua sozinho de onde o cliente parou (portal, Asaas ou outro sistema). O **número da DPS** é o nosso pedido, com uma série; o governo recusa DPS repetida.
- **Série nossa por emitente** (`dpsSeries`): escolhida na importação entre as que o CNPJ **nunca usou**, olhando as notas antigas. Não continuar a série de outro emissor: se o dono ainda emitir pelo portal, os dois disputariam o mesmo número. Visto na piloto: o portal do governo usou as séries 900 (nas primeiras notas) e 70000; o Asaas usa a 1. Candidata padrão: 10, trocando se já tiver sido usada.
- **Número**: contador em `private/nfse/emitters/{emitterId}.nextDpsNumber`, reservado numa transação que também cria a nota `creating` com o `dpsId` (que é determinístico: cidade + CNPJ + série + número).
- **Sem resposta certa** (tempo esgotado, 5xx, rede): `GET /dps/{dpsId}`. Existe → busca a NFS-e e grava como emitida. Não existe → reenvia **a mesma DPS** (mesmo número), nunca pula nem repete número. Conferência automática das `creating` com mais de 3 minutos, como a do Asaas.
- **Recusa** (o governo respondeu com erro): a nota fica `error` com o código, e o número **não** é reaproveitado (é da DPS recusada; o número da NFS-e é do governo e não pula).

### 5.4 Recusas em frase simples

Tabela `refusalCode` nova, pelo código `E0xxx` do governo, com os grupos que a folha já sabe tratar:

| Grupo | Exemplos conhecidos | Na folha |
|---|---|---|
| Dados do cliente | documento, endereço, e-mail do tomador | Abre os campos do "Para" |
| Configuração do emitente | E0116/E0120 (inscrição municipal), E0312 (serviço fora da lista da cidade), E0119 (não habilitado na cidade), E0162/E0676 (regime) | "Configurar" abre o emitente |
| Certificado | E0718 (certificado de outro CNPJ), certificado vencido, mTLS recusado | "Trocar certificado" |
| Outro | qualquer código novo | "O governo recusou a nota: {texto}" |

O log grava código e texto do governo (até 200 caracteres), nunca o XML nem dados do cliente. A tabela cresce com o piloto.

### 5.5 Cancelamento e PDF

- **Cancelar**: evento `e101101` assinado, `POST /nfse/{chave}/eventos`, resposta na hora. Motivos na tela: "Erro na nota" e "Serviço não prestado". Prazo e regra de cancelamento são da cidade: recusa vira frase simples com "Cancele no portal do governo" quando for o caso.
- **PDF (DANFSe)**: a API do governo que gerava o PDF foi suspensa; o servidor gera a partir do XML, no leiaute oficial do DANFSe da documentação técnica (com o QR code de consulta), guarda no Storage e o detalhe abre e compartilha. Importadas: PDF gerado na primeira vez que alguém abre.

### 5.6 Leitura no governo (importação e sincronização)

- **No envio do certificado**: `GET {adn}/contribuintes/DFe/{NSU}?cnpjConsulta=&lote=true`, de 50 em 50, desde o começo. Emitidas pelo CNPJ viram `invoices` com `source: 'external'`; eventos de cancelamento atualizam a situação. O servidor monta a proposta (§4.3) em `nfseImports/{batchId}` e só aplica no "Importar".
- **Todo dia**: a mesma leitura a partir do último NSU (`private/nfse/emitters/{id}.lastNsu`) traz as notas feitas no portal ou em outro sistema, para o histórico e o faturamento do ano ficarem certos.
- **Recebidas**: na primeira entrega só se grava um registro mínimo, só no servidor (`private/nfse/emitters/{id}/received/{nsu}`: chave, CNPJ e nome do prestador, valor, data, situação), para a etapa posterior A.
- **Cadastro**: `GET {adn}/cnc/consulta/cad` (inscrição municipal, habilitado), `GET {adn}/parametrizacao/{ibge}/convenio` (cidade no Emissor Nacional), `GET .../historicoaliquotas` (ISS do serviço). CNPJ de emitente e de cliente: API pública de CNPJ (escolher na etapa 3; BrasilAPI é a candidata).

### 5.7 Faturamento do ano

O servidor mantém em cada emitente `totals { year, yearValue, month, monthValue }`, somando notas emitidas (de qualquer origem) menos canceladas, recalculado na emissão, no cancelamento e na sincronização diária. O teto do MEI fica em `config/nfse.meiAnnualLimit` (R$ 81.000 hoje). Os avisos da folha usam o total + o valor da nota.

### 5.8 Emissão automática

Gatilho único da OS: quando `status` vira `done` e `settings/nfse.autoIssue` é `selectedCustomers` (com o interruptor do cliente ligado) ou `allOrders` (sem o interruptor desligado), cria o pedido de emissão. Regras que já valem: uma vez por OS, nunca junta várias OS. Faltando dado (documento, endereço, e-mail, emitente com certificado vencido), grava `auto-{orderId}` com o `errorCode`, e a OS mostra "Nota fiscal · Falta o CPF do cliente", que abre a folha. Emitente: o da decisão 3.

### 5.9 IBS/CBS (2027)

A partir de 01/01/2027 o leiaute ganha os grupos de IBS/CBS. Entra como um módulo de leiaute novo (`v2027`), ligado por data e ambiente na configuração. Acompanhar as notas técnicas desde já: é a etapa com prazo duro do plano.

## 6. Guarda do certificado

Detalhe completo e o porquê de cada ponto em [`NFSE_DIRECT_DISCOVERY.md`, "Guarda do certificado e da senha"](../../NFSE_DIRECT_DISCOVERY.md#guarda-do-certificado-e-da-senha-proposta-para-o-desenho). Resumo do que vale:

1. **Senha e .pfx nunca são gravados.** O servidor abre o arquivo na memória, confere CNPJ, validade e cadeia ICP-Brasil, e guarda só a chave e o certificado em PEM, cifrados. A senha não aparece em log.
2. **Envelope com Cloud KMS, uma chave por emitente** (`nfse-certs/emitter-{emitterId}`): uma DEK AES-256-GCM por certificado, cifrada pela KEK do emitente, que nunca sai do KMS.
3. **Só a `nfseApi`**, com conta de serviço própria, decifra. O KMS registra cada decifração.
4. **Área privada da empresa** `companies/{cid}/private/nfse/certificates/{emitterId}`, coberta pela regra que já fecha `private/{doc=**}` (`if false`, só o servidor grava e lê): `ciphertext`, `iv`, `tag`, `wrappedDek`, `kmsKeyVersion`, `createdAt`. Obrigatório: **teste das regras provando que nenhum perfil da empresa (dono, admin, gerente, consultor, técnico) lê nem grava esse caminho**. Vantagem sobre uma coleção na raiz: o certificado sai junto quando a empresa é excluída. Decisão de 2026-11-05 (antes era `nfseCertificates/{emitterId}` na raiz). O emitente mostra só CNPJ, titular, validade e quem enviou quando.
5. **Na memória só durante a chamada**, sem cache.
6. **Dono e admin** enviam, trocam e apagam; ninguém baixa de volta. Cada ação vai para `private/nfse/audit` (quem, quando, aparelho, ação).
7. **Apagar de verdade**: apaga material e DEK, agenda a destruição da versão da chave com 24 h (`destroyScheduledDuration` = 1 dia, dá para desfazer nesse prazo); depois disso, as cópias em backup ficam ilegíveis. Vale para apagar o emitente, excluir a conta (`ACCOUNT_DELETION.md`) e certificado vencido há mais de 90 dias. Renovar cria versão nova e destrói a antiga.
8. **Termo** aceito no envio (gravado com a versão do termo), **avisos** 30 e 7 dias antes de vencer, **política de privacidade e LGPD** atualizadas antes do piloto.

Custo: ~US$ 0,06 por emitente por mês mais ~US$ 0,03 por 10 mil operações.

### 6.1 Página do contador

- O dono gera em "Pedir ao contador": token aleatório, só o hash fica em `nfseCertificateRequests/{hash}` (`companyId`, `emitterId?`, `requestedBy`, `expiresAt` = 48 h, `status`). Uso único.
- `praticos.app/certificado/{token}`: "Oficina Exemplo pediu o certificado para emitir notas pelo PraticOS", campo do arquivo e da senha, o mesmo termo. Envia direto para a `nfseApi`, que valida e guarda como **pendente**.
- O dono recebe aviso e vê "O contador enviou o certificado de OFICINA EXEMPLO … (CNPJ, vence em …)". Só com "Confirmar" o certificado vale e a importação roda. Sem confirmar em 7 dias, o pendente é apagado como no item 7.
- Proteções: limite de tentativas por token e por IP, senha errada não queima o token (3 tentativas), página sem nada da empresa além do nome, sem indexação.

## 7. Dados (Firestore)

| Caminho | Quem grava | Quem lê | O quê |
|---|---|---|---|
| `companies/{cid}/fiscalEmitters/{id}` | servidor | dono, admin, gerente | `taxId`, `legalName`, `tradeName`, `regime` (`mei` \| `simples`), `simplesOption` (`regApTribSN`), `cityCode`, `cityName`, `municipalRegistration`, `enabledInCity`, `service { nationalCode, municipalCode?, nbs?, name, issRate }`, `descriptionStyle { uppercase, separator }`, `dpsSeries`, `certificate { holderName, notAfter, uploadedAt, uploadedBy, status }`, `totals`, `importBatchId`, `createdAt` |
| `companies/{cid}/settings/nfse` | servidor | `canViewCharges` | + `provider` (`direct`), `defaultEmitterId`, `autoIssue` (`never` \| `selectedCustomers` \| `allOrders`); campos do Asaas ficam para notas antigas |
| `companies/{cid}/settings/payments.nfseDirectEnabled` | script/admin | quem lê pagamentos | flag do piloto |
| `companies/{cid}/invoices/{id}` | servidor | `canViewCharges` | + `provider`, `source` (`praticos` \| `external`), `emitter { id, taxId, legalName, regime }`, `recipient { customerId, taxId, legalName, address, email }`, `dps { id, series, number }`, `accessKey`, `xmlPath`, `pdfPath`, `cancelReason`, `importBatchId?` |
| `companies/{cid}/nfseImports/{batchId}` | servidor | dono, admin | proposta, respostas, o que foi aplicado (clientes criados, campos preenchidos, ligações) para o "Desfazer", `expiresAt` (30 dias) |
| `companies/{cid}/customers/{id}` | app e servidor | como hoje | + `legalName`, `fiscalAddress { postalCode, street, number, complement, district, cityCode, cityName, state }`, `invoiceEmail`, `invoiceRecipient` (`CustomerAggr`), `autoIssueInvoice`, `lastEmitterId` |
| `companies/{cid}/private/nfse/emitters/{id}` | servidor | ninguém | `nextDpsNumber`, `lastNsu`, `received/{nsu}` |
| `companies/{cid}/private/nfse/orders/{orderId}` | servidor | ninguém | trava de uma nota ativa por OS (já existe) |
| `companies/{cid}/private/nfse/audit/{id}` | servidor | ninguém (suporte pelo console) | ações no certificado |
| `companies/{cid}/private/nfse/certificates/{emitterId}` | servidor | ninguém (teste de regras obrigatório) | material cifrado (§6) |
| `nfseCertificateRequests/{hash}` | servidor | ninguém | link do contador |

CNPJ único por empresa: o app confere com `customers where taxId ==` antes de salvar, e a importação usa a mesma consulta. Corrida entre dois aparelhos é rara e aceitável; a importação junta o duplicado se achar.

Modelos novos no app seguem o padrão Full + Aggr (`FiscalEmitter`/`FiscalEmitterAggr`), com `build_runner`, i18n nos 3 idiomas e `FormatService` em valores e datas.

## 8. Regras de negócio

- Só serviços entram na nota; peças nunca. Valor: serviços − parte do desconto.
- Uma nota ativa por OS. Nota com erro ou cancelada libera a OS. Nota importada ligada a uma OS trava a OS como qualquer outra.
- Emitir exige emitente com certificado válido, cidade no Emissor Nacional e emitente habilitado no cadastro nacional.
- CNPJ do certificado tem de ser o do emitente; um CNPJ só pode ser emitente uma vez por empresa.
- Destinatário: "Nota fiscal para" do cliente, senão o próprio cliente; precisa de CPF/CNPJ; endereço e e-mail quando a cidade exigir (a recusa abre os campos).
- MEI: aviso a 80% e 100% do teto, nunca bloqueia e nunca sugere outro emitente.
- Emissão automática só ao concluir a OS, uma vez por OS, nos modos escolhidos.
- Número da DPS nunca pula nem repete; repetir o envio usa a mesma DPS.
- Agente nunca emite nota real. Teste em produção só pelo Rafael, com nota de valor baixo cancelada em seguida.

## 9. Plano em etapas

Ordem pensada para chegar ao piloto o quanto antes: primeiro emitir à mão pela empresa de teste do Rafael, depois a importação e o resto para a oficina piloto. Cada etapa é uma issue (ou um PR com várias, quando pequenas).

| # | Etapa | Entrega | Risco |
|---|---|---|---|
| 0 | Revisão de segurança do desenho | Revisão da §6 e da §6.1 por alguém de fora do código (ameaças, IAM, LGPD, termo); ajustes nesta spec | `risk:high` · `needs-human` |
| 1 | Cofre do certificado | KMS (keyring `nfse-certs`, chave por emitente), conta de serviço da `nfseApi`, certificado em `private/nfse/certificates` com teste de regras de que nenhum membro lê, envio/validação/troca/apagar com crypto-shred, auditoria, testes | `risk:high` |
| 2 | Modelo e regras | `fiscalEmitters`, campos novos de `invoices`, `customers` e `settings/nfse`, `nfseImports`; regras do Firestore e índices; modelos no app (`FiscalEmitter`) | `risk:high` |
| 3 | Motor de emissão | DPS por leiaute e regime, assinatura, mTLS, emitir, numeração, idempotência e conferência, cancelar, tabela de recusas, faturamento do ano, consultas de cadastro e CNPJ; testes com XSD e fixtures | `risk:high` |
| 4 | PDF da nota | DANFSe a partir do XML, no Storage, com QR code | `risk:high` (Function com escrita) |
| 5 | Telas: configuração e emitente | Configuração da nota, Adicionar CNPJ com envio do arquivo (app e web), tela do emitente, avisos de vencimento | `risk:low` (UI; o servidor vem das etapas 1–3) |
| 6 | Telas: emitir | Folha com "Emitir por", "Para", descrição aberta, aviso do MEI; OS, lista, detalhe e web adaptados ao `provider: 'direct'` | `risk:low` |
| 7 | Piloto 1: empresa de teste do Rafael | Liga `nfseDirectEnabled`; o Rafael emite e cancela uma nota de valor baixo pelo app | `needs-human` |
| 8 | Cliente: dados para nota | Grupo "Dados para nota", busca do CNPJ e do CEP, CNPJ único, "Nota fiscal para" | `risk:low` (UI) + parte do modelo na etapa 2 |
| 9 | Importação | Leitura do ADN, proposta, tela de resumo, aplicar, desfazer, ligar às OS, "Ligar a uma OS" à mão, sincronização diária e registro das recebidas | `risk:high` (escreve em clientes em lote) |
| 10 | Pedir ao contador | Link de uso único, página pública, pendente + confirmar, limites | `risk:high` |
| 11 | Emissão automática nova | Modos, interruptor do cliente, oferta na 3ª nota, pedido pela Cloud Task | `risk:high` (gatilho com escrita) |
| 12 | Termos, privacidade e docs | Termo do certificado, política de privacidade/LGPD, `docs/NFSE_DIRECT.md`, artigo público em pt/en/es | `risk:low` (o texto do termo pede leitura do Rafael) |
| 13 | Piloto 2: oficina piloto | Contador envia os certificados pelo link, importação revisada com o dono, primeiras notas reais acompanhadas | `needs-human` |
| 14 | Planos | Free sem nota, Starter 1 CNPJ, Pro+ ilimitados, tela do plano nos pontos da §4 | `risk:high` (billing) |
| 15 | Leiaute 2027 (IBS/CBS) | Módulo `v2027` testado no ambiente de testes antes de 01/01/2027 | `risk:high` · prazo duro |
| 16 | Tirar a nota pelo Asaas | Remove o motor do Asaas da nota (a cobrança fica) | `risk:low` |

Dependências: 0 antes de ligar para qualquer cliente de fora (etapa 13); 1 e 2 antes de 3; 3 antes de 4, 5, 6, 9, 10 e 11; 8 antes de 9 (a importação preenche os campos novos); 12 antes de 13; 14 antes de abrir para todos. 15 corre em paralelo a partir de agora.

Etapas posteriores (fora desta lista): A, notas recebidas → despesas; B, NF-e de peças (§2).

## 10. Riscos

- **Certificado vazado**: o maior. Mitigado pela §6 e pela revisão da etapa 0; ainda assim o PraticOS passa a guardar algo que abre o e-CAC dos clientes.
- **Prazo de 2027**: o leiaute com IBS/CBS sai em minuta e muda; sem a etapa 15 pronta, a emissão para em janeiro.
- **Documentação em minuta e ambiente de testes desatualizado**: o piloto valida em produção, com nota real cancelada.
- **Suporte fiscal**: recusas por regra da cidade chegam ao nosso suporte; a tabela de recusas e o "Configurar" reduzem, não eliminam.
- **Vários MEIs no mesmo negócio**: o produto apoia emitir por vários CNPJs, mas não sugere qual usar para fugir de teto; o enquadramento é do contador.
- **CNPJ único sem trava no banco**: dois aparelhos podem gravar o mesmo CNPJ ao mesmo tempo; raro, e a importação junta.
