# Checklist: a IA lê a foto e escreve a observação

Data: 2026-11-10. Status: direção aprovada pelo Rafael, implementação não começou.
Base: `2026-10-10-checklists-design.md` (uma pergunta por vez, "Falar as respostas"), `docs/AI_ORDER_ASSIST.md` (IA da OS, cota, chave de ligar), `docs/DEVICE_READING.md` (quilometragem e horímetro), `docs/formularios_dinamicos.md`.
Issues relacionadas: #390 (Falar as respostas), #646 (pergunta ligada à leitura do equipamento).

## 1. Problema

No checklist a pessoa tira a foto e depois digita o que a foto já mostra: o km do painel, o risco na porta, o número de série da etiqueta. É trabalho dobrado no balcão, e por isso a descrição do dano quase nunca é escrita. Sem a descrição, a vistoria de entrada não protege a oficina ("o risco já estava lá").

## 2. Objetivo

A pessoa tira a foto e a IA, sabendo qual é a pergunta, faz duas coisas:

1. **Responde a pergunta** quando a foto mostra a resposta.
2. **Escreve a observação**: o que viu e onde ("Amassado na porta traseira esquerda, perto da maçaneta").

A pessoa pode corrigir tudo. O texto final é dela.

| Pergunta | Foto | A IA preenche |
|---|---|---|
| Quilometragem (número) | Painel | `98.000` + leitura do veículo (ver §6) |
| Nível de combustível (opções) | Painel | "1/4" |
| Lataria (Sim/Não ou opções) | Lateral do carro | "Com avaria" + observação "Amassado na porta traseira esquerda, perto da maçaneta" |
| Onde tem dano? (várias) | Volta no carro | ✓ Porta "amassado perto da maçaneta", ✓ Para-choque "risco de uns 10 cm" |
| Número de série (texto) | Etiqueta | `SN 4C2X91…` |
| Tela (opções) | Celular | "Trincada" + "Trinca no canto superior direito" |
| Placa de identificação (texto) | Ar-condicionado | "Modelo X, 12.000 BTU, gás R-410A" |
| Contador de páginas (número) | Visor da impressora | `48.213` |

### Fora desta fase

- Descrever o dano desenhado sobre a foto (caixa ou seta).
- Várias fotos de uma vez espalhadas pelas perguntas.
- Comparar a entrada com a saída ("nenhum dano novo").
- Resumo da entrada para o cliente e sugestão de serviço a partir do dano.
- Falar as respostas (#390). Usa a mesma rota, mas fica na issue dela.

## 3. Observação: onde fica

Três níveis, todos opcionais e todos editáveis:

| Nível | Quando aparece | Exemplo |
|---|---|---|
| **Da pergunta** | Em toda pergunta | "Lataria: amassado na porta traseira esquerda" |
| **Da opção marcada** | Só em pergunta de várias escolhas (`checklist`) | "Porta ✓ amassado perto da maçaneta" |
| **Da foto** | Em toda foto | Embaixo da foto no PDF e no link: "Risco no para-lama dianteiro" |

Na pergunta Sim/Não e na de uma opção, a observação da pergunta basta, sem observação por opção.

### Regras

1. A IA preenche e marca com ✦ azul (regra do design system). Quando a pessoa edita o texto, o ✦ some e o texto passa a ser dela.
2. **A IA nunca reescreve texto editado pela pessoa.** Numa foto nova, se a pessoa já escreveu, a IA só sugere no aviso: "A IA viu também: risco no para-lama. Acrescentar?"
3. A resposta da pergunta segue a mesma regra: a IA só preenche se a pergunta está sem resposta. Se já tem resposta e a foto diz outra coisa, ela avisa e não troca.
4. Sem IA, o campo funciona do mesmo jeito: "+ Observação" como link embaixo da resposta. Serve para quem não usa a IA, para quem está sem internet e para pergunta sem foto.
5. A observação vai para o PDF, o web e o link do cliente. A observação é escrita para o cliente ler: é ela que protege a oficina.

## 4. Telas (app)

Na sheet de uma pergunta por vez (`lib/screens/forms/form_question_sheet.dart`):

- Depois da foto, a sheet **já passa para a próxima pergunta** se a pergunta for só de foto, como hoje. A IA lê em segundo plano.
- Enquanto lê, a foto ganha "✦ Lendo a foto…" em `textSecondary`.
- Quando a IA responde, aparece o aviso opaco de sempre: "✦ Preenchi: 98.000 km · Desfazer". Se a pessoa já estiver em outra pergunta, o aviso diz qual: "✦ Lataria: com avaria · Ver".
- Embaixo da resposta fica a linha **"Observação"** com o texto e o ✦. Ao tocar, abre um campo de texto com o teclado (sheet pequena, "Pronto" no teclado).
- Foto ruim (escura, tremida, sem o painel): o aviso diz "Foto escura, não deu para ler. Tirar de novo" com o botão. Não preenche nada.
- Erro de rede ou cota: o aviso diz "Não deu para ler a foto agora", e o resto continua como sem IA. Nunca alerta.
- A lista do checklist e o resumo na OS mostram a observação embaixo da resposta, em `textTertiary`.

A IA só roda com a IA ligada para a empresa (`GET /v1/app/ai/status`, como na OS). Desligada, nada aparece além do "+ Observação".

## 5. Dados

### Observações fora da lista de respostas

As observações ficam num campo novo do checklist, `notes`, e **não** dentro de `responses`:

```json
// companies/{companyId}/orders/{orderId}/forms/{instanceId}
{
  "responses": [{ "itemId": "fuel", "value": "1/4", "photoUrls": ["…"] }],
  "notes": {
    "body": {
      "text": "Amassado na porta traseira esquerda, perto da maçaneta",
      "ai": true,
      "options": [{ "option": "Porta", "text": "amassado perto da maçaneta", "ai": true }],
      "photos": [{ "url": "https://…/1.jpg", "text": "Amassado na porta traseira", "ai": false }]
    }
  },
  "aiFilled": ["fuel"]
}
```

Por que fora:

- O app em produção (1.56), o app web (`firebase/webapp/src/lib/forms/data.ts:245`) e o app atual regravam `responses` só com `itemId`, `value` e `photoUrls`. Dentro de `responses`, a observação seria apagada na próxima resposta salva por qualquer um deles.
- O app atual salva com `arrayRemove` + `arrayUnion` do objeto exato (`lib/services/forms_service.dart:184`). Um campo a mais no objeto faria a remoção falhar e duplicaria a resposta.
- Todos gravam com `update` de campos fixos, então um campo novo no documento passa intacto pelos apps antigos.

Chaves:

- `notes` é um mapa por `itemId`.
- A observação de opção usa como chave o **valor gravado da opção** (`options[i]` original, não o texto traduzido), o mesmo que já vai em `value` (`form_question_sheet.dart:496`). Como o checklist da OS guarda uma cópia das perguntas (`OrderForm.items`), a chave não muda se o modelo for editado ou traduzido depois.
- A observação de foto usa a URL, a mesma de `photoUrls`. Foto apagada leva a observação junto.
- `ai: true` enquanto o texto é o da IA. A primeira edição da pessoa grava `ai: false`.
- `aiFilled` lista as perguntas cuja **resposta** veio da IA e não foi mexida, para mostrar o ✦ na resposta. Responder de novo tira o item da lista.

### Modelos

- Dart: `OrderForm.notes` (`Map<String, FormItemNote>`), `FormItemNote { text, ai, options, photos }`, `OrderForm.aiFilled`. `build_runner` depois.
- TypeScript (`firebase/functions/src/models/types.ts`) e web (`firebase/webapp/src/lib/forms/model.ts`): os mesmos tipos, só leitura nesta fase. O web passa a editar na etapa 5.
- Gravação: transação que muda só `notes.{itemId}` (e `aiFilled`), separada da gravação da resposta. Um resultado da IA que chega depois de a pessoa ter escrito relê o documento e respeita a regra 2.

## 6. Leitura do equipamento (#646)

Quando a pergunta é numérica e o ramo tem leitura (`reading: true`, ver `docs/DEVICE_READING.md`), a pergunta pode ser ligada à leitura: `FormItemDefinition.reading: true` no modelo do ramo.

- Respondida (pela IA ou à mão), a mesma gravação preenche a leitura do equipamento da OS. A OS deixa de mostrar "+ Quilometragem" e não pergunta duas vezes.
- Se a leitura do equipamento já existe nesta OS, a pergunta já vem respondida com ela.
- Km menor que o da última visita: o aviso diz "Menor que os 102.000 km da última visita. Está certo?" e não trava.

## 7. Function

Rota nova `POST /v1/app/ai/form-photo` no `api`, ao lado de `order-assist` (`src/routes/v1/ai.routes.ts`), com o mesmo bearer, `resolveCompanyContext`, `write:orders`, chave de ligar e cota.

Entrada:

```ts
{
  photo: { mimeType, data },            // uma foto, JPEG ≤ 2 MB, a mesma já reduzida para o upload
  question: { label, type, options? },   // o rótulo traduzido e as opções originais
  device?: { category, name },           // "Veículo", "Fiat Uno 2015": ajuda a ler o painel certo
  segment, locale,
  lastReading?: { value, unit }          // só se a pergunta for de leitura
}
```

Saída (structured output, mesmo `LlmRouter` da OS):

```ts
{
  answer?: string | number | boolean | string[],  // sempre dentro de `options` quando houver
  note?: string,                                  // observação da pergunta, uma frase
  optionNotes?: { option: string; text: string }[],
  photoNote?: string,
  photoIssue?: 'dark' | 'blurry' | 'off_target',
  confident: boolean                              // false: não preenche `answer`, só a observação
}
```

- A Function não grava nada. O app aplica e salva (mesmo modelo da OS).
- Resposta fora das opções é descartada no servidor.
- **Cota:** cada foto lida conta 1, como na OS. Ver a pergunta aberta na §10.
- **Privacidade:** não vai nome de cliente, telefone nem placa no pedido. O log só tem empresa, tipo da pergunta, código de erro e latência, nunca a imagem ou o texto (regra 11 do `AI_ORDER_ASSIST.md`).
- **Modelo:** o padrão da IA (Gemini no Vertex). O Claude como alternativa pela chave `provider`. Ler número de painel e etiqueta é o ponto a testar primeiro (§9).

## 8. Onde aparece

| Lugar | O que muda |
|---|---|
| Sheet da pergunta (app) | Linha "Observação", ✦, aviso com Desfazer |
| Lista do checklist e resumo na OS (app) | Observação embaixo da resposta |
| PDF (`lib/services/pdf/pdf_service.dart`, `firebase/webapp/src/lib/pdf/load.ts`) | Observação embaixo da resposta e da foto |
| Link do cliente (`src/routes/public/orders.routes.ts`) | Observação junto com a resposta (o resumo já existe desde #373) |
| App web | Mostra na etapa 1, edita na etapa 5 |
| Bot | Nada (desligado) |

## 9. Ordem de implementação

| # | Etapa | Onde | Risco |
|---|---|---|---|
| 1 | Campo `notes` e "+ Observação" sem IA: app, PDF, web (só leitura) e link do cliente, com testes | modelos, `forms_service.dart`, sheet, PDF, `orders.routes.ts` | `risk:high` (modelo compartilhado, API pública) |
| 2 | Teste de leitura: 30 fotos reais sem dado de cliente (painel, lataria, etiqueta, visor), medir acerto do km e da observação no Gemini e no Claude. Fotos fora do repositório | script em `firebase/functions/scripts` | `risk:low` |
| 3 | Rota `form-photo` com testes (opção inválida, `confident: false`, cota, IA desligada) | `firebase/functions/src/services/ai/` | `risk:high` (Function de produção) |
| 4 | App chama a rota depois da foto, aplica com ✦ e Desfazer, respeita o texto da pessoa | `form_question_sheet.dart`, serviço novo `ai_form_photo_service.dart` | `risk:low` |
| 5 | Pergunta ligada à leitura do equipamento (#646) e edição da observação no web | modelo do ramo, `seed_forms.js`, webapp | `risk:high` (seed) |

A etapa 2 decide se seguimos: se o km sair errado com frequência, a leitura de número fica de fora e só a observação vai adiante.

Documentação: atualizar `docs/formularios_dinamicos.md` e `docs/AI_ORDER_ASSIST.md` (rota nova), e a página pública de checklists se existir, junto com a etapa 4.

## 10. Perguntas abertas

- **Cota:** contar 1 por foto, como na OS, ou 1 por checklist? Uma volta no carro pode ter 6 fotos.
- **Analytics:** acrescentar `via: 'ai_photo'` ao `checklist_answered` e um evento `checklist_ai_undone`, para saber quanto a pessoa desfaz.
