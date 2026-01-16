# Social Features V3 - Lista Unificada (OS = Conversa)

## Visao Geral

Esta versao unifica a lista de OSs com a funcionalidade de conversas. Cada OS se torna uma conversa com timeline completa de eventos, sem necessidade de abas ou telas adicionais.

### Principio Central

**A lista de OSs E a lista de conversas. Ao tocar em uma OS, abre a timeline (chat) em vez dos detalhes.**

### Mudancas em Relacao ao App Atual

| Aspecto | Antes | Depois |
|---------|-------|--------|
| Tap na OS | Abre detalhes | Abre **timeline** |
| Detalhes da OS | Tela principal | Acessivel via botao (i) |
| Preview no card | Servico principal | **Ultima atividade** |
| Indicador nao lido | Nao existe | **Badge + dot azul** |
| Comunicacao | WhatsApp externo | **Dentro do app** |

### Beneficios

1. **Zero navegacao extra** - nao adiciona abas
2. **Comunicacao em primeiro plano** - timeline e a tela principal
3. **Historia completa** - todos eventos da OS num lugar
4. **Substitui WhatsApp** - UX familiar

---

## UX Flow

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│                 │         │                 │         │                 │
│  Lista de OSs   │──tap───>│    Timeline     │──tap───>│  Detalhes OS    │
│  (Home)         │         │    (Chat)       │   (i)   │  (Tela atual)   │
│                 │         │                 │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

---

## Tela: Lista de OSs (Home Atualizada)

### Layout

```
┌─────────────────────────────────────────┐
│                                         │
│  Ordens de Servico              📊  +   │
│                                         │
├─────────────────────────────────────────┤
│  🔍 Buscar...                           │
├─────────────────────────────────────────┤
│  [Todos] [Nao lidas] [Aprovado] ...     │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 🔵 #1234 • Joao Silva       10:30  ││
│  │    💬 Maria: @voce pode...     (2) ││
│  │    🔵 Aprovado            R$ 450   ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 🔵 #1230 • Ana Paula        09:15  ││
│  │    📷 Carlos adicionou 3 fotos (1) ││
│  │    🟣 Progresso           R$ 800   ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ ⚠️ #1228 • Pedro             08:00  ││
│  │    ⚠️ Prazo vence hoje!            ││
│  │    🟣 Progresso          R$ 1.200  ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │    #1225 • Fernanda         Ontem  ││
│  │    Voce: Entregue ✓✓               ││
│  │    ✅ Concluido           R$ 650   ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │    #1220 • Carlos            Seg   ││
│  │    💰 Pagamento: R$ 500 PIX   ✓✓   ││
│  │    ✅ Concluido           R$ 500   ││
│  └─────────────────────────────────────┘│
│                                         │
├─────────────────────────────────────────┤
│  🏠         👥         •••             │
│  OSs      Clientes    Mais             │
│  (3)                                   │
└─────────────────────────────────────────┘
```

### Anatomia do Card

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────┐  🔵 #1234 • Joao Silva                   10:30   │
│  │ 🔵   │     💬 Maria: @voce pode usar a peca...    (2)   │
│  │ img  │     🔵 Aprovado                        R$ 450    │
│  │      │                                                   │
│  └──────┘                                                   │
│                                                             │
│  [thumb]  [indicador] [numero] [cliente]           [hora]   │
│           [icone] [preview da ultima atividade]   [badge]   │
│           [status dot] [status label]             [valor]   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Componentes do Card

| Elemento | Descricao |
|----------|-----------|
| Thumbnail | Foto de capa da OS (ou icone do dispositivo) |
| Dot azul | Indica atividade nao lida |
| Numero | #1234 |
| Cliente | Nome do cliente |
| Hora | Hora da ultima atividade |
| Icone | Tipo da ultima atividade (💬📷✅🔧💰⚠️) |
| Preview | Texto resumido da ultima atividade |
| Badge | Quantidade de itens nao lidos |
| Status | Dot colorido + label do status |
| Valor | Total da OS |

### Indicadores Visuais

| Indicador | Significado | Visual |
|-----------|-------------|--------|
| 🔵 Dot (thumb) | Atividade nao lida | Dot 12px azul no canto do thumb |
| (N) Badge | Quantidade nao lida | Circulo azul com numero |
| ✓✓ Azul | Voce enviou, foi lido | Checkmarks azuis |
| ✓✓ Cinza | Voce enviou, nao lido | Checkmarks cinza |
| ⚠️ Amarelo | Prazo vencendo | Icone warning + fundo amarelo claro |
| 🔴 Vermelho | Prazo vencido | Dot vermelho no thumb |

### Previews por Tipo de Atividade

| Tipo | Icone | Preview |
|------|-------|---------|
| Comentario | 💬 | "Maria: @voce pode usar..." |
| Mencao | 💬 | "Maria: @voce precisa ver isso" |
| Fotos | 📷 | "Carlos adicionou 3 fotos" |
| Status | ✅ | "Maria: Aprovado → Concluido" |
| Servico | 🔧 | "Servico: Troca de oleo +R$ 80" |
| Produto | 📦 | "Produto: Oleo 5W30 (4x)" |
| Checklist | 📋 | "Carlos concluiu Vistoria" |
| Pagamento | 💰 | "Pagamento: R$ 280 via PIX" |
| Prazo alerta | ⚠️ | "⚠️ Prazo vence hoje!" |
| Prazo vencido | 🔴 | "🔴 Prazo vencido ha 2 dias!" |
| Atribuicao | 👤 | "Atribuido a Carlos" |
| OS criada | 📋 | "OS criada" |

### Filtros Atualizados

```
[Todos] [Nao lidas] [Aprovado] [Progresso] [Concluido] ...
```

| Filtro | Descricao |
|--------|-----------|
| Todos | Todas as OSs (comportamento atual) |
| **Nao lidas** | **NOVO** - Apenas com atividade nao lida |
| Aprovado | Status = approved |
| Progresso | Status = progress |
| Concluido | Status = done |
| ... | Demais filtros existentes |

### Ordenacao

1. **OSs com alerta de prazo** (vencendo/vencido) - sempre no topo
2. **OSs com atividade nao lida** - ordenadas por ultima atividade
3. **OSs lidas** - ordenadas por ultima atividade

---

## Tela: Timeline (Chat da OS)

### Layout Principal

```
┌─────────────────────────────────────────┐
│  ←  #1234 • Joao Silva         ℹ️  •••  │
│      Troca de oleo • Fiat Uno           │
├─────────────────────────────────────────┤
│                                         │
│           ┌───────────────┐             │
│           │   15 Jan      │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📋 OS Criada               │         │
│  │ Cliente: Joao Silva        │         │
│  │ Veiculo: Fiat Uno 2015     │         │
│  │ Status: Orcamento          │         │
│  └────────────────────────────┘         │
│                   Sistema, 09:00        │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📷 3 fotos                 │         │
│  │ ┌─────┬─────┬─────┐        │         │
│  │ │ img │ img │ img │        │         │
│  │ └─────┴─────┴─────┘        │         │
│  └────────────────────────────┘         │
│                      Voce, 09:30    ✓✓  │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 🔧 Troca de oleo           │         │
│  │ R$ 80,00                   │         │
│  └────────────────────────────┘         │
│                      Voce, 09:45    ✓✓  │
│                                         │
│           ┌───────────────┐             │
│           │     Hoje      │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ ✅ Orcamento → Aprovado    │         │
│  └────────────────────────────┘         │
│                     Maria, 10:00        │
│                                         │
│         ┌────────────────────────────┐  │
│         │ @Joao, pode usar a peca   │  │
│         │ alternativa?              │  │
│         └────────────────────────────┘  │
│                     Maria, 10:30        │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │ Pode sim, cliente autorizou       │ │
│  └────────────────────────────────────┘ │
│  Voce, 10:35                        ✓✓  │
│                                         │
├─────────────────────────────────────────┤
│  📷  │ Mensagem...              │   ➤   │
└─────────────────────────────────────────┘
```

### Header

```
┌─────────────────────────────────────────┐
│  ←  #1234 • Joao Silva         ℹ️  •••  │
│      Troca de oleo • Fiat Uno           │
└─────────────────────────────────────────┘
      │                            │    │
      │                            │    └── Menu acoes
      │                            └─────── Ver detalhes da OS
      └────────────────────────────────── Numero • Cliente
                                          Servico • Dispositivo
```

### Input de Mensagem

```
Estado normal:
┌─────────────────────────────────────────┐
│  📷  │ Mensagem...              │   ➤   │
└─────────────────────────────────────────┘

Digitando @mention:
┌─────────────────────────────────────────┐
│  @mar|                                  │
│  ┌─────────────────────────────────┐    │
│  │ 👤 Maria Silva (Supervisor)     │    │
│  │ 👤 Marcos Tecnico               │    │
│  └─────────────────────────────────┘    │
│  📷  │                          │   ➤   │
└─────────────────────────────────────────┘

Multiline:
┌─────────────────────────────────────────┐
│  @Maria, vou precisar pedir a peca     │
│  porque nao tem em estoque.            │
│  ─────────────────────────────────────  │
│  📷 Foto   📎 Arquivo         [Enviar]  │
└─────────────────────────────────────────┘
```

### Menu de Acoes (...)

```
┌─────────────────────────────────────────┐
│              Opcoes                     │
├─────────────────────────────────────────┤
│  📄  Ver detalhes da OS                 │
│  📷  Adicionar fotos                    │
│  📋  Preencher checklist                │
│  🔔  Silenciar notificacoes             │
├─────────────────────────────────────────┤
│  ❌  Cancelar                           │
└─────────────────────────────────────────┘
```

---

## Tipos de Eventos na Timeline

### 1. OS Criada (Sistema)

```
┌────────────────────────────────────────┐
│ 📋 OS Criada                           │
│                                        │
│ Cliente: Joao Silva                    │
│ Telefone: (11) 99999-9999              │
│ Veiculo: Fiat Uno 2015                 │
│ Placa: ABC-1234                        │
│ Status: Orcamento                      │
│ Entrega prevista: 20/01/2025           │
└────────────────────────────────────────┘
                      Sistema, 09:00
```

**Dados:**
- type: `order_created`
- author: null (sistema)
- data: { customerName, customerPhone, deviceName, devicePlate, status, dueDate }

---

### 2. Mudanca de Status

```
┌────────────────────────────────────────┐
│ ✅ Status alterado                     │
│ Orcamento → Aprovado                   │
└────────────────────────────────────────┘
                      Maria, 10:00
```

```
┌────────────────────────────────────────┐
│ ❌ OS Cancelada                        │
│ Motivo: Cliente desistiu               │
└────────────────────────────────────────┘
                      Maria, 10:00
```

**Dados:**
- type: `status_change`
- author: { id, name }
- data: { oldStatus, newStatus, reason? }

**Icones por status:**
| De/Para | Icone |
|---------|-------|
| → Aprovado | ✅ |
| → Concluido | ✅ |
| → Em andamento | 🔄 |
| → Cancelado | ❌ |
| Outro | 🔵 |

---

### 3. Fotos Adicionadas

```
┌────────────────────────────────────────┐
│ 📷 3 fotos adicionadas                 │
│                                        │
│ ┌─────────┬─────────┬─────────┐        │
│ │         │         │         │        │
│ │   img   │   img   │   img   │        │
│ │         │         │         │        │
│ └─────────┴─────────┴─────────┘        │
│                                        │
│ Motor antes do servico                 │
└────────────────────────────────────────┘
                      Voce, 09:30     ✓✓
```

**Dados:**
- type: `photos_added`
- author: { id, name }
- data: { photoUrls[], caption? }

**Comportamento:**
- Tap na foto abre galeria fullscreen
- Maximo 3 fotos no grid, "+N" para mais
- Caption opcional abaixo das fotos

---

### 4. Servico Adicionado

```
┌────────────────────────────────────────┐
│ 🔧 Servico adicionado                  │
│                                        │
│ Troca de oleo                          │
│ R$ 80,00                               │
│                                        │
│ Descricao: Troca de oleo do motor      │
│ com filtro                             │
└────────────────────────────────────────┘
                      Voce, 09:45     ✓✓
```

**Dados:**
- type: `service_added`
- author: { id, name }
- data: { serviceName, value, description? }

---

### 5. Servico Atualizado

```
┌────────────────────────────────────────┐
│ 🔧 Servico atualizado                  │
│                                        │
│ Alinhamento                            │
│ R$ 100,00 → R$ 120,00                  │
│                                        │
│ Motivo: Ajuste de preco                │
└────────────────────────────────────────┘
                      Maria, 11:00
```

**Dados:**
- type: `service_updated`
- author: { id, name }
- data: { serviceName, oldValue, newValue, reason? }

---

### 6. Servico Removido

```
┌────────────────────────────────────────┐
│ 🔧 Servico removido                    │
│                                        │
│ Balanceamento                          │
│ - R$ 60,00                             │
└────────────────────────────────────────┘
                      Maria, 11:05
```

**Dados:**
- type: `service_removed`
- author: { id, name }
- data: { serviceName, value }

---

### 7. Produto Adicionado

```
┌────────────────────────────────────────┐
│ 📦 Produto adicionado                  │
│                                        │
│ Oleo 5W30 (4 unidades)                 │
│ 4x R$ 50,00 = R$ 200,00                │
└────────────────────────────────────────┘
                      Voce, 09:50     ✓✓
```

**Dados:**
- type: `product_added`
- author: { id, name }
- data: { productName, quantity, unitPrice, totalPrice }

---

### 8. Produto Atualizado

```
┌────────────────────────────────────────┐
│ 📦 Produto atualizado                  │
│                                        │
│ Oleo 5W30                              │
│ Quantidade: 4 → 5 unidades             │
│ Total: R$ 200 → R$ 250                 │
└────────────────────────────────────────┘
                      Maria, 11:10
```

**Dados:**
- type: `product_updated`
- author: { id, name }
- data: { productName, oldQty, newQty, oldTotal, newTotal }

---

### 9. Produto Removido

```
┌────────────────────────────────────────┐
│ 📦 Produto removido                    │
│                                        │
│ Filtro de ar                           │
│ - R$ 45,00                             │
└────────────────────────────────────────┘
                      Maria, 11:15
```

**Dados:**
- type: `product_removed`
- author: { id, name }
- data: { productName, value }

---

### 10. Checklist/Formulario Concluido

```
┌────────────────────────────────────────┐
│ 📋 Checklist concluido                 │
│                                        │
│ Vistoria de Entrada                    │
│ 15/15 itens ✓                          │
│                                        │
│                            [Ver →]     │
└────────────────────────────────────────┘
                      Carlos, 14:00
```

**Dados:**
- type: `form_completed`
- author: { id, name }
- data: { formName, formId, totalItems, completedItems }

**Comportamento:**
- Tap em [Ver] abre o formulario preenchido

---

### 11. Pagamento Recebido

```
┌────────────────────────────────────────┐
│ 💰 Pagamento recebido                  │
│                                        │
│ R$ 280,00 via PIX                      │
│                                        │
│ Total OS: R$ 280,00                    │
│ Pago: R$ 280,00                        │
│ Status: Quitado ✓                      │
└────────────────────────────────────────┘
                      Maria, 16:00
```

```
┌────────────────────────────────────────┐
│ 💰 Pagamento recebido                  │
│                                        │
│ R$ 150,00 via Cartao Credito           │
│                                        │
│ Total OS: R$ 450,00                    │
│ Pago: R$ 150,00                        │
│ Restante: R$ 300,00                    │
└────────────────────────────────────────┘
                      Maria, 14:00
```

**Dados:**
- type: `payment_received`
- author: { id, name }
- data: { amount, method, orderTotal, totalPaid, remaining }

---

### 12. Comentario/Mensagem

Mensagem de outro usuario (esquerda):
```
         ┌────────────────────────────┐
         │ @Joao, pode usar a peca   │
         │ alternativa ou precisa    │
         │ ser original?             │
         └────────────────────────────┘
                       Maria, 10:30
```

Minha mensagem (direita):
```
┌────────────────────────────────────────┐
│ Pode ser alternativa, o cliente ja    │
│ autorizou por telefone as 10h         │
└────────────────────────────────────────┘
Voce, 10:35                          ✓✓
```

**Dados:**
- type: `comment`
- author: { id, name }
- data: { text, mentions[], attachments[] }

---

### 13. Mensagem com Anexo

```
         ┌────────────────────────────┐
         │ Olha como ficou:          │
         │                            │
         │ ┌────────────────────┐     │
         │ │                    │     │
         │ │    [foto anexa]    │     │
         │ │                    │     │
         │ └────────────────────┘     │
         └────────────────────────────┘
                       Carlos, 14:30
```

**Dados:**
- type: `comment`
- author: { id, name }
- data: { text?, attachments[{ type, url, thumbnailUrl }] }

---

### 14. Responsavel Atribuido/Alterado

```
┌────────────────────────────────────────┐
│ 👤 Responsavel atribuido               │
│                                        │
│ Carlos Silva (Tecnico)                 │
└────────────────────────────────────────┘
                      Maria, 09:30
```

```
┌────────────────────────────────────────┐
│ 👤 Responsavel alterado                │
│                                        │
│ Joao → Carlos                          │
└────────────────────────────────────────┘
                      Maria, 11:00
```

**Dados:**
- type: `assignment_change`
- author: { id, name }
- data: { oldAssignee?, newAssignee }

---

### 15. Alerta de Prazo (Sistema)

```
┌────────────────────────────────────────┐
│ ⚠️ Prazo vence em 1 dia                │
│                                        │
│ Entrega prevista: 20/01/2025           │
└────────────────────────────────────────┘
                      Sistema, 08:00
```

```
┌────────────────────────────────────────┐
│ 🔴 Prazo vencido!                      │
│                                        │
│ Entrega era: 19/01/2025                │
│ Atraso: 2 dias                         │
└────────────────────────────────────────┘
                      Sistema, 08:00
```

**Dados:**
- type: `due_date_alert`
- author: null (sistema)
- data: { dueDate, daysRemaining, isOverdue }

---

### 16. Data de Entrega Alterada

```
┌────────────────────────────────────────┐
│ 📅 Data de entrega alterada            │
│                                        │
│ 20/01/2025 → 25/01/2025                │
│                                        │
│ Motivo: Cliente solicitou mais prazo   │
└────────────────────────────────────────┘
                      Maria, 11:00
```

**Dados:**
- type: `due_date_change`
- author: { id, name }
- data: { oldDate, newDate, reason? }

---

## Sistema de Entrega e Leitura (Estilo WhatsApp)

### Modelo Mental: OS como Grupo de WhatsApp

Cada OS funciona como um **grupo de WhatsApp** onde:

| WhatsApp Grupo | PraticOS OS |
|----------------|-------------|
| Membros do grupo | Colaboradores da empresa |
| Mensagem enviada | Evento na timeline |
| ✓ Enviado | Salvo no Firestore |
| ✓✓ Entregue | Push notification recebido |
| ✓✓ Azul (Lido) | Usuario abriu a timeline |

---

### Participantes da Conversa

#### Opcao A: Todos da Empresa (MVP - Mais Simples)

```
OS #1234
├── Evento criado
└── Notifica TODOS os colaboradores da empresa
    ├── Maria (Supervisor) ✓
    ├── Joao (Tecnico) ✓
    ├── Carlos (Tecnico) ✓
    └── Ana (Atendente) ✓
```

**Prós:** Simples de implementar, todos ficam informados
**Contras:** Pode gerar muitas notificacoes em empresas grandes

#### Opcao B: Apenas Envolvidos (Recomendado para evolucao)

```
OS #1234
├── Criador: Maria
├── Responsavel: Joao
├── Mencionados: Carlos (em um comentario)
└── Seguidores: Ana (optou por seguir)

Evento criado → Notifica apenas:
├── Maria (criou a OS) ✓
├── Joao (responsavel) ✓
├── Carlos (foi mencionado) ✓
└── Ana (esta seguindo) ✓
```

**Participantes automaticos:**
- Quem **criou** a OS
- Quem esta **atribuido/responsavel**
- Quem foi **mencionado** (@usuario)
- Quem **comentou** na OS (entra automaticamente)

**Participantes opcionais:**
- Quem clicou em **"Seguir"** a OS

---

### Estados de Mensagem

#### 1. Enviado (✓)

```
┌────────────────────────────────────────┐
│ Pode ser alternativa, cliente aprovou │
└────────────────────────────────────────┘
Voce, 10:35                            ✓
```

- Mensagem salva no Firestore
- Ainda nao chegou nos dispositivos dos outros

#### 2. Entregue (✓✓ Cinza)

```
┌────────────────────────────────────────┐
│ Pode ser alternativa, cliente aprovou │
└────────────────────────────────────────┘
Voce, 10:35                           ✓✓
```

- Push notification enviado
- Pelo menos um destinatario recebeu no dispositivo
- **Mas ainda nao abriu a conversa**

#### 3. Lido (✓✓ Azul)

```
┌────────────────────────────────────────┐
│ Pode ser alternativa, cliente aprovou │
└────────────────────────────────────────┘
Voce, 10:35                    ✓✓ (azul)
```

- Pelo menos um destinatario **abriu a timeline** da OS
- A mensagem apareceu na tela dele

---

### Visualizacao dos Status

#### Na Timeline (Chat)

```
         ┌────────────────────────────┐
         │ @Joao, pode usar a peca   │
         │ alternativa?              │
         └────────────────────────────┘
                       Maria, 10:30

┌────────────────────────────────────────┐
│ Pode ser alternativa, cliente aprovou │
└────────────────────────────────────────┘
Voce, 10:35                           ✓✓

         ↑
         Tap para ver quem leu
```

#### Popup "Visto por" (Tap no ✓✓)

```
┌─────────────────────────────────────────┐
│           Informacoes                   │
├─────────────────────────────────────────┤
│                                         │
│  LIDO POR                               │
│  👤 Maria Silva          10:40          │
│  👤 Carlos Tecnico       10:45          │
│                                         │
│  ENTREGUE PARA                          │
│  👤 Ana Atendente        10:35          │
│     (ainda nao leu)                     │
│                                         │
├─────────────────────────────────────────┤
│                Fechar                   │
└─────────────────────────────────────────┘
```

---

### Fluxo Completo de Mensagem

#### 1. Usuario Envia Mensagem

```
Joao digita: "Pode ser alternativa"
     │
     ▼
┌─────────────────────────────────────┐
│ 1. Salva no Firestore               │
│    - createdAt: now()               │
│    - participants: [maria, carlos]  │
│    - deliveredTo: {}                │
│    - readBy: {joao: now()}          │
│                                     │
│ 2. UI mostra ✓ (enviado)            │
└─────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────┐
│ 3. Cloud Function dispara           │
│    - Envia push para maria          │
│    - Envia push para carlos         │
└─────────────────────────────────────┘
```

#### 2. Push Chega no Dispositivo

```
Maria recebe push notification
     │
     ▼
┌─────────────────────────────────────┐
│ 4. App atualiza Firestore           │
│    deliveredTo.maria = now()        │
│                                     │
│ 5. UI do Joao atualiza para ✓✓      │
└─────────────────────────────────────┘
```

#### 3. Usuario Abre a Timeline

```
Maria abre a OS #1234
     │
     ▼
┌─────────────────────────────────────┐
│ 6. App marca como lido              │
│    readBy.maria = now()             │
│                                     │
│ 7. UI do Joao atualiza para ✓✓ azul │
│                                     │
│ 8. Badge da Maria zera              │
│    unreadCounts.maria = 0           │
└─────────────────────────────────────┘
```

---

### Logica dos Checkmarks (Flutter)

```dart
Widget _buildMessageStatus(TimelineEvent event, String currentUserId) {
  // So mostra status para mensagens do usuario atual
  if (event.author?.id != currentUserId) return SizedBox.shrink();

  final participants = event.participants ?? [];
  final deliveredTo = event.deliveredTo ?? {};
  final readBy = event.readBy ?? {};

  // Remover o autor das contagens
  final targetUsers = participants.where((id) => id != currentUserId).toList();

  if (targetUsers.isEmpty) {
    // Ninguem para receber (so eu na OS)
    return Icon(CupertinoIcons.checkmark, color: CupertinoColors.systemGrey, size: 16);
  }

  final deliveredCount = targetUsers.where((id) => deliveredTo.containsKey(id)).length;
  final readCount = targetUsers.where((id) => readBy.containsKey(id)).length;

  if (readCount > 0) {
    // Pelo menos um leu → ✓✓ azul
    return Icon(CupertinoIcons.checkmark_seal_fill, color: CupertinoColors.activeBlue, size: 16);
  }

  if (deliveredCount > 0) {
    // Entregue mas nao lido → ✓✓ cinza
    return Icon(CupertinoIcons.checkmark_seal, color: CupertinoColors.systemGrey, size: 16);
  }

  // Apenas enviado → ✓
  return Icon(CupertinoIcons.checkmark, color: CupertinoColors.systemGrey, size: 16);
}
```

---

### Regras de Notificacao

#### Quem Recebe Push?

| Evento | Quem recebe | Prioridade |
|--------|-------------|------------|
| @mencao direta | Apenas o mencionado | Alta |
| Comentario comum | Participantes da OS | Normal |
| Mudanca de status | Participantes da OS | Normal |
| Fotos adicionadas | Participantes da OS | Baixa |
| Prazo vencendo | Responsavel + Criador | Alta |
| OS atribuida | Novo responsavel | Alta |

#### Configuracoes por Usuario (Por OS)

```
┌─────────────────────────────────────────┐
│  Notificacoes da OS #1234               │
├─────────────────────────────────────────┤
│                                         │
│  🔔 Receber notificacoes      [ON/OFF]  │
│                                         │
│  Quando notificar:                      │
│  ☑️ Mencoes diretas (@voce)             │
│  ☑️ Mudancas de status                  │
│  ☐ Novos comentarios                    │
│  ☐ Fotos adicionadas                    │
│                                         │
│  🔇 Silenciar por:                      │
│     [ 1 hora ] [ 8 horas ] [ Sempre ]   │
│                                         │
└─────────────────────────────────────────┘
```

---

### Comparativo com WhatsApp

| Funcionalidade | WhatsApp Grupo | PraticOS OS |
|----------------|----------------|-------------|
| Membros | Fixos (adicionados manualmente) | Dinamicos (envolvidos na OS) |
| ✓ Enviado | Servidor recebeu | Firestore salvou |
| ✓✓ Entregue | Dispositivo recebeu | Push entregue |
| ✓✓ Azul | Abriu o chat | Abriu a timeline |
| Ver quem leu | Tap na mensagem | Tap no ✓✓ |
| Silenciar | Por grupo | Por OS |
| Sair do grupo | Sai e nao ve mais | "Deixar de seguir" |
| Admin | Sim | Nao (todos iguais) |
| Historico | Limitado | Completo (timeline = auditoria) |

---

### MVP vs Evolucao

#### MVP (Fase 1) - Simplificado

- **Participantes**: Todos da empresa
- **Status**: Apenas "lido" (sem "entregue")
- **Notificacoes**: Push para todos, sem configuracao
- **Silenciar**: Nao implementado

```typescript
// MVP: readBy apenas
interface TimelineEvent {
  // ...
  readBy: { [userId: string]: Timestamp };  // Quem leu
}
```

#### Evolucao (Fase 2+) - Completo

- **Participantes**: Dinamicos (envolvidos + seguidores)
- **Status**: Enviado → Entregue → Lido
- **Notificacoes**: Configuravel por OS
- **Silenciar**: Por tempo ou permanente
- **Deixar de seguir**: Opt-out de OSs

```typescript
// Evolucao: deliveredTo + readBy + participants
interface TimelineEvent {
  // ...
  participants: string[];                      // Quem deve receber
  deliveredTo: { [userId: string]: Timestamp }; // Quem recebeu push
  readBy: { [userId: string]: Timestamp };      // Quem leu
}
```

---

## Arquitetura Firestore

### Estrutura

```
/companies/{companyId}/
│
├── orders/{orderId}/
│   │
│   ├── ... (campos existentes)
│   │
│   ├── lastActivity: {              // Agregado para lista
│   │     type: string,
│   │     icon: string,
│   │     preview: string,
│   │     authorId: string?,
│   │     authorName: string?,
│   │     createdAt: Timestamp
│   │   }
│   │
│   ├── unreadCounts: {              // Map<userId, count>
│   │     'user123': 0,
│   │     'user456': 3
│   │   }
│   │
│   └── timeline/{eventId}/          // Subcollection
│         ├── type: string
│         ├── visibility: 'internal' | 'customer'  // NOVO
│         ├── author: { id, name, type, photoUrl }?  // type: collaborator|customer|system
│         ├── data: { ... }
│         ├── readBy: string[]
│         ├── mentions: string[]
│         ├── createdAt: Timestamp
│         └── isDeleted: boolean
│
└── users/{userId}/
    └── settings/
          └── mutedOrders: string[]  // IDs de OSs silenciadas
```

### TimelineEvent Schema

```typescript
interface TimelineEvent {
  id: string;
  type: TimelineEventType;
  author: TimelineAuthor | null;  // null = sistema
  data: TimelineEventData;
  readBy: string[];
  mentions: string[];
  createdAt: Timestamp;
  isDeleted: boolean;

  // Visibilidade (Portal do Cliente)
  visibility: 'internal' | 'customer';  // Padrão: 'internal'
}

type TimelineEventType =
  | 'order_created'
  | 'status_change'
  | 'photos_added'
  | 'service_added'
  | 'service_updated'
  | 'service_removed'
  | 'product_added'
  | 'product_updated'
  | 'product_removed'
  | 'form_completed'
  | 'payment_received'
  | 'comment'
  | 'assignment_change'
  | 'due_date_alert'
  | 'due_date_change';

interface TimelineAuthor {
  id: string;
  name: string;
  type: 'collaborator' | 'customer' | 'system';  // Tipo do autor
  photoUrl?: string;
}

interface TimelineEventData {
  // comment
  text?: string;
  attachments?: Attachment[];

  // status_change
  oldStatus?: string;
  newStatus?: string;
  reason?: string;

  // photos_added
  photoUrls?: string[];
  caption?: string;

  // service_added/updated/removed
  serviceName?: string;
  serviceValue?: number;
  oldValue?: number;
  newValue?: number;
  description?: string;

  // product_added/updated/removed
  productName?: string;
  quantity?: number;
  oldQuantity?: number;
  newQuantity?: number;
  unitPrice?: number;
  totalPrice?: number;
  oldTotal?: number;
  newTotal?: number;

  // form_completed
  formName?: string;
  formId?: string;
  totalItems?: number;
  completedItems?: number;

  // payment_received
  amount?: number;
  method?: string;
  orderTotal?: number;
  totalPaid?: number;
  remaining?: number;

  // assignment_change
  oldAssignee?: { id: string; name: string };
  newAssignee?: { id: string; name: string };

  // due_date_alert/change
  dueDate?: Timestamp;
  oldDate?: Timestamp;
  newDate?: Timestamp;
  daysRemaining?: number;
  isOverdue?: boolean;

  // order_created
  customerName?: string;
  customerPhone?: string;
  deviceName?: string;
  devicePlate?: string;
}

interface Attachment {
  id: string;
  type: 'image' | 'file';
  url: string;
  thumbnailUrl?: string;
  name?: string;
  size?: number;
}
```

### LastActivity Schema (Agregado na OS)

```typescript
interface LastActivity {
  type: TimelineEventType;
  icon: string;           // Emoji para exibicao rapida
  preview: string;        // Texto truncado
  authorId?: string;
  authorName?: string;
  createdAt: Timestamp;
}
```

### Exemplos de LastActivity

```javascript
// Comentario
{
  type: 'comment',
  icon: '💬',
  preview: 'Maria: @voce pode usar a peca...',
  authorId: 'user123',
  authorName: 'Maria',
  createdAt: Timestamp
}

// Fotos
{
  type: 'photos_added',
  icon: '📷',
  preview: 'Carlos adicionou 3 fotos',
  authorId: 'user456',
  authorName: 'Carlos',
  createdAt: Timestamp
}

// Status
{
  type: 'status_change',
  icon: '✅',
  preview: 'Maria: Aprovado → Concluido',
  authorId: 'user123',
  authorName: 'Maria',
  createdAt: Timestamp
}

// Alerta (sistema)
{
  type: 'due_date_alert',
  icon: '⚠️',
  preview: '⚠️ Prazo vence hoje!',
  authorId: null,
  authorName: null,
  createdAt: Timestamp
}

// Voce enviou
{
  type: 'comment',
  icon: '💬',
  preview: 'Voce: Pode ser alternativa...',
  authorId: 'currentUserId',
  authorName: 'Voce',
  createdAt: Timestamp
}
```

---

## Models Flutter

### TimelineEvent

```dart
// lib/models/timeline_event.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'timeline_event.g.dart';

@JsonSerializable(explicitToJson: true)
class TimelineEvent {
  String? id;
  String? type;
  TimelineAuthor? author;
  TimelineEventData? data;
  List<String>? readBy;
  List<String>? mentions;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  bool? isDeleted;

  // Visibilidade: 'internal' (padrão) ou 'customer' (cliente vê)
  @JsonKey(defaultValue: 'internal')
  String? visibility;

  TimelineEvent();

  factory TimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventToJson(this);

  bool isReadBy(String userId) => readBy?.contains(userId) ?? false;
  bool get isSystemEvent => author == null;
  bool get isComment => type == 'comment';
  bool get isPublic => visibility == 'customer';  // Helper para visibilidade

  String get icon {
    switch (type) {
      case 'comment': return '💬';
      case 'photos_added': return '📷';
      case 'status_change': return data?.newStatus == 'canceled' ? '❌' : '✅';
      case 'service_added':
      case 'service_updated':
      case 'service_removed': return '🔧';
      case 'product_added':
      case 'product_updated':
      case 'product_removed': return '📦';
      case 'form_completed': return '📋';
      case 'payment_received': return '💰';
      case 'assignment_change': return '👤';
      case 'due_date_alert': return data?.isOverdue == true ? '🔴' : '⚠️';
      case 'due_date_change': return '📅';
      case 'order_created': return '📋';
      default: return '🔵';
    }
  }

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

@JsonSerializable()
class TimelineAuthor {
  String? id;
  String? name;
  String? photoUrl;

  // Tipo do autor: 'collaborator', 'customer', 'system'
  @JsonKey(defaultValue: 'collaborator')
  String? type;

  TimelineAuthor();

  factory TimelineAuthor.fromJson(Map<String, dynamic> json) =>
      _$TimelineAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAuthorToJson(this);

  bool get isCustomer => type == 'customer';
  bool get isCollaborator => type == 'collaborator';
  bool get isSystem => type == 'system';
}

@JsonSerializable(explicitToJson: true)
class TimelineEventData {
  // Comment
  String? text;
  List<TimelineAttachment>? attachments;

  // Status
  String? oldStatus;
  String? newStatus;
  String? reason;

  // Photos
  List<String>? photoUrls;
  String? caption;

  // Service
  String? serviceName;
  double? serviceValue;
  double? oldValue;
  double? newValue;
  String? description;

  // Product
  String? productName;
  int? quantity;
  int? oldQuantity;
  int? newQuantity;
  double? unitPrice;
  double? totalPrice;
  double? oldTotal;
  double? newTotal;

  // Form
  String? formName;
  String? formId;
  int? totalItems;
  int? completedItems;

  // Payment
  double? amount;
  String? method;
  double? orderTotal;
  double? totalPaid;
  double? remaining;

  // Assignment
  TimelineAuthor? oldAssignee;
  TimelineAuthor? newAssignee;

  // Due date
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? dueDate;
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? oldDate;
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? newDate;
  int? daysRemaining;
  bool? isOverdue;

  // Order created
  String? customerName;
  String? customerPhone;
  String? deviceName;
  String? devicePlate;

  TimelineEventData();

  factory TimelineEventData.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventDataFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventDataToJson(this);
}

@JsonSerializable()
class TimelineAttachment {
  String? id;
  String? type;
  String? url;
  String? thumbnailUrl;
  String? name;
  int? size;

  TimelineAttachment();

  factory TimelineAttachment.fromJson(Map<String, dynamic> json) =>
      _$TimelineAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAttachmentToJson(this);
}
```

### LastActivity (Adicionar ao Order)

```dart
// Adicionar ao lib/models/order.dart

@JsonSerializable()
class LastActivity {
  String? type;
  String? icon;
  String? preview;
  String? authorId;
  String? authorName;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  LastActivity();

  factory LastActivity.fromJson(Map<String, dynamic> json) =>
      _$LastActivityFromJson(json);
  Map<String, dynamic> toJson() => _$LastActivityToJson(this);

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

// No Order, adicionar:
class Order extends BaseAuditCompany {
  // ... campos existentes ...

  LastActivity? lastActivity;
  Map<String, int>? unreadCounts;

  // Helper para obter contagem de nao lidos do usuario atual
  int getUnreadCount(String userId) => unreadCounts?[userId] ?? 0;
}
```

---

## Repository

### TimelineRepository

```dart
// lib/repositories/timeline_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/global.dart';

class TimelineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _timelineRef(
    String companyId,
    String orderId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('timeline');
  }

  DocumentReference<Map<String, dynamic>> _orderRef(
    String companyId,
    String orderId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId);
  }

  /// Stream de eventos da timeline
  Stream<List<TimelineEvent>> getTimeline(String companyId, String orderId) {
    return _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Criar evento generico
  Future<TimelineEvent> createEvent(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    final docRef = await _timelineRef(companyId, orderId).add(event.toJson());
    event.id = docRef.id;

    await _updateLastActivity(companyId, orderId, event);
    await _incrementUnreadCounts(companyId, orderId, event.author?.id);

    return event;
  }

  /// Enviar comentario
  Future<TimelineEvent> sendComment(
    String companyId,
    String orderId,
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,  // NOVO: Define se cliente vê
  }) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'comment'
      ..visibility = isPublic ? 'customer' : 'internal'  // NOVO: Visibilidade
      ..author = (TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
        ..photoUrl = currentUser?.photoUrl
        ..type = 'collaborator')  // NOVO: Tipo do autor
      ..data = TimelineEventData()
        ..text = text
        ..attachments = attachments
      ..readBy = [currentUser?.id ?? '']
      ..mentions = _parseMentions(text)
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    return createEvent(companyId, orderId, event);
  }

  /// Enviar comentario do CLIENTE (via Portal)
  Future<TimelineEvent> sendCustomerComment(
    String companyId,
    String orderId,
    String text,
    String customerName,
  ) async {
    final event = TimelineEvent()
      ..type = 'comment'
      ..visibility = 'customer'  // Sempre público
      ..author = (TimelineAuthor()
        ..id = 'customer'  // ID especial para cliente
        ..name = customerName
        ..type = 'customer')  // Tipo: cliente
      ..data = TimelineEventData()
        ..text = text
      ..readBy = []  // Cliente não conta como "leu"
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    return createEvent(companyId, orderId, event);
  }

  /// Criar evento de mudanca de status
  Future<void> logStatusChange(
    String companyId,
    String orderId,
    String oldStatus,
    String newStatus, {
    String? reason,
  }) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'status_change'
      ..visibility = 'customer'  // SEMPRE público (cliente acompanha status)
      ..author = (TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
        ..type = 'collaborator')  // NOVO
      ..data = TimelineEventData()
        ..oldStatus = oldStatus
        ..newStatus = newStatus
        ..reason = reason
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de fotos adicionadas
  Future<void> logPhotosAdded(
    String companyId,
    String orderId,
    List<String> photoUrls, {
    String? caption,
    bool isPublic = true,  // NOVO: Fotos são públicas por padrão
  }) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'photos_added'
      ..visibility = isPublic ? 'customer' : 'internal'  // NOVO
      ..author = (TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
        ..type = 'collaborator')  // NOVO
      ..data = TimelineEventData()
        ..photoUrls = photoUrls
        ..caption = caption
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de servico adicionado
  Future<void> logServiceAdded(
    String companyId,
    String orderId,
    String serviceName,
    double value, {
    String? description,
  }) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'service_added'
      ..author = TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
      ..data = TimelineEventData()
        ..serviceName = serviceName
        ..serviceValue = value
        ..description = description
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de produto adicionado
  Future<void> logProductAdded(
    String companyId,
    String orderId,
    String productName,
    int quantity,
    double unitPrice,
  ) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'product_added'
      ..author = TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
      ..data = TimelineEventData()
        ..productName = productName
        ..quantity = quantity
        ..unitPrice = unitPrice
        ..totalPrice = quantity * unitPrice
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de formulario concluido
  Future<void> logFormCompleted(
    String companyId,
    String orderId,
    String formName,
    String formId,
    int totalItems,
  ) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'form_completed'
      ..author = TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
      ..data = TimelineEventData()
        ..formName = formName
        ..formId = formId
        ..totalItems = totalItems
        ..completedItems = totalItems
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de pagamento recebido
  Future<void> logPaymentReceived(
    String companyId,
    String orderId,
    double amount,
    String method,
    double orderTotal,
    double totalPaid,
  ) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent()
      ..type = 'payment_received'
      ..visibility = 'customer'  // SEMPRE público (comprovante para cliente)
      ..author = (TimelineAuthor()
        ..id = currentUser?.id
        ..name = currentUser?.name
        ..type = 'collaborator')  // NOVO
      ..data = TimelineEventData()
        ..amount = amount
        ..method = method
        ..orderTotal = orderTotal
        ..totalPaid = totalPaid
        ..remaining = orderTotal - totalPaid
      ..readBy = [currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Marcar todos como lidos
  Future<void> markAllAsRead(
    String companyId,
    String orderId,
    String userId,
  ) async {
    final batch = _firestore.batch();

    final unreadDocs = await _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .get();

    for (final doc in unreadDocs.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
    }

    batch.update(_orderRef(companyId, orderId), {
      'unreadCounts.$userId': 0,
    });

    await batch.commit();
  }

  // --- Helpers Privados ---

  Future<void> _updateLastActivity(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    final currentUserId = Global.currentUser?.id;
    final isMyEvent = event.author?.id == currentUserId;

    String preview = '';
    String icon = event.icon;

    switch (event.type) {
      case 'comment':
        final prefix = isMyEvent ? 'Voce' : event.author?.name ?? '';
        preview = '$prefix: ${_truncate(event.data?.text ?? '', 40)}';
        break;
      case 'photos_added':
        final count = event.data?.photoUrls?.length ?? 0;
        final prefix = isMyEvent ? 'Voce adicionou' : '${event.author?.name} adicionou';
        preview = '$prefix $count foto${count > 1 ? 's' : ''}';
        break;
      case 'status_change':
        final prefix = isMyEvent ? 'Voce' : event.author?.name ?? '';
        preview = '$prefix: ${event.data?.oldStatus} → ${event.data?.newStatus}';
        break;
      case 'service_added':
        preview = 'Servico: ${event.data?.serviceName} +R\$ ${event.data?.serviceValue?.toStringAsFixed(0)}';
        break;
      case 'product_added':
        preview = 'Produto: ${event.data?.productName} (${event.data?.quantity}x)';
        break;
      case 'form_completed':
        final prefix = isMyEvent ? 'Voce concluiu' : '${event.author?.name} concluiu';
        preview = '$prefix ${event.data?.formName}';
        break;
      case 'payment_received':
        preview = 'Pagamento: R\$ ${event.data?.amount?.toStringAsFixed(0)} via ${event.data?.method}';
        break;
      case 'due_date_alert':
        final days = event.data?.daysRemaining ?? 0;
        final isOverdue = event.data?.isOverdue ?? false;
        if (isOverdue) {
          preview = '🔴 Prazo vencido ha ${-days} dias!';
          icon = '🔴';
        } else if (days == 0) {
          preview = '⚠️ Prazo vence hoje!';
        } else {
          preview = '⚠️ Prazo vence em $days dia${days > 1 ? 's' : ''}';
        }
        break;
      case 'assignment_change':
        preview = 'Atribuido a ${event.data?.newAssignee?.name}';
        break;
      case 'order_created':
        preview = 'OS criada';
        break;
      default:
        preview = 'Nova atividade';
    }

    await _orderRef(companyId, orderId).update({
      'lastActivity': {
        'type': event.type,
        'icon': icon,
        'preview': preview,
        'authorId': event.author?.id,
        'authorName': isMyEvent ? 'Voce' : event.author?.name,
        'createdAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> _incrementUnreadCounts(
    String companyId,
    String orderId,
    String? authorId,
  ) async {
    // Buscar colaboradores da empresa
    final collaborators = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .get();

    final updates = <String, dynamic>{};

    for (final collab in collaborators.docs) {
      if (collab.id != authorId) {
        updates['unreadCounts.${collab.id}'] = FieldValue.increment(1);
      }
    }

    if (updates.isNotEmpty) {
      await _orderRef(companyId, orderId).update(updates);
    }
  }

  List<String> _parseMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(text).map((m) => m.group(1) ?? '').toList();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
```

---

## MobX Stores

### TimelineStore

```dart
// lib/mobx/timeline_store.dart

import 'package:mobx/mobx.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/repositories/timeline_repository.dart';
import 'package:praticos/global.dart';

part 'timeline_store.g.dart';

class TimelineStore = _TimelineStore with _$TimelineStore;

abstract class _TimelineStore with Store {
  final TimelineRepository _repository = TimelineRepository();

  @observable
  ObservableStream<List<TimelineEvent>>? timelineStream;

  @observable
  bool isSending = false;

  @observable
  String? error;

  String? _companyId;
  String? _orderId;

  @computed
  List<TimelineEvent> get events => timelineStream?.value ?? [];

  @computed
  Map<String, List<TimelineEvent>> get eventsByDate {
    final grouped = <String, List<TimelineEvent>>{};

    for (final event in events) {
      final dateKey = _formatDateKey(event.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }

  @action
  void init(String companyId, String orderId) {
    _companyId = companyId;
    _orderId = orderId;

    timelineStream = ObservableStream(
      _repository.getTimeline(companyId, orderId),
    );

    // Marcar como lido ao abrir
    _markAllAsRead();
  }

  @action
  Future<void> sendMessage(String text, {List<TimelineAttachment>? attachments}) async {
    if (_companyId == null || _orderId == null) return;
    if (text.trim().isEmpty && (attachments?.isEmpty ?? true)) return;

    isSending = true;
    error = null;

    try {
      await _repository.sendComment(
        _companyId!,
        _orderId!,
        text.trim(),
        attachments: attachments,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
    }
  }

  @action
  Future<void> _markAllAsRead() async {
    if (_companyId == null || _orderId == null) return;

    final userId = Global.currentUser?.id;
    if (userId == null) return;

    await _repository.markAllAsRead(_companyId!, _orderId!, userId);
  }

  @action
  void dispose() {
    timelineStream = null;
  }

  String _formatDateKey(DateTime? date) {
    if (date == null) return 'Desconhecido';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'Hoje';
    if (eventDate == yesterday) return 'Ontem';
    if (now.difference(date).inDays < 7) {
      const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
      return weekdays[date.weekday - 1];
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
```

---

## Integracao com Codigo Existente

### 1. OrderStore - Adicionar Logs

```dart
// Em order_store.dart, modificar metodos existentes:

@action
Future<void> setStatus(String newStatus) async {
  final oldStatus = order?.status;
  order?.status = newStatus;

  await repository.updateItem(companyId!, order!);

  // LOG NA TIMELINE
  if (order?.id != null && oldStatus != newStatus) {
    await TimelineRepository().logStatusChange(
      companyId!,
      order!.id!,
      oldStatus ?? '',
      newStatus,
    );
  }
}

@action
Future<void> addService(OrderService service) async {
  // ... logica existente ...

  // LOG NA TIMELINE
  if (order?.id != null) {
    await TimelineRepository().logServiceAdded(
      companyId!,
      order!.id!,
      service.service?.name ?? '',
      service.value ?? 0,
      description: service.description,
    );
  }
}

@action
Future<void> addProduct(OrderProduct product) async {
  // ... logica existente ...

  // LOG NA TIMELINE
  if (order?.id != null) {
    await TimelineRepository().logProductAdded(
      companyId!,
      order!.id!,
      product.product?.name ?? '',
      product.quantity ?? 1,
      product.unitPrice ?? 0,
    );
  }
}
```

### 2. PhotoService - Log de Fotos

```dart
// Em photo_service.dart ou order_store.dart:

Future<void> uploadPhotos(List<File> photos) async {
  // ... upload existente ...

  // LOG NA TIMELINE
  if (orderId != null && uploadedUrls.isNotEmpty) {
    await TimelineRepository().logPhotosAdded(
      companyId!,
      orderId!,
      uploadedUrls,
    );
  }
}
```

### 3. FormsService - Log de Checklist

```dart
// Em forms_service.dart:

Future<void> completeForm(String companyId, String orderId, OrderForm form) async {
  // ... logica existente ...

  // LOG NA TIMELINE
  await TimelineRepository().logFormCompleted(
    companyId,
    orderId,
    form.title ?? '',
    form.id,
    form.items.length,
  );
}
```

### 4. PaymentService - Log de Pagamento

```dart
// Ao registrar pagamento:

Future<void> registerPayment(Payment payment) async {
  // ... logica existente ...

  // LOG NA TIMELINE
  await TimelineRepository().logPaymentReceived(
    companyId,
    orderId,
    payment.amount,
    payment.method,
    orderTotal,
    totalPaid,
  );
}
```

---

## Atualizacao da Home (Lista de OSs)

### Mudancas no Card

```dart
// Em home.dart, atualizar _buildOrderItem:

Widget _buildOrderItem(Order order, int index, bool isLast, SegmentConfigProvider config) {
  final userId = Global.currentUser?.id;
  final unreadCount = order.getUnreadCount(userId ?? '');
  final hasUnread = unreadCount > 0;
  final lastActivity = order.lastActivity;
  final isAlert = lastActivity?.type == 'due_date_alert';

  return CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: () => _openTimeline(order),  // MUDANCA: abre timeline
    child: Container(
      // ...
      child: Row(
        children: [
          // Thumbnail com indicador de nao lido
          _buildThumbnailWithIndicator(order, hasUnread, isAlert),

          // Conteudo
          Expanded(
            child: Column(
              children: [
                // Linha 1: Numero + Cliente + Hora
                Row(
                  children: [
                    if (hasUnread)
                      Text('🔵 ', style: TextStyle(fontSize: 12)),
                    Text('#${order.number} • ${order.customer?.name}'),
                    Spacer(),
                    Text(_formatTime(lastActivity?.createdAt)),
                  ],
                ),

                // Linha 2: Preview da ultima atividade + Badge
                Row(
                  children: [
                    Text(lastActivity?.icon ?? ''),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lastActivity?.preview ?? _getServicePreview(order),
                        style: TextStyle(
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      _buildBadge(unreadCount),
                  ],
                ),

                // Linha 3: Status + Valor
                Row(
                  children: [
                    _buildStatusDot(order.status),
                    Text(config.getStatus(order.status)),
                    Spacer(),
                    Text(_formatCurrency(order.total)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _openTimeline(Order order) {
  Navigator.of(context, rootNavigator: true).pushNamed(
    '/timeline',  // NOVA ROTA
    arguments: {'order': order},
  );
}
```

### Novo Filtro "Nao Lidas"

```dart
// Em _getFilters, adicionar:

final baseFilters = [
  {'status': l10n.all, 'icon': CupertinoIcons.square_grid_2x2, 'field': null},
  {'status': 'Nao lidas', 'icon': CupertinoIcons.bell_fill, 'field': 'unread'},  // NOVO
  {'status': l10n.delivery, 'field': 'due_date', 'icon': CupertinoIcons.clock},
  // ... demais filtros
];

// No OrderStore, adicionar query:

Future<void> loadUnreadOrders() async {
  final userId = Global.currentUser?.id;
  if (userId == null) return;

  final query = _ordersRef
      .where('unreadCounts.$userId', isGreaterThan: 0)
      .orderBy('unreadCounts.$userId', descending: true)
      .orderBy('lastActivity.createdAt', descending: true);

  // ...
}
```

---

## Cloud Functions

### Alertas de Prazo

```typescript
// functions/src/due_date_alerts.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

export const scheduledDueDateAlerts = functions.pubsub
  .schedule('0 8 * * *')  // 8h todos os dias
  .timeZone('America/Sao_Paulo')
  .onRun(async () => {
    const companies = await db.collection('companies').get();

    for (const company of companies.docs) {
      await checkDueDatesForCompany(company.id);
    }
  });

async function checkDueDatesForCompany(companyId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const in3Days = new Date(today);
  in3Days.setDate(in3Days.getDate() + 3);

  // OSs com prazo nos proximos 3 dias ou vencidas
  const ordersSnap = await db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .where('status', 'not-in', ['done', 'canceled'])
    .where('dueDate', '<=', in3Days)
    .get();

  for (const orderDoc of ordersSnap.docs) {
    const order = orderDoc.data();
    const dueDate = order.dueDate.toDate();

    const diffTime = dueDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    // Evitar alertas duplicados no mesmo dia
    const existingAlert = await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderDoc.id)
      .collection('timeline')
      .where('type', '==', 'due_date_alert')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(today))
      .limit(1)
      .get();

    if (!existingAlert.empty) continue;

    // Criar evento de alerta
    await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderDoc.id)
      .collection('timeline')
      .add({
        type: 'due_date_alert',
        author: null,
        data: {
          dueDate: order.dueDate,
          daysRemaining: diffDays,
          isOverdue: diffDays < 0,
        },
        readBy: [],
        mentions: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isDeleted: false,
      });

    // Atualizar lastActivity
    const icon = diffDays < 0 ? '🔴' : '⚠️';
    const preview = diffDays < 0
      ? `🔴 Prazo vencido ha ${-diffDays} dias!`
      : diffDays === 0
        ? '⚠️ Prazo vence hoje!'
        : `⚠️ Prazo vence em ${diffDays} dias`;

    await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderDoc.id)
      .update({
        'lastActivity': {
          type: 'due_date_alert',
          icon,
          preview,
          authorId: null,
          authorName: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

    // Incrementar unread para todos
    const collaborators = await db
      .collection('companies')
      .doc(companyId)
      .collection('collaborators')
      .get();

    const updates: { [key: string]: any } = {};
    for (const collab of collaborators.docs) {
      updates[`unreadCounts.${collab.id}`] = admin.firestore.FieldValue.increment(1);
    }

    await db
      .collection('companies')
      .doc(companyId)
      .collection('orders')
      .doc(orderDoc.id)
      .update(updates);
  }
}
```

---

## Internationalizacao

### Novas Strings

```json
// lib/l10n/app_pt.arb
{
  "timeline": "Conversa",
  "typeMessage": "Digite uma mensagem...",
  "unread": "Nao lidas",
  "viewDetails": "Ver detalhes",
  "addPhotos": "Adicionar fotos",
  "fillChecklist": "Preencher checklist",
  "muteNotifications": "Silenciar notificacoes",
  "osCreated": "OS criada",
  "statusChanged": "Status alterado",
  "photosAdded": "{count, plural, =1{1 foto adicionada} other{{count} fotos adicionadas}}",
  "serviceAdded": "Servico adicionado",
  "serviceUpdated": "Servico atualizado",
  "serviceRemoved": "Servico removido",
  "productAdded": "Produto adicionado",
  "productUpdated": "Produto atualizado",
  "productRemoved": "Produto removido",
  "checklistCompleted": "Checklist concluido",
  "paymentReceived": "Pagamento recebido",
  "assignedTo": "Atribuido a",
  "dueDateAlert": "Prazo",
  "dueDateChanged": "Entrega alterada",
  "dueTodayAlert": "⚠️ Prazo vence hoje!",
  "dueInDaysAlert": "⚠️ Prazo vence em {count} {count, plural, =1{dia} other{dias}}",
  "overdueAlert": "🔴 Prazo vencido ha {count} {count, plural, =1{dia} other{dias}}!",
  "you": "Voce",
  "system": "Sistema"
}
```

---

## Plano de Implementacao

### Fase 1: Fundacao

| # | Task | Arquivos |
|---|------|----------|
| 1.1 | Model TimelineEvent | `lib/models/timeline_event.dart` |
| 1.2 | Adicionar lastActivity e unreadCounts ao Order | `lib/models/order.dart` |
| 1.3 | TimelineRepository | `lib/repositories/timeline_repository.dart` |
| 1.4 | TimelineStore | `lib/mobx/timeline_store.dart` |
| 1.5 | Tela TimelineScreen | `lib/screens/timeline/timeline_screen.dart` |
| 1.6 | Rota /timeline | `lib/routes.dart` |
| 1.7 | Strings i18n | `lib/l10n/app_*.arb` |

### Fase 2: Integracao Home

| # | Task | Arquivos |
|---|------|----------|
| 2.1 | Atualizar card da OS com preview | `lib/screens/menu_navigation/home.dart` |
| 2.2 | Mudar tap para abrir timeline | `lib/screens/menu_navigation/home.dart` |
| 2.3 | Adicionar filtro "Nao lidas" | `lib/screens/menu_navigation/home.dart` |
| 2.4 | Badge na TabBar | `lib/screens/menu_navigation/navigation_controller.dart` |

### Fase 3: Logs Automaticos

| # | Task | Arquivos |
|---|------|----------|
| 3.1 | Log de mudanca de status | `lib/mobx/order_store.dart` |
| 3.2 | Log de fotos adicionadas | `lib/services/photo_service.dart` |
| 3.3 | Log de servico add/edit/remove | `lib/mobx/order_store.dart` |
| 3.4 | Log de produto add/edit/remove | `lib/mobx/order_store.dart` |
| 3.5 | Log de checklist concluido | `lib/services/forms_service.dart` |
| 3.6 | Log de pagamento | `lib/screens/payment/payment_screen.dart` |

### Fase 4: Alertas e Notificacoes

| # | Task | Arquivos |
|---|------|----------|
| 4.1 | Cloud Function alertas de prazo | `functions/src/due_date_alerts.ts` |
| 4.2 | Push notifications | `lib/services/notification_service.dart` |
| 4.3 | Marcar como lido ao abrir | `lib/mobx/timeline_store.dart` |

### Fase 5: Mencoes

| # | Task | Arquivos |
|---|------|----------|
| 5.1 | Parser de @mentions | `lib/utils/mention_parser.dart` |
| 5.2 | Autocomplete de usuarios | `lib/widgets/mention_autocomplete.dart` |
| 5.3 | Rich text com mentions | `lib/widgets/mention_text.dart` |

---

## Portal do Cliente (Link Mágico)

### Conceito

O cliente final pode acompanhar sua OS através de um **link único** sem precisar instalar app ou criar conta.

```
https://app.praticos.com/t/abc123xyz
                            └── Token único da OS
```

**Benefícios:**
- Zero fricção (sem login, sem app)
- Funciona em qualquer dispositivo
- Fácil de compartilhar via WhatsApp
- Cliente se sente informado e confiante

---

### Fluxo do Link Mágico

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│                 │         │                 │         │                 │
│  Equipe envia   │──────>  │  Cliente clica  │──────>  │  Timeline       │
│  link via Zap   │         │  no link        │         │  (versão client)│
│                 │         │                 │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

---

### UI: Compartilhar com Cliente

Na tela de Timeline (ou menu de ações), botão para compartilhar:

```
┌─────────────────────────────────────────┐
│  🔗 Compartilhar com Cliente            │
├─────────────────────────────────────────┤
│                                         │
│  Link de acompanhamento:                │
│  ┌─────────────────────────────────┐    │
│  │ praticos.app/t/xK9mP2           │ 📋 │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  📱 Enviar via WhatsApp             ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  📋 Copiar link                     ││
│  └─────────────────────────────────────┘│
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Notificar cliente automaticamente:     │
│                                         │
│  ☑️ Quando status mudar                 │
│  ☑️ Quando serviço for concluído        │
│  ☐ Quando houver nova mensagem          │
│                                         │
│  Via:  (•) WhatsApp  ( ) SMS  ( ) Email │
│                                         │
└─────────────────────────────────────────┘
```

### Mensagem Padrão WhatsApp

```
┌─────────────────────────────────────────┐
│  Olá João! 👋                           │
│                                         │
│  Sua OS #1234 está em andamento na      │
│  MecânicaXYZ.                           │
│                                         │
│  📱 Acompanhe em tempo real:            │
│  https://praticos.app/t/xK9mP2          │
│                                         │
│  Qualquer dúvida, responda por aqui     │
│  ou pelo link acima!                    │
└─────────────────────────────────────────┘
```

---

### Timeline do Cliente (Versão Filtrada)

O cliente vê uma versão **filtrada** da timeline, apenas eventos públicos:

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  🔧  MecânicaXYZ                │    │
│  │      OS #1234                   │    │
│  │      Fiat Uno 2015 • ABC-1234   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Status: 🟣 Em andamento                │
│  Previsão: 20/01/2025                   │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│           ┌───────────────┐             │
│           │   15 Jan      │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📋 OS Recebida             │         │
│  │                            │         │
│  │ Serviço: Troca de óleo     │         │
│  │ Veículo: Fiat Uno 2015     │         │
│  │ Previsão: 20/01/2025       │         │
│  └────────────────────────────┘         │
│                              09:00      │
│                                         │
│  ┌────────────────────────────┐         │
│  │ ✅ Orçamento Aprovado      │         │
│  │                            │         │
│  │ Serviços: R$ 280,00        │         │
│  │ Peças: R$ 170,00           │         │
│  │ Total: R$ 450,00           │         │
│  └────────────────────────────┘         │
│                              10:30      │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 🔧 Serviço Iniciado        │         │
│  │                            │         │
│  │ Técnico responsável:       │         │
│  │ Carlos                     │         │
│  └────────────────────────────┘         │
│                              14:00      │
│                                         │
│           ┌───────────────┐             │
│           │     Hoje      │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📷 Fotos do serviço        │         │
│  │                            │         │
│  │ ┌─────────┬─────────┐      │         │
│  │ │         │         │      │         │
│  │ │   img   │   img   │      │         │
│  │ │         │         │      │         │
│  │ └─────────┴─────────┘      │         │
│  │                            │         │
│  │ "Peças antigas removidas"  │         │
│  └────────────────────────────┘         │
│                              09:30      │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │ Bom dia! Quando fica pronto?      │ │
│  └────────────────────────────────────┘ │
│  Você, 10:00                            │
│                                         │
│  ┌────────────────────────────┐         │
│  │ Bom dia João! Fica pronto  │         │
│  │ hoje às 17h, pode buscar!  │         │
│  └────────────────────────────┘         │
│                  MecânicaXYZ, 10:15     │
│                                         │
├─────────────────────────────────────────┤
│  💬  │ Enviar mensagem...      │   ➤    │
└─────────────────────────────────────────┘
```

---

### Visibilidade de Eventos

#### Controle por Tipo de Evento

| Evento | Visível para Cliente? | Observação |
|--------|----------------------|------------|
| OS Criada | ✅ Sempre | Confirmação |
| Status Mudou | ✅ Sempre | Acompanhamento |
| Fotos | ⚠️ Se marcada pública | Toggle ao enviar |
| Comentário Equipe | ⚠️ Se marcado público | Toggle ao enviar |
| Comentário Cliente | ✅ Sempre | Ele enviou |
| Serviço Adicionado | ⚠️ Após aprovação | Evita confusão |
| Produto Adicionado | ⚠️ Após aprovação | Evita confusão |
| Pagamento | ✅ Sempre | Comprovante |
| Checklist | ❌ Nunca | Interno |
| Atribuição | ⚠️ Só nome do técnico | Sem detalhes |
| Alerta de Prazo | ❌ Nunca | Interno |
| @menções | ❌ Nunca | Interno |

#### Toggle de Visibilidade (Equipe)

Ao enviar mensagem ou foto, a equipe escolhe:

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Peças trocadas com sucesso!    │    │
│  │                                 │    │
│  │ [foto_anexada.jpg]              │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Visível para:                          │
│  ┌─────────────────────────────────┐    │
│  │ 🔒 Só equipe    │ 🌐 Cliente ✓ │    │
│  └─────────────────────────────────┘    │
│                                         │
│                              [Enviar]   │
│                                         │
└─────────────────────────────────────────┘
```

**Padrão inteligente:**
- Fotos → 🌐 Cliente (transparência)
- Mensagens → 🔒 Só equipe (segurança)
- Mensagens com "cliente" ou nome → Sugere 🌐

---

### Modelo de Dados

#### Token no Order

```typescript
// Adicionar ao Order
interface Order {
  // ... campos existentes ...

  // Link mágico
  customerToken?: string;           // Token único (gerado uma vez)
  customerNotifications?: {
    enabled: boolean;
    channels: ('whatsapp' | 'sms' | 'email')[];
    events: ('status' | 'completion' | 'message')[];
  };
}
```

#### Visibilidade no TimelineEvent

```typescript
interface TimelineEvent {
  // ... campos existentes ...

  // Visibilidade
  visibility: 'internal' | 'customer';  // Padrão: 'internal'

  // Autor (expandido para incluir cliente)
  author: {
    id: string;
    name: string;
    type: 'collaborator' | 'customer' | 'system';
    photoUrl?: string;
  } | null;
}
```

#### Coleção de Tokens (Index)

```
/customerTokens/{token}/
  ├── companyId: string
  ├── orderId: string
  ├── createdAt: Timestamp
  └── lastAccessedAt: Timestamp
```

---

### Segurança

#### Geração do Token

```typescript
// Gerar token único e curto
function generateCustomerToken(): string {
  // 8 caracteres alphanumeric = 62^8 = 218 trilhões de combinações
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  let token = '';
  for (let i = 0; i < 8; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}
```

**Características:**
- Sem caracteres ambíguos (0/O, 1/l/I)
- 8 caracteres = fácil de digitar se necessário
- Único por OS (não reutilizado)
- Não expira (simplifica UX)

#### Rate Limiting

```typescript
// Cloud Function: Limitar acessos
const MAX_REQUESTS_PER_MINUTE = 30;
const MAX_REQUESTS_PER_DAY = 500;

// Se exceder, retornar 429 Too Many Requests
```

#### Dados Sensíveis

O cliente **NÃO** vê:
- Outros clientes
- Dados financeiros detalhados da empresa
- Conversas internas (@menções)
- Informações de outros técnicos além do nome
- Alertas de prazo
- Histórico de edições de preço

---

### Notificações para o Cliente

#### Via WhatsApp (API Oficial ou Click-to-Chat)

**Opção A: Click-to-Chat (Simples)**
```
https://wa.me/5511999999999?text=Olá!%20Sua%20OS%20%231234...
```

**Opção B: WhatsApp Business API (Escalável)**
```typescript
// Cloud Function
async function notifyCustomerWhatsApp(orderId: string, event: string) {
  const order = await getOrder(orderId);
  const phone = order.customer.phone;
  const token = order.customerToken;

  const templates = {
    status_change: `Sua OS #${order.number} mudou para: ${order.status}. Acompanhe: praticos.app/t/${token}`,
    completion: `Sua OS #${order.number} está pronta! Acompanhe: praticos.app/t/${token}`,
    message: `Nova mensagem na sua OS #${order.number}. Veja: praticos.app/t/${token}`,
  };

  await sendWhatsAppMessage(phone, templates[event]);
}
```

#### Gatilhos de Notificação

| Evento | Notifica Cliente? | Mensagem |
|--------|-------------------|----------|
| Status → Aprovado | ✅ | "Orçamento aprovado!" |
| Status → Em andamento | ✅ | "Serviço iniciado!" |
| Status → Pronto | ✅ | "Pronto para retirada!" |
| Status → Entregue | ✅ | "Obrigado pela preferência!" |
| Nova mensagem pública | ⚠️ Opcional | "Nova mensagem..." |
| Pagamento registrado | ✅ | "Pagamento confirmado!" |

---

### UI: Tela do Cliente (Web)

#### Header

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌───────┐                              │
│  │ LOGO  │  MecânicaXYZ                 │
│  └───────┘  (11) 99999-9999             │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  OS #1234                               │
│  Fiat Uno 2015 • ABC-1234               │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  🟣 Em andamento                │    │
│  │  Previsão: Hoje, 17h            │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

#### Resumo Financeiro (Expandível)

```
┌─────────────────────────────────────────┐
│                                         │
│  💰 Resumo                          ▼   │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ Serviços                            ││
│  │   Troca de óleo          R$ 80,00   ││
│  │   Alinhamento           R$ 100,00   ││
│  │   Balanceamento         R$ 100,00   ││
│  │                                     ││
│  │ Peças                               ││
│  │   Óleo 5W30 (4x)        R$ 200,00   ││
│  │   Filtro de óleo         R$ 35,00   ││
│  │                         ──────────  ││
│  │ Total                   R$ 515,00   ││
│  │                                     ││
│  │ Pago                    R$ 200,00   ││
│  │ Restante                R$ 315,00   ││
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

#### Footer com Ações

```
┌─────────────────────────────────────────┐
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  📞 Ligar para a loja           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │  📍 Ver no mapa                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  Powered by PraticOS                    │
│                                         │
└─────────────────────────────────────────┘
```

---

### Implementação (Fases Adicionais)

#### Fase 6: Portal Cliente MVP

| # | Task | Arquivos |
|---|------|----------|
| 6.1 | Gerar customerToken ao criar OS | `lib/repositories/order_repository.dart` |
| 6.2 | Coleção customerTokens (index) | Firestore |
| 6.3 | Cloud Function: resolveToken | `functions/src/customer_portal.ts` |
| 6.4 | Web page: /t/{token} | `web/customer/` ou hosting separado |
| 6.5 | Timeline filtrada (visibility) | `lib/repositories/timeline_repository.dart` |
| 6.6 | UI: Botão compartilhar | `lib/screens/timeline/share_button.dart` |
| 6.7 | Deep link WhatsApp | `lib/services/share_service.dart` |

#### Fase 7: Interação Cliente

| # | Task | Arquivos |
|---|------|----------|
| 7.1 | Cliente pode comentar | Web + Cloud Function |
| 7.2 | Toggle visibilidade na equipe | `lib/screens/timeline/message_input.dart` |
| 7.3 | Push notification (PWA) | Service Worker |
| 7.4 | Notificação WhatsApp automática | Cloud Function + API |

---

### Métricas de Sucesso

| Métrica | Como Medir | Meta |
|---------|------------|------|
| Taxa de abertura | Links clicados / enviados | > 70% |
| Engajamento | Clientes que comentam | > 30% |
| Redução WhatsApp | Mensagens no app vs fora | > 50% no app |
| NPS implícito | Clientes que voltam | Crescimento |

---

## Otimizações e Pontos de Atenção

### 1. Otimização de Leitura (Firestore)

Para o Portal do Cliente (Web), a performance é crítica. O cliente abre o link e espera ver o status imediatamente.

**Problema Potencial:**
Se uma OS tiver 50 eventos internos e 2 públicos, baixar a collection inteira e filtrar no cliente é desperdício (custo e dados móveis).

**Solução: Índice Composto**

Criar índice no Firestore Console:

```
Collection: companies/{companyId}/orders/{orderId}/timeline
Fields:
  - visibility (ASC)
  - createdAt (DESC)
```

**Query Otimizada para Cliente:**

```dart
// Cliente vê apenas eventos públicos
_timelineRef(companyId, orderId)
  .where('visibility', isEqualTo: 'customer')
  .orderBy('createdAt', descending: false)
```

**Query para Equipe (todos os eventos):**

```dart
// Equipe vê tudo
_timelineRef(companyId, orderId)
  .where('isDeleted', isEqualTo: false)
  .orderBy('createdAt', descending: false)
```

> ⚠️ **Importante:** O índice garante que o cliente baixe **apenas** o que pode ver, economizando reads do Firestore e dados do usuário.

---

### 2. Otimização de Notificações (Redução de Ruído)

Com o cliente participando, o volume de notificações aumenta. É preciso lógica inteligente.

#### Matriz de Notificação

| Quem enviou | Tipo | Quem recebe notificação |
|-------------|------|-------------------------|
| **Cliente** | Mensagem | Apenas `assignedTo` + `createdBy` |
| **Técnico** | Interno (🔒) | Participantes internos |
| **Técnico** | Público (🌐) | Equipe (push) + Cliente (WhatsApp/SMS) |
| **Sistema** | Alerta prazo | Apenas `assignedTo` + `createdBy` |

#### Lógica de Notificação

```typescript
async function notifyOnNewEvent(event: TimelineEvent, order: Order) {
  const recipients: string[] = [];

  if (event.author?.type === 'customer') {
    // Cliente falou → notificar responsável e criador
    if (order.assignedTo?.id) recipients.push(order.assignedTo.id);
    if (order.createdBy?.id) recipients.push(order.createdBy.id);

    // Push para equipe
    await sendPushToUsers(recipients, {
      title: `OS #${order.number}`,
      body: `${order.customer?.name}: ${truncate(event.data?.text, 50)}`,
    });

  } else if (event.visibility === 'customer') {
    // Técnico falou público → notificar equipe + cliente

    // 1. Push para equipe (exceto autor)
    const teamRecipients = await getCompanyCollaborators(order.company.id);
    await sendPushToUsers(
      teamRecipients.filter(id => id !== event.author?.id),
      { title: `OS #${order.number}`, body: event.data?.text }
    );

    // 2. WhatsApp/SMS para cliente
    if (order.customerNotifications?.enabled) {
      await notifyCustomerExternal(order, event);
    }

  } else {
    // Interno → notificar apenas equipe (lógica existente)
    await notifyInternalParticipants(event, order);
  }
}
```

#### Evitar Spam para o Cliente

```typescript
// Debounce: Agrupar mensagens em janela de 5 minutos
const CUSTOMER_NOTIFICATION_DEBOUNCE = 5 * 60 * 1000; // 5 min

async function notifyCustomerExternal(order: Order, event: TimelineEvent) {
  const lastNotification = order.customerNotifications?.lastSentAt;
  const now = Date.now();

  if (lastNotification && (now - lastNotification) < CUSTOMER_NOTIFICATION_DEBOUNCE) {
    // Já notificou recentemente, agendar batch
    await scheduleCustomerNotification(order.id, event.id);
    return;
  }

  // Enviar agora
  await sendWhatsAppMessage(order.customer?.phone, {
    template: 'new_message',
    params: { orderNumber: order.number, link: getCustomerLink(order) }
  });

  // Atualizar timestamp
  await updateOrder(order.id, {
    'customerNotifications.lastSentAt': now
  });
}
```

---

### 3. UX de Envio Híbrido (Input Bar)

Na timeline, o técnico precisa de **clareza absoluta** sobre quem vai ler a mensagem.

#### Design do Toggle de Visibilidade

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Estado: INTERNO (padrão)                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  📷  │ Mensagem...                      │ 🔒 │  ➤  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                              ↑              │
│                                         Tap para alternar   │
│                                                             │
│  Estado: PÚBLICO (cliente vê)                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  📷  │ Mensagem...                      │ 🌐 │  ➤  │  │
│  └───────────────────────────────────────────────────────┘  │
│         │                                   │               │
│         └─ Borda colorida (ex: verde)       └─ Ícone muda   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Feedback Visual na Timeline

```
┌─────────────────────────────────────────┐
│                                         │
│  Mensagem INTERNA (só equipe):          │
│  ┌────────────────────────────┐         │
│  │ Peça atrasada, avisar      │         │
│  │ o cliente amanhã           │         │
│  └────────────────────────────┘         │
│  Você, 10:35                        ✓✓  │
│                                         │
│  Mensagem PÚBLICA (cliente vê):         │
│  ┌────────────────────────────┐         │
│  │ 🌐 Bom dia! Seu veículo   │         │◄── Indicador
│  │ está pronto para retirada! │         │
│  └────────────────────────────┘         │
│  Você, 10:40                   🌐   ✓✓  │◄── Badge público
│                                         │
└─────────────────────────────────────────┘
```

#### Widget de Indicador

```dart
Widget _buildVisibilityIndicator(TimelineEvent event) {
  if (event.visibility != 'customer') return SizedBox.shrink();

  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: CupertinoColors.systemGreen.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.globe, size: 12, color: CupertinoColors.systemGreen),
        SizedBox(width: 4),
        Text(
          'Cliente vê',
          style: TextStyle(
            fontSize: 10,
            color: CupertinoColors.systemGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

#### Confirmação para Mensagem Pública

Para evitar o clássico "falar mal do cliente para o cliente":

```
┌─────────────────────────────────────────┐
│                                         │
│  🌐 Enviar para o Cliente?              │
│                                         │
│  Esta mensagem será visível para        │
│  João Silva (cliente da OS).            │
│                                         │
│  "Bom dia! Seu veículo está pronto      │
│  para retirada!"                        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │        Enviar para Cliente      │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │        Enviar só p/ Equipe      │    │
│  └─────────────────────────────────┘    │
│                                         │
│              Cancelar                   │
│                                         │
└─────────────────────────────────────────┘
```

**Quando mostrar confirmação:**
- Primeira mensagem pública do usuário (educativo)
- Configurável nas preferências do usuário
- Opcional: sempre mostrar (segurança máxima)

---

### 4. Índices Firestore Necessários

Lista completa de índices compostos para criar:

```
Collection: companies/{companyId}/orders/{orderId}/timeline

Índice 1 - Query da Equipe:
  - isDeleted (ASC)
  - createdAt (ASC)

Índice 2 - Query do Cliente:
  - visibility (ASC)
  - createdAt (ASC)

Índice 3 - Não lidos por usuário (se usar subcollection):
  - readBy (ARRAY_CONTAINS)
  - createdAt (DESC)
```

```
Collection: companies/{companyId}/orders

Índice 4 - Lista com não lidos:
  - status (ASC)
  - lastActivity.createdAt (DESC)

Índice 5 - Filtro não lidas:
  - unreadCounts.{userId} (ASC) → Precisa ser criado dinamicamente
```

> 💡 **Dica:** O índice 5 pode ser substituído por uma query client-side se o número de OSs ativas for pequeno (< 100).

---

### Validação do Modelo

Com essas otimizações, o modelo V3 resolve:

| Objetivo | Solução | Status |
|----------|---------|--------|
| **Engajamento Interno** | Timeline unificada substitui WhatsApp da equipe | ✅ |
| **Transparência Externa** | Link mágico permite cliente acompanhar sem login | ✅ |
| **Segurança** | Toggle de visibilidade + confirmação + segregação de dados | ✅ |
| **Performance** | Índices compostos garantem queries eficientes | ✅ |
| **Redução de Ruído** | Lógica inteligente de notificação por contexto | ✅ |

---

## Resumo

Esta abordagem unificada:

1. **Nao adiciona abas** - usa a estrutura existente
2. **Muda o tap** - OS abre timeline em vez de detalhes
3. **Detalhes acessiveis** - via botao (i) no header
4. **Preview na lista** - mostra ultima atividade
5. **Indicadores claros** - dot azul, badge, ✓✓
6. **Todos os eventos** - comentarios, fotos, status, servicos, etc.
7. **Substitui WhatsApp** - comunicacao dentro do app
