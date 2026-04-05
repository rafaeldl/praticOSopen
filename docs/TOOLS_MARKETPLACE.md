# Tools & Local Marketplace

> **Status:** Ideação / Refinamento
> **Última atualização:** 2026-02-27

## Visão Geral

Transformar o PraticOS de um app de gestão de OS em um **hub completo do profissional técnico**, adicionando:

1. **Ferramentas técnicas** - calculadoras e utilitários do dia a dia
2. **Marketplace local** - diretório de fornecedores de peças/produtos
3. **Recomendação contextual** - conectar ferramenta/OS ao fornecedor certo
4. **Conteúdo patrocinado** - ferramentas e dicas branded por fornecedores

O profissional abre o PraticOS pra trabalhar. Além de gerenciar OS, encontra ferramentas úteis do ofício e, quando precisa de peça/material, encontra fornecedores locais ali mesmo.

---

## Pilar 1: Ferramentas Técnicas

Calculadoras e utilitários que o profissional usa no dia a dia. O valor é **reter o profissional no app** e gerar dados de comportamento/intenção.

### Por que isso importa pra monetização

- Profissional que usa calculadora de BTU provavelmente vai precisar comprar um ar-condicionado
- Profissional que calcula markup está precificando um serviço, pode precisar de peças
- Cada uso de ferramenta é um **sinal de intenção de compra**

### Ferramentas Universais (todos os segmentos)

| Ferramenta | Descrição |
|------------|-----------|
| Calculadora de markup / margem | Calcula preço de venda a partir de custo + margem desejada |
| Calculadora de hora técnica | Calcula custo/hora considerando despesas fixas, impostos, lucro |
| Conversor de unidades | Medidas, temperatura, pressão, elétrica |

### Ferramentas por Segmento

**Mecânica Automotiva**

| Ferramenta | Descrição |
|------------|-----------|
| Calculadora de torque | Valores de referência por modelo/motor |
| Tabela de viscosidade de óleo | Recomendação por motor e clima |
| Calculadora de consumo | km/l e custo por km |
| Conversor polegadas/mm, PSI/bar | Unidades comuns da mecânica |
| Referência tabela FIPE | Consulta de preço de veículos |

**Eletrônica / Assistência Técnica**

| Ferramenta | Descrição |
|------------|-----------|
| Calculadora de resistores | Código de cores → valor |
| Conversor elétrico | V, A, W, Ohm (Lei de Ohm interativa) |
| Calculadora de nobreak | Tempo de backup por carga |
| Tabela de baterias | Compatibilidade por modelo de dispositivo |

**Refrigeração / HVAC**

| Ferramenta | Descrição |
|------------|-----------|
| Calculadora de BTU | Dimensionamento por ambiente |
| Tabela de gás refrigerante | Tipo de gás por modelo de equipamento |
| Calculadora de carga térmica | Cálculo detalhado por variáveis do ambiente |
| Conversor de temperatura | Celsius/Fahrenheit/Kelvin |

**Construção / Manutenção Predial**

| Ferramenta | Descrição |
|------------|-----------|
| Calculadora de materiais | Tinta por m², piso, argamassa, cimento |
| Calculadora elétrica | Bitola de fio por carga |
| Calculadora hidráulica | Dimensionamento de tubulação |

---

## Pilar 2: Marketplace Local de Peças/Produtos

Conectar o profissional ao fornecedor local. Modelo "páginas amarelas inteligentes".

### Diferencial vs. Google / Mercado Livre

- **Filtrado pelo segmento** do profissional (relevância alta)
- **Integrado ao fluxo de trabalho** (está na OS, precisa de peça, acha ali)
- **Avaliações de profissionais** pra profissionais (confiança do nicho)
- **Histórico vinculado às OS** (rastreabilidade de fornecimento)

### Níveis de Fornecedor

| Nível | O que ganha | Custo |
|-------|-------------|-------|
| **Básico** | Listagem simples (nome, contato, categorias de produtos) | Grátis |
| **Destaque** | Aparece primeiro, logo, link direto WhatsApp, selo verificado | Fee mensal fixo |
| **Premium** | Tudo do Destaque + recomendação contextual nas ferramentas e OS | Fee mensal + CPA por lead |

### Cadastro de Fornecedor

**Dados do fornecedor:**
- Nome da empresa, CNPJ
- Endereço + coordenadas (geolocalização)
- Categorias de produtos/serviços
- Segmentos atendidos
- Canais de contato (WhatsApp, telefone, site)
- Horário de funcionamento
- Área de entrega/atendimento
- Logo e fotos (nível Destaque+)

**Dados de produto (nível Premium):**
- Nome, categoria, marca
- Faixa de preço (opcional)
- Disponibilidade
- Compatibilidade (modelo/equipamento)

### Métricas para Fornecedores

- **Impressões**: quantos profissionais viram a listagem
- **Cliques**: quantos interagiram (abriram perfil, viram produtos)
- **Leads**: quantos entraram em contato (WhatsApp, ligação)
- **Avaliações**: nota e comentários de profissionais
- **Conversões**: se integração de pedido existir

---

## Pilar 3: Recomendação Contextual

A conexão entre ferramentas/OS e fornecedores. É onde o maior valor é gerado.

### Recomendação pós-cálculo (nas ferramentas)

```
Profissional calcula BTU → resultado: 12.000 BTU
    ↓
"Fornecedores de ar-condicionado 12.000 BTU perto de você:"
    ↓
[Logo Fornecedor A] ★4.8 - 2.3km - "Entrega hoje"
[Logo Fornecedor B] ★4.5 - 5.1km - "10% desconto PraticOS"
    ↓
Toque → Abre WhatsApp / Liga / Abre mapa
```

### Recomendação na OS (mais avançado)

- Profissional adiciona serviço "Troca de compressor" na OS
- App sugere: "Precisa de compressor? Veja fornecedores"
- Ou: "Compressor X em promoção na [Fornecedor] - R$ 890"

### Recomendação por histórico

- Profissional comprou peça X há 6 meses
- Se peça tem vida útil média conhecida, sugerir reposição
- "Seus clientes que trocaram filtro há 6 meses podem precisar de nova troca"

---

## Pilar 4: Conteúdo Patrocinado / Branded Tools

Menos intrusivo que anúncio, mais valor percebido.

### Formatos

| Formato | Exemplo | Modelo de cobrança |
|---------|---------|-------------------|
| Ferramenta patrocinada | "Calculadora de BTU - by Elgin" | Fee mensal fixo |
| Tutorial técnico | "Como dimensionar tubulação - [Fornecedor]" | Fee por conteúdo |
| Dica sazonal | "Prepare-se pro verão: checklist preventivo - [Marca]" | Fee por campanha |
| Banner contextual | Banner discreto no resultado da ferramenta | CPM ou fee fixo |

### Regras de branded content

- Sempre útil pro profissional (conteúdo real, não propaganda pura)
- Identificado como patrocinado (transparência)
- Máximo 1 patrocinador por ferramenta
- Profissional pode desativar recomendações (opt-out)

---

## Modelo de Receita

```
                    ┌─────────────────────────┐
                    │   Ferramentas Técnicas   │  ← Engajamento
                    │   (Grátis pro usuário)   │    + dados de intenção
                    └───────────┬─────────────┘
                                │
                                ▼
                ┌───────────────────────────────────┐
                │      Marketplace Local             │
                │                                    │
                │  Básico (grátis) → popular base    │
                │  Destaque → fee mensal             │
                │  Premium → fee mensal + CPA        │
                └───────────────┬───────────────────┘
                                │
                                ▼
                ┌───────────────────────────────────┐
                │      Branded Content               │
                │                                    │
                │  Ferramentas patrocinadas → mensal │
                │  Tutoriais/dicas → por conteúdo    │
                └───────────────────────────────────┘
```

### Projeção simplificada (exemplo)

| Fonte | Premissa | Receita mensal |
|-------|----------|----------------|
| Fornecedores Destaque | 50 fornecedores × R$ 99/mês | R$ 4.950 |
| Fornecedores Premium | 10 fornecedores × R$ 299/mês + CPA | R$ 2.990 + variável |
| Branded Tools | 5 patrocinadores × R$ 499/mês | R$ 2.495 |
| **Total estimado** | | **~R$ 10.400/mês** |

*Valores ilustrativos para validação. Ajustar conforme mercado real.*

---

## Modelos de Go-to-Market

Existem duas abordagens em avaliação para lançar essa iniciativa. A decisão depende do momento do produto e recursos disponíveis.

### Modelo A: Product-First (Ferramentas → Fornecedores)

Começa pelas ferramentas pra gerar engajamento, depois atrai fornecedores com base nos dados de uso.

```
Ferramentas grátis → Profissionais engajam → Dados de uso
    → Abordagem comercial: "X profissionais usam, quer ser recomendado?"
        → Fornecedores pagam
```

**Quando faz sentido:**
- Já tem base razoável de usuários ativos
- Quer validar engajamento antes de envolver terceiros
- Time pequeno, foco em produto

**Risco:** Construir ferramentas que ninguém usa. Sem fornecedores, a experiência é incompleta.

### Modelo B: Fornecedor como Canal de Aquisição

Começa pelos fornecedores, que divulgam o app pros profissionais (seus próprios clientes).

```
Parceria com fornecedores locais → Fornecedor divulga o app
    → Profissionais adotam o PraticOS → Fornecedor ganha visibilidade
        → Mais profissionais → Mais valor pro fornecedor
```

**Proposta pro fornecedor:**
- "Cadastre sua loja no PraticOS gratuitamente"
- "Seus clientes (os profissionais) vão te encontrar direto pelo app"
- "Divulgue o app pros seus clientes e ganhe destaque"

**O que o fornecedor ganha:**
- Visibilidade pra profissionais da região (canal novo, sem custo)
- Quanto mais divulga, mais profissionais usam, mais ele aparece
- Selo "Parceiro Fundador" (exclusividade temporal, reconhecimento)

**O que o PraticOS ganha:**
- Cada fornecedor vira um "vendedor" do app
- Aquisição orgânica via quem já tem relacionamento com o público-alvo
- Base de fornecedores já populada quando os profissionais chegarem

**Kit de divulgação pro fornecedor:**
- Adesivo de vitrine ("Estamos no PraticOS")
- QR code personalizado (rastreia quantos vieram por ele)
- Posts prontos pra redes sociais
- Dashboard mostrando quantos profissionais vieram pela indicação dele

**Incentivos:**
- Ranking: fornecedores que mais indicam ganham destaque permanente
- Primeiros N fornecedores ganham selo "Parceiro Fundador"
- Acesso antecipado a features premium

**Quando faz sentido:**
- Base de usuários ainda pequena
- Precisa de canal de aquisição sem custo de marketing
- Quer validar o marketplace e as ferramentas ao mesmo tempo

**Risco:** Depende do fornecedor realmente divulgar. Precisa de abordagem comercial ativa.

### Modelo C: Híbrido

Lançar ferramentas básicas e ao mesmo tempo abordar fornecedores locais. As ferramentas dão um motivo pro profissional abrir o app além da OS, e o fornecedor dá volume de novos usuários.

**Quando faz sentido:**
- Consegue executar as duas frentes em paralelo
- Quer reduzir o risco de depender de um único modelo

---

## Roadmap de Execução

*O roadmap abaixo segue o Modelo A (Product-First). Se o Modelo B ou C for escolhido, as fases se reorganizam - o diretório de fornecedores e o kit de divulgação entram na Fase 0.*

### Fase 0 - Ferramentas Standalone

**Objetivo:** Validar engajamento dos profissionais com ferramentas.

**Escopo:**
- Nova aba "Ferramentas" no menu principal do app
- 3-5 calculadoras universais (markup, hora técnica, conversores)
- 2-3 calculadoras do segmento mais ativo
- Analytics de uso por ferramenta

**Métricas de sucesso:**
- % de usuários ativos que usam ferramentas
- Frequência de uso por ferramenta
- Ferramentas mais pedidas (feedback)

**Resultado esperado:** Dados de engajamento pra validar a tese e priorizar próximas ferramentas.

### Fase 1 - Diretório de Fornecedores

**Objetivo:** Criar base inicial de fornecedores e validar busca.

**Escopo:**
- Cadastro de fornecedores (curadoria manual ou auto-serviço - decisão pendente)
- Busca por categoria + região
- Perfil do fornecedor (contato, produtos, avaliação)
- Nível Básico (grátis) pra popular a base

**Métricas de sucesso:**
- Número de fornecedores cadastrados
- Buscas realizadas por profissionais
- Contatos gerados (cliques em WhatsApp/telefone)

**Resultado esperado:** Base de fornecedores populada e primeiros dados de demanda.

### Fase 2 - Conexão Ferramentas ↔ Fornecedores

**Objetivo:** Monetizar via recomendação contextual.

**Escopo:**
- Recomendação pós-cálculo (ferramentas → fornecedores)
- Níveis Destaque e Premium pra fornecedores
- Dashboard do fornecedor (impressões, cliques, leads)
- Sistema de avaliação de fornecedores

**Métricas de sucesso:**
- Taxa de conversão ferramenta → contato com fornecedor
- Receita mensal de fornecedores pagantes
- NPS dos profissionais com recomendações

**Resultado esperado:** Primeira receita recorrente do marketplace.

### Fase 3 - Recomendação na OS + Branded Content

**Objetivo:** Expandir pontos de contato e receita.

**Escopo:**
- Sugestões de fornecedores baseadas nos serviços da OS
- Catálogo de produtos dos fornecedores Premium
- Ferramentas patrocinadas (branded tools)
- Conteúdo técnico patrocinado

**Métricas de sucesso:**
- Receita por branded content
- Engajamento com conteúdo patrocinado
- Retenção de fornecedores pagantes

**Resultado esperado:** Modelo de receita diversificado e sustentável.

---

## Decisões Pendentes

| # | Decisão | Opções | Impacto |
|---|---------|--------|---------|
| 1 | **Modelo go-to-market** | **A (Product-First) / B (Fornecedor como canal) / C (Híbrido)** | **Define toda a estratégia de lançamento e prioridades** |
| 2 | Escopo geográfico inicial | Cidade específica / Regional / Nacional | Define estratégia de aquisição de fornecedores |
| 3 | Cadastro de fornecedores | Auto-serviço / Curadoria manual / Híbrido | Define velocidade de crescimento e qualidade |
| 4 | Modelo de transação | Só conectar (lead gen) / Intermediar pagamento | Define complexidade técnica e regulatória |
| 5 | Segmento prioritário | Mecânica / Eletrônica / Refrigeração / Outro | Define quais ferramentas construir primeiro |
| 6 | Ferramentas offline | Sim (todas offline) / Híbrido (calculadoras offline, marketplace online) | Define arquitetura técnica |
| 7 | Geolocalização | GPS em tempo real / Cidade cadastrada / Raio configurável | Define precisão das recomendações |

---

## Ideias Complementares (Brainstorm)

As ideias abaixo expandem o ecossistema além de ferramentas e marketplace. Cada uma pode ser uma fase futura ou um produto separado. Nenhuma está decidida - são oportunidades a explorar.

### Comunidade de Profissionais

Hoje o profissional trabalha isolado. O app poderia criar uma rede entre profissionais do mesmo segmento ou região.

**Indicação de serviços entre profissionais:**
- Mecânico recebe pedido de elétrica → indica eletricista pelo app
- Quem indica ganha crédito/pontos por indicação convertida
- Cria um ciclo de colaboração em vez de competição

**Fórum técnico por segmento:**
- Perguntas e respostas rápidas ("alguém já trocou compressor do modelo X?")
- Respostas validadas pela comunidade (upvote)
- Profissionais com mais respostas ganham reputação

**Banco de profissionais para emergência:**
- "Preciso de um técnico pra cobrir amanhã" → profissionais disponíveis na região respondem
- Útil pra férias, excesso de demanda, especialidades que o profissional não cobre

**Por que isso importa:**
- Cria efeito de rede (quanto mais profissionais, mais valioso pra cada um)
- Fornecedores adorariam patrocinar uma comunidade ativa
- Aumenta retenção - profissional não sai porque perderia a rede

---

### Integração com Distribuidores / Catálogo de Peças

Indo além do diretório simples de fornecedores, criar um catálogo integrado.

**Busca de peça por código/modelo:**
- Profissional digita código da peça ou modelo do equipamento
- Vê onde comprar perto dele, com preço e disponibilidade
- Comparação de preço entre fornecedores

**Alerta de preço:**
- "Me avise quando o compressor X baixar de R$ 800"
- Profissional cadastra itens que compra com frequência
- Fornecedor pode criar promoções direcionadas

**Histórico de compras vinculado à OS:**
- Sabe exatamente que peça usou em cada serviço
- Útil pra garantia ("peça instalada em 15/01, garantia até 15/07")
- Relatório de custos por fornecedor

**Lista de compras automática:**
- Baseado nos serviços da OS, sugere peças necessárias
- Profissional confirma e já vê fornecedores com estoque
- Reduz ida desnecessária à loja

---

### Programa de Fidelidade / Cashback

Incentivo financeiro pra usar o marketplace em vez de comprar por fora.

**Mecânica:**
- Profissional compra via indicação do app → ganha pontos/cashback
- Pontos podem virar desconto na assinatura do PraticOS
- Ou desconto em compras futuras no marketplace
- Fornecedor financia o cashback (custo de aquisição de cliente pra ele)

**Gamificação:**
- Ranking mensal de profissionais mais ativos
- Badges por marcos ("100 OS concluídas", "50 compras pelo app")
- Benefícios progressivos por nível

---

### Capacitação / Cursos

Profissional técnico quer se atualizar mas não tem tempo pra cursos longos.

**Micro-cursos (5-15 min):**
- Conteúdo prático por segmento
- "Como diagnosticar problema X", "Nova técnica pra Y"
- Formato vídeo curto ou passo-a-passo ilustrado

**Certificações por marca/fabricante:**
- Fornecedores/fabricantes certificam profissionais pelo app
- Ex: "Certificado em instalação de ar-condicionado [Marca]"
- Profissional certificado ganha selo no perfil → mais confiança do cliente final

**Conteúdo técnico de fabricantes:**
- Manuais, vídeos técnicos, boletins de serviço
- Fabricante paga pra ter seu conteúdo distribuído
- Profissional acessa gratuitamente

**Monetização:**
- Fabricante/fornecedor paga pra disponibilizar conteúdo e certificação
- Cursos premium pagos pelo profissional (ou inclusos na assinatura)
- Profissional certificado pode cobrar mais

---

### Seguro e Garantia Estendida

Diferencial competitivo pra profissionais que usam PraticOS.

**Garantia digital pelo app:**
- Profissional emite garantia vinculada à OS
- Cliente recebe comprovante digital (push/email/WhatsApp)
- Histórico completo: o que foi feito, peças usadas, validade

**Seguro do serviço (parceria com seguradora):**
- Cobra um % a mais no serviço, cobre retrabalho
- Cliente tem segurança, profissional se diferencia
- "Serviço com garantia PraticOS" → selo de confiança

**Por que funciona:**
- Diferencia o profissional que usa PraticOS do que não usa
- Cliente prefere profissional com garantia registrada
- Argumento forte de venda pra adoção do app

---

### Financiamento / Crediário pro Cliente Final

Problema real: cliente quer o serviço mas não tem o dinheiro todo.

**Modelo:**
- Parceria com fintech pra oferecer parcelamento direto pelo app
- Profissional não precisa fiar do próprio bolso
- Fintech paga o profissional à vista, cliente parcela
- PraticOS ganha fee por intermediação

**Fluxo:**
```
Profissional cria OS → valor R$ 2.000
    ↓
"Oferecer parcelamento ao cliente?"
    ↓
Cliente aprova em 10x de R$ 230 (com juros da fintech)
    ↓
Fintech paga profissional R$ 2.000 à vista (- fee)
    ↓
Cliente paga fintech em 10x
```

**Por que resolve um problema real:**
- Profissional perde serviços porque cliente não tem dinheiro
- Fiar do próprio bolso é risco alto e descapitaliza
- Com fintech intermediando, profissional recebe rápido e sem risco

---

### Perfil Público / Mini-site do Profissional

O profissional hoje não tem presença digital. O PraticOS poderia gerar automaticamente uma página pública.

**O que inclui:**
- Página pública com serviços oferecidos, avaliações, certificações, fotos de trabalhos
- Link compartilhável (praticos.web.app/pro/joao-refrigeracao) - profissional coloca no Instagram, cartão de visita, WhatsApp
- Agendamento online - cliente final acessa o perfil e agenda direto
- SEO local - profissional aparece no Google quando alguém busca "técnico de refrigeração em [cidade]"

**Efeito de rede:**
- Cada profissional divulga o PraticOS ao compartilhar seu próprio link
- O profissional vira canal de aquisição de outros profissionais ("vi que o João tem essa página, quero uma também")
- Cliente final conhece o PraticOS pelo profissional, e depois exige de outros profissionais

---

### Inteligência de Preço / Benchmark

Dado anonimizado de OS de toda a plataforma vira inteligência de mercado.

**O que oferece:**
- "A média de preço pra troca de compressor na sua região é R$ 850-1.200"
- "Você está cobrando 20% abaixo da média pra esse serviço"
- "Serviços de ar-condicionado têm alta de demanda em outubro-março"
- Tendências de preço por serviço ao longo do tempo

**Por que é poderoso:**
- Essa informação **só existe no PraticOS** porque vem do volume de OS
- Quanto mais profissionais, mais preciso fica - efeito de rede em dados
- Profissional precifica melhor → ganha mais → atribui o ganho ao app
- Fornecedores pagariam pra acessar dados de demanda agregados

---

### Compra Coletiva / Grupo de Compras

Profissionais da mesma região/segmento se juntam pra comprar em volume.

**Como funciona:**
- "15 mecânicos da região precisam de óleo 5W30 este mês"
- Distribuidor oferece preço de atacado pro grupo
- Cada um paga sua parte, entrega centralizada ou individual
- PraticOS orquestra a negociação e cobra fee do distribuidor

**Efeito de rede:**
- Quanto mais profissionais no grupo, melhor o preço pra todos
- Fornecedor/distribuidor quer participar porque vende volume garantido
- Profissional convida colegas pra melhorar o preço do grupo

---

### Otimização de Rota

Profissional que faz serviço externo (atendimento em domicílio) perde tempo planejando o dia.

**O que oferece:**
- Com base nas OS agendadas, sugere a melhor rota do dia
- Integração com maps pra tempo/distância real
- "Se você encaixar o cliente Y entre o X e o Z, economiza 40 min"
- Estimativa de tempo total do dia e horário de término

**Valor:** Economia de tempo e combustível. Profissional atende mais clientes por dia.

---

### Mercado Secundário entre Profissionais

Equipamentos e ferramentas usadas, vendidas entre profissionais verificados.

**Como funciona:**
- Profissional que trocou de equipamento vende pro colega
- "Manifold digital semi-novo - R$ 400" (visto só por profissionais de refrigeração)
- Filtrado por segmento e região
- Confiança maior que OLX porque é entre profissionais verificados

**Efeito de rede:**
- Quanto mais profissionais, mais oferta e demanda de equipamentos
- Segmentação por nicho cria liquidez que plataformas genéricas não têm

---

### Contratos de Manutenção Preventiva

Transformar serviço avulso em receita recorrente pro profissional.

**Como funciona:**
- Profissional cadastra contrato: "Manutenção preventiva a cada 6 meses pra cliente X"
- App lembra automaticamente quando está chegando a hora
- Gera OS pré-preenchida e notifica o cliente
- "Você tem 12 contratos ativos = receita previsível de R$ X/mês"

**Valor:**
- Profissional tem previsibilidade de receita
- Cliente recebe manutenção proativa (não espera quebrar)
- PraticOS se torna indispensável pra gerenciar esses contratos

---

### Diagnóstico Assistido por IA

Base de conhecimento coletiva da plataforma alimenta um assistente inteligente.

**Como funciona:**
- "Cliente reporta: ar-condicionado fazendo barulho e não gelando"
- IA sugere: "80% dos casos com esses sintomas são compressor com defeito (dados de 2.300 OS similares)"
- Sugere peças necessárias, tempo estimado de serviço e preço médio
- Profissional confirma ou corrige, alimentando o modelo

**Efeito de rede em dados:**
- Quanto mais OS na plataforma, mais inteligente fica o diagnóstico
- Conhecimento coletivo de milhares de profissionais disponível pra cada um
- Impossível de replicar sem a base de OS

---

### Portal do Cliente Final (White-label)

O cliente do profissional acompanha tudo pelo app ou link, com a marca do profissional.

**O que o cliente vê:**
- Status da OS em tempo real ("Em andamento", "Aguardando peça")
- Fotos do serviço em andamento
- Aprovação de orçamento online
- Histórico de todos os serviços feitos com aquele profissional
- Avaliação pós-serviço

**Efeito de rede indireto:**
- O profissional parece mais profissional → atrai mais clientes
- Cliente final começa a **exigir** PraticOS de outros profissionais que contratar
- "Meu outro técnico me mandava atualização pelo app, você não tem?"

---

### Atendimento a Frotas / Corporativo (B2B)

Empresas com frotas de veículos ou muitos equipamentos contratam profissionais pela plataforma.

**Como funciona:**
- Empresa cadastra seus veículos/equipamentos no PraticOS
- Abre chamado pelo app, profissional mais próximo e qualificado atende
- Contrato corporativo com SLA definido
- Dashboard pra empresa acompanhar todas as manutenções

**Por que é interessante:**
- Mercado B2B: ticket maior, receita mais previsível
- Empresa quer controle e rastreabilidade (PraticOS entrega isso nativamente)
- Profissional ganha clientes recorrentes de alto volume
- Efeito de rede: mais profissionais → melhor cobertura → mais empresas querem usar

---

### Mapa de Oportunidades (visão consolidada)

```
                           ECOSSISTEMA PRATICOS

         ENGAJAMENTO               CONEXÃO                CRESCIMENTO
    ┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
    │  Ferramentas │     │  Marketplace     │     │  Comunidade      │
    │  Técnicas    │────▶│  Local           │────▶│  Profissional    │
    │              │     │                  │     │                  │
    │ Calculadoras │     │ Fornecedores     │     │ Indicações       │
    │ Conversores  │     │ Catálogo peças   │     │ Fórum técnico    │
    │ Referências  │     │ Compra coletiva  │     │ Emergências      │
    │ Diagnóst. IA │     │ Mercado secund.  │     │ Mercado secund.  │
    └──────┬───────┘     └────────┬─────────┘     └──────────────────┘
           │                      │
           ▼                      ▼
    ┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
    │  Capacitação │     │  Financeiro      │     │  Confiança       │
    │              │     │                  │     │                  │
    │ Micro-cursos │     │ Cashback         │     │ Garantia digital │
    │ Certificação │     │ Fidelidade       │     │ Seguro serviço   │
    │ Conteúdo     │     │ Crediário        │     │ Certificação     │
    └──────────────┘     │ Benchmark preço  │     │ Perfil público   │
                         └──────────────────┘     └──────────────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Expansão        │
                         │                  │
                         │ Portal cliente   │
                         │ Frotas / B2B     │
                         │ Rota otimizada   │
                         │ Manutenção prev. │
                         └──────────────────┘
```

Cada bloco pode ser uma fase independente.

### Priorização: efeito de rede primeiro

**Ideias que geram efeito de rede devem ter prioridade.** Elas criam barreira de entrada (moat) - quanto mais gente usa, mais valioso fica, e mais difícil é o profissional sair.

| Ideia | Tipo de efeito de rede | Força |
|-------|----------------------|-------|
| **Marketplace local** | Bilateral (profissional ↔ fornecedor) - mais profissionais atraem mais fornecedores e vice-versa | Alta |
| **Comunidade / Indicações** | Direto (profissional ↔ profissional) - profissional não sai porque perderia a rede de contatos e indicações | Alta |
| **Compra coletiva** | Direto (profissional ↔ profissional) - quanto mais profissionais no grupo, melhor o preço pra todos | Alta |
| **Diagnóstico IA** | Dados coletivos - quanto mais OS na plataforma, mais inteligente fica. Impossível replicar sem a base | Alta |
| **Inteligência de preço** | Dados coletivos - informação que só existe com volume de OS. Quanto mais profissionais, mais preciso | Alta |
| **Perfil público / Mini-site** | Viral - cada profissional divulga o PraticOS ao compartilhar seu link. Canal de aquisição orgânico | Alta |
| **Certificação por marca** | Triangular (profissional ↔ app ↔ fabricante) - vínculo triplo que reforça todos os lados | Média-alta |
| **Portal do cliente final** | Indireto (via cliente) - cliente exige PraticOS de outros profissionais que contratar | Média-alta |
| **Frotas / B2B** | Bilateral (empresa ↔ profissional) - mais profissionais = melhor cobertura = mais empresas | Média-alta |
| **Garantia digital** | Indireto (via cliente final) - cliente passa a exigir "profissional com PraticOS" porque tem garantia registrada | Média |
| **Mercado secundário** | Direto entre profissionais - mais profissionais = mais oferta/demanda de equipamentos | Média |
| **Manutenção preventiva** | Lock-in (profissional ↔ cliente) - contratos criam dependência do app pra gerenciar | Média |
| Ferramentas técnicas | Nenhum (valor individual) - útil como porta de entrada, mas não cria dependência do ecossistema | Baixa |
| Otimização de rota | Nenhum (valor individual) - útil mas substituível por qualquer app de mapa | Baixa |
| Cashback / Fidelidade | Fraco (troca por incentivo melhor) - funciona mas não cria moat real | Baixa |
| Financiamento / Crediário | Nenhum (substituível) - qualquer app pode oferecer | Baixa |

**Combinação mais forte:** Marketplace + Comunidade de indicações + Inteligência de preço. O profissional encontra peças, encontra colegas pra indicar/receber serviços, e tem dados de mercado que não existem em nenhum outro lugar. O custo de sair do app fica muito alto.

As ferramentas técnicas (calculadoras, conversores) continuam importantes como **porta de entrada** - dão motivo pro profissional abrir o app todo dia - mas não devem ser o foco estratégico isoladamente.

---

## Arquitetura Técnica (Preliminar)

### Stack Web: Nuxt.js (Vue) no Cloud Run

As páginas públicas do ecossistema (perfil, marketplace, portal do cliente) usam **Nuxt.js** rodando no **Cloud Run** em `southamerica-east1`, com **Firebase Hosting** como CDN.

Ver [PUBLIC_PROFILE.md](./PUBLIC_PROFILE.md) para detalhes completos da decisão técnica, incluindo justificativa da escolha de Nuxt.js vs Next.js, exemplos de código e configuração de deploy.

```
Firebase Hosting (CDN)
    ↓ rewrites
Cloud Run (Nuxt.js SSR) ← Páginas públicas (perfil, marketplace, portal)
    ↓
Firestore (dados)

Flutter App (iOS/Android/Web) ← App do profissional (ferramentas, OS, gestão)
    ↓
Firestore (dados)
```

**Divisão de responsabilidades:**

| Camada | Tecnologia | Responsabilidade |
|--------|-----------|-----------------|
| App do profissional | Flutter | Gestão de OS, ferramentas, configuração de perfil |
| Páginas públicas | Nuxt.js (Cloud Run) | Perfil público, marketplace, portal do cliente |
| Site institucional | Eleventy (11ty) | Páginas estáticas, docs, landing pages |
| API / Backend | Cloud Functions (Express) | APIs, triggers, integrações |
| Dados | Firestore | Fonte única de verdade |
| CDN | Firebase Hosting | Cache e roteamento |

### Estrutura do projeto web

```
firebase/web/                            # Projeto Nuxt.js
├── pages/
│   ├── pro/[slug].vue                   # Perfil público do profissional
│   ├── marketplace/                     # Marketplace de fornecedores (futuro)
│   │   ├── index.vue                    # Busca de fornecedores
│   │   └── [supplierId].vue             # Perfil do fornecedor
│   └── portal/                          # Portal do cliente final (futuro)
│       └── [token].vue                  # Acompanhamento de OS
├── components/                          # Componentes Vue reutilizáveis
├── server/
│   ├── api/                             # API routes do Nuxt
│   └── utils/
│       └── firebase.ts                  # Firebase Admin SDK
├── Dockerfile
└── nuxt.config.ts
```

### Estrutura Firestore

```
/tools/{toolId}                          # Catálogo de ferramentas
  - name, description, icon
  - segments[]                           # Segmentos aplicáveis
  - category                             # 'calculator', 'converter', 'reference'
  - sponsorId?                           # Fornecedor patrocinador (branded)
  - config {}                            # Parâmetros da ferramenta

/suppliers/{supplierId}                  # Fornecedores
  - name, cnpj, address, coordinates
  - segments[], categories[]
  - contacts { whatsapp, phone, website }
  - tier: 'basic' | 'featured' | 'premium'
  - rating, reviewCount
  - active, createdAt

/suppliers/{supplierId}/products/{id}    # Catálogo (Premium)
  - name, category, brand
  - priceRange, availability
  - compatibility[]

/suppliers/{supplierId}/metrics/{period} # Métricas do fornecedor
  - impressions, clicks, leads
  - period: '2026-02'

/companies/{companyId}/toolUsage/{id}    # Analytics de uso
  - toolId, usedAt, segment
  - result {}                            # Resultado do cálculo (pra recomendação)

/companies/{companyId}/publicProfile     # Perfil público (ver PUBLIC_PROFILE.md)
  - active, slug, bio, portfolioPhotos...
```

### Integração no App Flutter

```
Menu Principal
├── OS (existente)
├── Clientes (existente)
├── Dashboard (existente)
├── Ferramentas ← NOVO
│   ├── Calculadoras
│   ├── Conversores
│   └── Referências
└── Fornecedores ← NOVO (ou sub-aba de Ferramentas)
    ├── Busca por categoria
    ├── Busca por proximidade
    └── Favoritos
```

### Componentes Flutter (App)

```
lib/
├── screens/
│   ├── tools/                    # Aba de ferramentas
│   │   ├── tools_screen.dart     # Lista de ferramentas por segmento
│   │   ├── markup_calculator/    # Calculadora de markup
│   │   ├── hourly_rate/          # Calculadora de hora técnica
│   │   ├── unit_converter/       # Conversor de unidades
│   │   └── btu_calculator/       # Calculadora BTU (refrigeração)
│   └── suppliers/                # Marketplace
│       ├── suppliers_screen.dart # Busca/listagem
│       ├── supplier_detail.dart  # Perfil do fornecedor
│       └── supplier_review.dart  # Avaliações
├── models/
│   ├── tool.dart                 # Modelo de ferramenta
│   ├── supplier.dart             # Modelo de fornecedor
│   └── supplier_review.dart      # Modelo de avaliação
├── repositories/
│   ├── tool_repository.dart
│   └── supplier_repository.dart
└── mobx/
    ├── tool_store.dart
    └── supplier_store.dart
```

---

## Referências e Inspirações

- **iFixit** - base de conhecimento técnico por equipamento
- **GetNinjas** - marketplace de serviços (modelo inverso, mas referência de UX)
- **Mercado Livre** - marketplace com níveis de vendedor
- **Waze** - recomendação contextual baseada em localização
- **Calculadoras HP / Fluke** - referência de ferramentas técnicas profissionais
