# Documentação Técnica: Bot Centralizado PraticOS (via WhatsApp/Clawdbot)

## 1. Visão Geral
O objetivo é transformar o PraticOS em um serviço acessível via WhatsApp, focado em prestadores de serviços (mecânicos, técnicos de celular, etc.), especialmente aqueles com dificuldade em utilizar interfaces complexas. O bot atuará como um assistente de gestão conversacional.

## 2. Arquitetura de Sistema
- **Plataforma de Mensagens:** Clawdbot (Gateway Multi-tenant).
- **Backend:** Firebase (Firestore + Cloud Functions).
- **Interface de Usuário (UX):** Baseada em conversação (texto/botões/números/áudio/fotos).

## 3. Funcionalidades Principais
### 3.1 Abertura de OS Assistida
- Fluxo guiado por botões (Telegram/Discord) ou menus numéricos (WhatsApp).
- Suporte para anexo de fotos e transcrição de áudio para descrição de problemas.
- Integração com contatos do dispositivo.

### 3.2 Fechamento de Caixa Proativo
- O usuário define o horário de encerramento do expediente no seu perfil.
- O bot envia automaticamente um resumo do faturamento e tarefas concluídas no horário definido.

### 3.3 Gestão de Cobrança Assistida
- O bot identifica OSs entregues sem pagamento registrado.
- O bot solicita permissão ao dono da oficina para enviar uma mensagem de cobrança amigável ao cliente.

### 3.4 Compartilhamento de Contatos (Nativo)
- O bot deve ser capaz de enviar contatos de clientes no formato nativo do WhatsApp (.vcf/vCard interpretado).
- **Nota Técnica:** Não enviar como texto puro; a Skill deve utilizar a função de mensagem de tipo `contact` do gateway para garantir que o botão "Salvar Contato" apareça para o usuário, facilitando a comunicação direta.

### 3.5 Gestão de Equipes (Multi-user)
- **Convites:** Donos podem gerar tokens de convite para colaboradores.
- **Hierarquia:** Separação de visibilidade entre 'Admins' (visão total/financeira) e 'Técnicos' (visão operacional).
- **Audit:** Todas as ações via Bot registram o `authorId` para rastreabilidade de quem abriu ou alterou cada OS dentro da mesma empresa.

### 3.6 Onboarding Híbrido e Unificação de Contas
- **Vínculo Progressivo:** O colaborador pode iniciar o uso apenas via WhatsApp (identificado pelo número no Firestore sob o `empresaId`).
- **Sincronização com Firebase Auth:** Ao instalar o App Flutter posteriormente, o sistema realiza o merge do `UID` do Firebase Auth com o registro de WhatsApp existente através de uma validação de posse (SMS ou código via Bot).
- **Criação Provisória via Admin SDK:** Caso o usuário inicie pelo Bot, o backend utilizará o `admin.auth().createUser()` para gerar um UID oficial baseado no número de telefone, garantindo que o `ID no Firestore == UID no Auth` desde o primeiro contato.
- **Consistência de Dados:** Garante que o histórico gerado no WhatsApp esteja disponível no App no primeiro login do colaborador.

### 3.7 Gestão de Memória (Visão de Futuro)
- **Memória Unificada Multicanal:** Unificação do contexto do usuário (preferências, histórico pendente) independente do canal utilizado, via Token de Sessão persistente.
- **Memória Coletiva (Tenant Memory):** Compartilhamento de processos e conhecimentos operacionais entre membros da mesma equipe (ex: dicas de reparo e histórico de clientes compartilhados na oficina).

## 4. Integração e Segurança
### 4.1 Protocolo de Vinculação via Token (Onboarding)
1. O usuário logado no App PraticOS (Web/Mobile) gera um token de ativação.
2. O sistema fornece um link `wa.me` com o token pré-preenchido.
3. O Clawdbot recebe o token, identifica o `UID` do Firebase associado e vincula o `authorId` (número do WhatsApp) ao perfil do usuário no Firestore.

### 4.2 Isolamento de Dados (Multi-tenancy)
- Cada conversa no WhatsApp é tratada como uma `SessionKey` única e isolada.
- O contexto da empresa (IDs, clientes, histórico) é injetado na sessão somente após a identificação segura do número de telefone.

### 4.3 Defesa contra Prompt Injection
- **IA como Interface:** A IA é responsável apenas pela coleta e formatação dos dados.
- **API como Validadora:** Todas as ações de escrita (salvar/deletar) são feitas via chamadas para Firebase Cloud Functions, que realizam a sanitização e validação rígida dos dados recebidos da IA.
- **Sandboxing:** O Clawdbot garante que um usuário não tenha acesso às instruções ou dados de outras sessões.

## 5. Endpoints da API (Firebase Cloud Functions)

Para suportar o Bot Central, a API em Node.js (TypeScript) deve implementar os seguintes endpoints iniciais:

### 5.1 `POST /linkWhatsApp` (Vínculo de Conta)
- **Objetivo:** Realizar o "handshake" entre o número de WhatsApp e o UID do Firebase.
- **Payload:** `{ token: string, whatsappNumber: string }`
- **Ação:** Valida o token temporário e salva o `whatsappNumber` no documento do usuário no Firestore.

### 5.2 `POST /createOrder` (Abertura de OS)
- **Objetivo:** Registrar uma nova Ordem de Serviço via Bot.
- **Payload:** `{ uid: string, cliente: object, veiculo: object, servico: string, valor: number, previsao: string, fotos: string[] }`
- **Ação:** Cria o documento na sub-coleção de ordens do tenant e retorna o ID da OS gerada.

### 5.3 `GET /listOrders` (Consulta e Filtros)
- **Objetivo:** Recuperar histórico ou pendências para exibição no chat.
- **Params:** `uid: string`, `status?: string`, `clienteNome?: string`, `dataEntrega?: string`
- **Ação:** Retorna uma lista de OSs filtradas (ex: "entregas para hoje" ou "histórico do Ronaldo").

### 5.4 `POST /updateOrderStatus` (Fluxo de Trabalho)
- **Objetivo:** Atualizar o estágio da OS (Pronto, Entregue, Pago).
- **Payload:** `{ uid: string, orderId: string, status: string }`
- **Ação:** Atualiza o status e pode disparar notificações automáticas para o cliente via WhatsApp.

### 5.5 `GET /getFinancialSummary` (Inteligência Financeira)
- **Objetivo:** Gerar os dados para o "Resumo do Dia/Semana/Mês".
- **Params:** `uid: string`, `periodo: string` (daily|weekly|monthly)
- **Ação:** Realiza a agregação de valores (faturamento, lucro, pendências) e retorna os KPIs consolidados.

## 6. Desenvolvimento da Skill (A Inteligência do Bot)

A Skill será o "cérebro" dentro do Clawdbot que orquestra a conversa com o prestador de serviço.

### 6.1 Definição de Persona
- **Nome:** Prático 🌌
- **Vibe:** Assistente operacional focado em produtividade. Fala a língua do mecânico/técnico.
- **Regra de Ouro:** Ser o mais objetivo possível. No WhatsApp, usar listas numeradas para menus.
- **Idioma e Voz:** Todas as respostas (texto e áudio) devem ser estritamente em **Português Brasileiro (PT-BR)**. O tom deve ser profissional, mas acessível (estilo Florianópolis). Nunca utilizar síntese de voz em inglês.

### 6.2 Lógica de Fluxo de Diálogo e Auto-Aprendizado
1. **Identificação e Vínculo de Token:** 
   - No primeiro "Oi", a Skill extrai o `authorId` (WhatsApp ID).
   - A Skill consulta o backend para verificar se esse `authorId` já possui um `authToken` vinculado.
   - O `SessionID` do Clawdbot é então associado ao `authToken` do usuário no Firebase, permitindo que todas as requisições subsequentes (como a criação de OS) sejam autenticadas automaticamente no contexto daquele usuário específico.
2. **Ciclo de Auto-Aprendizado (Memory Maintenance):**
   - A Skill deve monitorar falhas de API ou dificuldades de entendimento do usuário.
   - **Reflexão Automática:** Ao final de cada interação bem-sucedida após um erro, o bot deve registrar a solução na `Tenant Memory`.
   - **Consolidação:** Uma tarefa diária deve revisar os logs e atualizar o `MEMORY.md` global com novos padrões técnicos identificados (ex: variações de headers ou gírias de novos segmentos).
3. **Contextualização:** Ajusta o vocabulário baseando-se no segmento retornado (Labels Traduzidas).
3. **Coleta Progressiva:** Salva cada resposta na memória da sessão (`SessionKey`) até completar o formulário dinâmico.
4. **Finalização:** Dispara os dados para `/createOrder` incluindo o `SessionID` no header, que o backend resolve para o usuário correto.

### 6.3 Tratamento de Mídia
- **Fotos:** Sempre que uma foto é enviada durante a abertura de uma OS, a Skill deve capturar o link temporário do gateway e repassá-lo para a API para armazenamento no Firebase Storage.
- **Áudio:** Utilizar a transcrição nativa da IA para preencher campos de texto longos (ex: descrição do problema).

## 7. Próximos Passos (Implementação)
1. Criar Cloud Functions no Firebase para as operações básicas de OS.
2. Configurar o servidor Clawdbot em uma instância VPS.
3. Desenvolver a Skill de integração entre Clawdbot e as Cloud Functions.
4. Implementar o fluxo de "Link Mágico" no App Web para vinculação de conta.
