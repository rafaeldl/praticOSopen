# Sequências de Email — PraticOS

**Criado por:** Head of Growth
**Data:** 2026-04-03
**Versão:** 1.0

---

## Visão Geral

13 emails organizados em 4 sequências:

| Sequência | Emails | Objetivo |
|-----------|--------|----------|
| Onboarding | 5 | Ativar novo usuário, mostrar valor |
| Re-engajamento | 2 | Trazer de volta usuário inativo |
| Upgrade | 2 | Converter Free → Pago |
| Conversão por Persona | 4 | Um email por persona (Marcos, Carlos, Zé, Ana) |

**Ferramentas sugeridas:** Brevo (grátis até 300/dia), Customer.io, ou Firebase Functions + Nodemailer

---

## SEQUÊNCIA 1: Onboarding (5 emails)

### Email 1 — Boas-vindas (Dia 0, imediato)

**Assunto:** Bem-vindo ao PraticOS, {{first_name}}! Sua primeira OS em 5 minutos

**Corpo:**
```
Olá, {{first_name}}!

Seja bem-vindo ao PraticOS 👋

Você acaba de dar o primeiro passo para organizar seu negócio de serviços.

Em 5 minutos você consegue:
✅ Criar sua primeira Ordem de Serviço
✅ Enviar o link de acompanhamento para seu cliente
✅ Ver o histórico do cliente

Vamos lá? Abra o app e clique em "Nova OS".

Se precisar de ajuda, é só responder este email.

— Equipe PraticOS
```

**Métricas:** Taxa de abertura, clique em "Abra o app"

---

### Email 2 — Primeira OS (Dia 1, se não criou OS)

**Assunto:** {{first_name}}, sua primeira OS está te esperando

**Corpo:**
```
Oi, {{first_name}}!

Vi que você ainda não criou sua primeira OS.

Entendo — às vezes falta um tempinho pra sentar e testar algo novo.

Mas prometo: leva menos de 2 minutos.

👉 [Criar minha primeira OS agora]

O que você vai conseguir depois de criar:
- Link para o cliente acompanhar o status (sem precisar ligar)
- PDF profissional para enviar por WhatsApp
- Histórico salvo para sempre

Qualquer dúvida, é só responder aqui.

— Rafael
PraticOS
```

**Condição:** Só enviar se não criou OS no dia 0
**Métricas:** Taxa de clique no CTA

---

### Email 3 — Link Mágico (Dia 3)

**Assunto:** Seus clientes vão adorar isso (e você também)

**Corpo:**
```
{{first_name}}, você já usou o link mágico?

É a funcionalidade que nossos usuários mais amam:

Quando você cria uma OS, o PraticOS gera um link único.
Você manda pelo WhatsApp para o cliente.
Ele abre no celular, sem baixar app, sem fazer cadastro.
Vê o status em tempo real.

Resultado? Zero ligações de "tá pronto?".

Nossos usuários reportam redução de 70% nas ligações desnecessárias.

👉 [Testar o link mágico agora]

— Equipe PraticOS
```

**Métricas:** Taxa de abertura, clique

---

### Email 4 — Checklist de Ativação (Dia 7)

**Assunto:** Você está usando 100% do PraticOS?

**Corpo:**
```
Olá, {{first_name}}!

Uma semana de PraticOS. Como está indo?

Veja o checklist de ativação completa:

□ Criou pelo menos 1 OS
□ Enviou link mágico para um cliente
□ Adicionou foto de um aparelho/equipamento
□ Exportou um PDF profissional
□ Registrou um pagamento

Quantos você marcou? Responda este email e me conta!

Os usuários que completam os 5 passos ficam usando o app por muito mais tempo — e ganham mais dinheiro.

👉 [Abrir PraticOS agora]

— Rafael
```

**Métricas:** Respostas, taxa de clique

---

### Email 5 — Dashboard (Dia 14)

**Assunto:** {{first_name}}, veja o que você conquistou em 2 semanas

**Corpo:**
```
{{first_name}},

Duas semanas com o PraticOS.

Sabe o que mais me impressiona nos nossos usuários?

Depois de 2 semanas, eles não conseguem imaginar trabalhar sem o histórico de clientes.

"Como eu sabia quais aparelhos tinha em aberto antes? Não sabia." — Técnico de celular, SP

Já acessou seu dashboard hoje?
→ OS abertas
→ OS concluídas esta semana
→ Recebimentos do mês

👉 [Ver meu dashboard]

E se tiver alguma dúvida ou sugestão, responda aqui. Leio tudo.

— Rafael
PraticOS
```

**Métricas:** Taxa de abertura, clique no dashboard

---

## SEQUÊNCIA 2: Re-engajamento (2 emails)

### Email 6 — Sentimos sua falta (Dia 30 inativo)

**Assunto:** {{first_name}}, faz 30 dias que você não abre o PraticOS

**Corpo:**
```
Oi, {{first_name}}

Vi que faz um mês que você não abre o PraticOS.

Tudo bem?

Às vezes a rotina corrida deixa a gente sem tempo.
Às vezes o sistema não encaixou direito.
Às vezes é só falta de uma empurradinha.

Se foi algo que não funcionou, me conta — posso ajudar.

Se for falta de tempo, preparei um vídeo de 2 minutos só para você:
👉 [Assistir: Como criar OS em 90 segundos]

O PraticOS continua te esperando. Sua conta e seus dados estão salvos.

— Rafael
PraticOS
```

**Condição:** Usuário sem login há 30+ dias
**Métricas:** Taxa de abertura, reativação (login após email)

---

### Email 7 — História de Sucesso (Dia 45 inativo)

**Assunto:** Como o {{segment_name}} do João virou referência na cidade

**Corpo:**
```
{{first_name}},

Deixa eu te contar uma história.

João tem uma assistência técnica de celular em Uberlândia.
Antes do PraticOS, recebia 20 ligações por dia de clientes perguntando status.
Depois de 1 semana usando o link mágico: 3 ligações por dia.

"Ganho 2 horas por dia que antes perdia no telefone." — João, AT Uberlândia

{{first_name}}, você pode ter o mesmo resultado.

👉 [Reativar minha conta]

Se precisar de ajuda para começar, é só responder este email.

— Rafael
```

**Variável:** {{segment_name}} adapta para o segmento do usuário
**Métricas:** Taxa de reativação

---

## SEQUÊNCIA 3: Upgrade (2 emails)

### Email 8 — Aviso 80% do Limite (Automático)

**Assunto:** {{first_name}}, você está usando 80% do seu plano

**Corpo:**
```
Oi, {{first_name}}!

Boa notícia: seu negócio está crescendo 📈

Você já usou {{usage_count}} das {{plan_limit}} {{resource_name}} do plano Free.

Quando chegar no limite, novas {{resource_name}} ficam pausadas.

Para continuar sem interrupção:

🚀 Plano Starter — R$59/mês
✅ OS ilimitadas
✅ Fotos ilimitadas
✅ PDF sem marca d'água
✅ Histórico completo

👉 [Fazer upgrade agora — R$59/mês]

Qualquer dúvida, responda este email.

— Equipe PraticOS
```

**Trigger:** Usuário atingiu 80% do limite do plano
**Métricas:** Taxa de conversão para pago

---

### Email 9 — Limite Atingido (Automático)

**Assunto:** Sua conta atingiu o limite — continue sem parar

**Corpo:**
```
{{first_name}},

Você atingiu o limite do plano Free.

Isso significa que você está usando o PraticOS ativamente — ótimo sinal! 🎉

Para continuar sem interrupção:

**Plano Starter — R$59/mês**
- OS ilimitadas (você estava limitado)
- Fotos ilimitadas (você estava limitado)
- PDF profissional sem marca d'água
- Suporte por WhatsApp

**Quanto vale isso?**
Se você cobrar apenas R$4 a mais por OS, o plano se paga sozinho.

👉 [Ativar Starter agora — R$59/mês]

Ou fale conosco: (48) 98879-4742

— Rafael
PraticOS
```

**Trigger:** Usuário atingiu 100% do limite
**Urgência:** Bloqueio real de funcionalidade
**Métricas:** Taxa de conversão, tempo entre email e conversão

---

## SEQUÊNCIA 4: Conversão por Persona (4 emails)

### Email 10 — Para Marcos (Técnico de Celular)

**Assunto:** Marcos, quanto tempo você perde com ligações por dia?

**Corpo:**
```
Oi, {{first_name}}!

Deixa eu te fazer uma pergunta:

Quantas vezes por dia um cliente te liga perguntando "tá pronto?"

5? 10? 15?

Se for 10 ligações × 3 minutos = 30 minutos perdidos por dia.
Em um mês = 10 horas.
10 horas que poderiam ser mais consertos ou descanso.

O PraticOS tem uma funcionalidade que resolve isso:

**Link Mágico** — o cliente acompanha o status no celular, sem ligar.

Você manda um link pelo WhatsApp.
Ele abre, vê "em análise", "peça pedida", "pronto para retirar".
Ele NÃO precisa baixar app. NÃO precisa fazer cadastro.

Resultado: redução de 70% nas ligações.

👉 [Ativar plano completo — R$59/mês]

Vale 1 conserto. Menos de R$2 por dia.

— Rafael
```

**Segmento:** Usuários com segmento "assistencia-celular"
**Métricas:** Taxa de conversão por segmento

---

### Email 11 — Para Carlos (Técnico de Refrigeração)

**Assunto:** Carlos, já perdeu algum contrato de manutenção por esquecimento?

**Corpo:**
```
Oi, {{first_name}}!

Pergunta direta: você já perdeu um contrato de manutenção preventiva porque esqueceu de fazer a visita?

Eu sei que isso acontece. A vida de técnico MEI é corrida.

Um contrato de PMOC pode valer R$800–2.000 por ano.
Perder um por esquecimento é R$800–2.000 no lixo.

O PraticOS resolve com **Alertas Automáticos**:

→ Você cadastra: "Cliente X, manutenção trimestral"
→ 3 dias antes da data: notificação no seu celular
→ No dia: lembrete de manhã
→ Depois da visita: relatório gerado automaticamente

Além disso: histórico de cada equipamento (gás adicionado, peças trocadas).

**O plano Starter custa R$59/mês.**
Se salvar 1 contrato de R$600, pagou 10 meses.

👉 [Ativar Starter — R$59/mês]

— Rafael
PraticOS
```

**Segmento:** Usuários com segmento "refrigeracao"

---

### Email 12 — Para Zé (Dono de Oficina)

**Assunto:** Zé, você sabe exatamente quanto sua oficina lucrou este mês?

**Corpo:**
```
Oi, {{first_name}}!

Pergunta que todo dono de oficina se faz:

"No fim do mês, depois de pagar tudo, sobrou alguma coisa?"

A maioria não sabe responder com certeza.

O PraticOS tem um **Dashboard Financeiro** que mostra:

💰 Receita do dia (atualiza em tempo real)
💰 Receitas do mês vs mês anterior
💰 OS em aberto com valor total
💰 Recebimentos por forma de pagamento

Além disso: cada OS registra as peças usadas.
Você sabe exatamente quanto gastou em peça por carro.

**E a busca por placa:**
Cliente chegou? Digita a placa.
Aparece todo o histórico: visitas anteriores, trocas, pendências.
Seus mecânicos impressionam o cliente sem fazer nenhum esforço.

👉 [Ativar plano completo — R$59/mês]

Menos de R$2/dia para saber se seu negócio está lucrando.

— Rafael
```

**Segmento:** Usuários com segmento "automotivo"

---

### Email 13 — Para Ana (Gestora de Equipe)

**Assunto:** Ana, quanto você paga hoje para gerenciar sua equipe de campo?

**Corpo:**
```
Oi, {{first_name}}!

Rápido cálculo:

Se você usa Field Control: R$79/usuário/mês
5 técnicos = R$395/mês

Se usa Contele: R$89 + mínimo 4 usuários = R$356/mês

**PraticOS Plano Business: R$249/mês — sem limite de usuários.**

Mas além do preço, o que o PraticOS oferece para gestoras:

✅ Dashboard em tempo real de toda equipe
✅ OS atribuídas por técnico com status
✅ Formulários dinâmicos customizáveis por tipo de serviço
✅ Relatório em PDF automático para clientes corporativos
✅ RBAC: cada técnico vê só o que precisa

**Trial grátis. Sem cartão de crédito.**

👉 [Testar PraticOS grátis por 14 dias]

Se quiser uma demonstração para sua equipe, responda este email.

— Rafael
PraticOS
```

**Segmento:** Usuários com segmento "gestao" ou empresas com 5+ usuários

---

## Variáveis de Template

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `{{first_name}}` | Nome do usuário | "Marcos" |
| `{{usage_count}}` | Quantidade usada | "38" |
| `{{plan_limit}}` | Limite do plano | "50" |
| `{{resource_name}}` | Recurso limitado | "OS", "fotos" |
| `{{segment_name}}` | Segmento do usuário | "assistência técnica" |

---

## Implementação Técnica

### Pré-requisitos
- [ ] Captura de email no onboarding (Firebase Auth já tem)
- [ ] Segmentação de usuário por tipo de negócio (campo no cadastro)
- [ ] Tracking de uso (OS criadas, fotos, etc.) — precisa de Firestore counter
- [ ] Trigger de limite atingido — Firebase Functions

### Ferramentas
- **Brevo** (ex-Sendinblue): grátis até 300 emails/dia, API REST
- **Customer.io**: melhor para automação comportamental, pago
- **Firebase Functions**: para triggers de limite e inatividade

### Sequência de Implementação
1. Email 1 (boas-vindas) — mais simples, só precisa de email
2. Emails 8 e 9 (upgrade) — precisa de billing implementado
3. Emails 2–5 (onboarding) — precisa de tracking de atividade
4. Emails 6 e 7 (re-engajamento) — precisa de last_login
5. Emails 10–13 (persona) — precisa de segmentação

---

## Métricas a Monitorar

| Métrica | Benchmark | Meta |
|---------|-----------|------|
| Taxa de abertura | 20–25% | 35%+ |
| Taxa de clique | 2–5% | 8%+ |
| Taxa de reativação (re-eng.) | 5–10% | 15% |
| Taxa de conversão (upgrade) | 3–8% | 12% |
