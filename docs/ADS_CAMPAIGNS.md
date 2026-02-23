# PraticOS - Campanhas de Ads e Integrações

## Status Geral

| Plataforma | Acesso | Credenciais | Escrita via API |
|------------|--------|-------------|-----------------|
| Google Ads | Conectado | `~/.google-ads.yaml` | Ativo |
| Meta Ads | Conectado | `~/.meta-ads.yaml` | Ativo |

## Contas

### Google Ads
- **Manager (MCC)**: PraticOS Manager - `156-966-6691`
- **Conta de anúncios**: PraticOS - `673-501-4760`
- **Moeda**: BRL
- **Fuso**: America/Sao_Paulo
- **Developer Token**: Configurado
- **Nível de acesso**: Acesso Padrão (leitura e escrita) - aprovado em 23/02/2026

### Meta Ads
- **App ID**: 2156455528501761 (PraticOS Ads)
- **Ad Account**: act_521666357871300
- **Moeda**: BRL
- **Lib Python**: facebook-business

## Campanhas Ativas

### Google Ads

#### 1. App-Android (ID: 23543314920)
- **Status**: ENABLED / SERVING / LEARNING
- **Tipo**: Multi-channel (App Install)
- **Bidding**: Maximize Conversions
- **Budget**: R$10/dia
- **App**: br.com.rafsoft.praticos (Google Play)
- **Segmentação**: Brasil, Português
- **Performance (últimos 30 dias)**:
  - Impressões: 3.848
  - Clicks: 439
  - CTR: 11,41%
  - CPC médio: R$0,23
  - Conversões: 102
  - Custo/conversão: R$0,98
  - Custo total: R$99,92
- **Headlines**:
  - Ordem de serviço no app
  - Controle sua assistência
  - OS, clientes e histórico
  - Checklist e fotos na OS
  - App para assistência técnica
- **Descriptions**:
  - Crie OS, registre serviços e acompanhe o status. Organização na rotina.
  - Clientes, aparelhos e histórico em um só lugar. Simples e rápido.
  - Faça orçamento, registre fotos e finalize serviços com agilidade.
  - Organize entradas e saídas e evite retrabalho. Baixe e teste grátis.
  - Funciona offline e facilita o atendimento. Gestão prática no dia a dia.

#### 2. App-iOS (ID: 23598117814)
- **Status**: ENABLED / SERVING
- **Tipo**: Multi-channel (App Install)
- **Bidding**: Maximize Conversions (OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST)
- **Budget**: R$10/dia (Budget ID: 15389228376)
- **App**: 1534604555 (Apple App Store)
- **Segmentação**: Brasil, Português
- **Ad Group**: Ad group 1 (ID: 192294584543)
- **Ad**: App Ad (ID: 798163564252)
- **Headlines**:
  - Ordem de serviço no app
  - Controle sua assistência
  - OS, clientes e histórico
  - Checklist e fotos na OS
  - App para assistência técnica
- **Descriptions**:
  - Crie OS, registre serviços e acompanhe o status. Organização na rotina.
  - Clientes, aparelhos e histórico em um só lugar. Simples e rápido.
  - Faça orçamento, registre fotos e finalize serviços com agilidade.
  - Organize entradas e saídas e evite retrabalho. Baixe e teste grátis.
  - Funciona offline e facilita o atendimento. Gestão prática no dia a dia.
- **Nota**: Sem conversion actions iOS dedicadas no Google Ads. Usa conversões modeladas (SKAdNetwork + sinais on-device) via OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST.
- **Script de criação**: `business/campaigns/google-ads/create_ios_campaign.py`
- **Criada**: 23/02/2026 via API

#### 3. Website traffic-Search-1 (ID: 23582521389)
- **Status**: ENABLED / SERVING / LEARNING
- **Tipo**: Search
- **Bidding**: Maximize Conversions
- **Budget**: R$10/dia
- **URL**: https://praticos.web.app
- **Ad Group**: Grupo de anúncios 1
- **Anúncio**: RSA (Responsive Search Ad) - APPROVED
- **Sitelinks**: 6 configurados
- **Callouts**: 15 configurados
- **Keywords**: 56 (18 PHRASE + 38 BROAD)
- **Negative Keywords**: 25 (nível de campanha)
- **Headlines (15)**:
  1. PraticOS - Gestão de OS
  2. App de Ordem de Serviço
  3. Crie OS Pelo WhatsApp
  4. Comece Grátis Hoje
  5. Controle OS Pelo Celular
  6. Sistema de OS Completo
  7. Gestão de Serviços Fácil
  8. Clientes, OS e Financeiro
  9. +10.000 OS Criadas
  10. Avaliação 4.8 nas Lojas
  11. Agenda e Equipe na Palma
  12. Ordem de Serviço online
  13. Envie Orçamentos em 1 Clique
  14. Para Técnicos e Autônomos
  15. Assistente IA no WhatsApp
- **Descriptions (4)**:
  1. Gestão de Ordens de Serviço Simplificada
  2. Crie OS, registre serviços e acompanhe o status. Organização na rotina.
  3. Faça orçamento, registre fotos e finalize serviços com agilidade.
  4. Clientes, aparelhos e histórico em um só lugar. Simples e rápido.
- **Sitelinks**:
  1. Planos e Preços → /pricing.html
  2. Assistente WhatsApp IA → /funcionalidades/whatsapp-bot.html
  3. Perguntas Frequentes → /faq.html
  4. Tutoriais e Guias → /docs/
  5. Agenda e Equipe → /docs/agenda.html
  6. Controle Financeiro → /docs/financeiro.html
- **Callouts**: Comece Grátis, Sem Fidelidade, App iOS e Android, Assistente WhatsApp IA, +10.000 OS Criadas, Avaliação 4.8 Estrelas, Suporte Humanizado, Agenda e Calendário, Controle Financeiro, Crie OS por Voz e Foto, Gestão de Equipe, Relatórios em Tempo Real, Envie Orçamentos Fácil, 14 Segmentos Atendidos, Sem Cartão para Começar

### Meta Ads

#### 1. PraticOS - App Install (ID: 6916166716575)
- **Status**: ACTIVE
- **Objetivo**: OUTCOME_APP_PROMOTION (App Installs)
- **Plataformas**: Facebook (Feed) + Instagram (Feed, Stories, Reels)
- **Segmentação**: Brasil, Português, Android + iOS, 25-65 anos
- **App**: br.com.rafsoft.praticos (Google Play) / id1534604555 (App Store)
- **Page ID**: 921394204400547 (Praticos - Ordem de Serviço)
- **Budget total**: R$22/dia (CBO — Campaign Budget Optimization)
- **Bid Strategy**: LOWEST_COST_WITHOUT_CAP
- **Advantage Audience**: ON (expande público automaticamente)

**Ad Set 1 - Todos os Públicos - Android (ID: 6916167924375)** — ACTIVE
- Store: Google Play | Age: 25-65
- Interesses (14): Empreendedorismo, Pequenas e médias empresas, Gestão, Trabalho autônomo, Business software, Mecânico de automóveis, HVAC, Refrigeração, Technician, Manutenção e reparo, Service (motor vehicle), Accounting software, Professional services, Encanamento
- Behaviors: Proprietários de pequenas empresas
- Placements: Facebook (Feed, Marketplace, Stories), Instagram (Feed, Stories, Reels, Explore), Audience Network
- 3 anúncios (teste A/B)

**Ad Set 2 - Todos os Públicos - iOS (ID: 6916515435975)** — ACTIVE
- Store: App Store | Age: 25-65
- Interesses (14): mesmos do Android
- Behaviors: Proprietários de pequenas empresas
- Placements: mesmos do Android
- 3 anúncios (teste A/B)
- Nota: `user_os` travado em `iOS_ver_2.0_to_14.4` pelo Meta (cache do app registration). Com Advantage Audience ON, alcance expandido automaticamente.

**Ad Sets PAUSADOS:**
- Segmentos Específicos - Android (ID: 6916167935975) — consolidado no Ad Set 1
- Segmentos Específicos - iOS (ID: 6916487807175) — consolidado no Ad Set 2
- Todos os Públicos - iOS antigo (ID: 6916487798775) — substituído pelo Ad Set 2

**Anúncios v2 (12 total - 3 variações x 4 ad sets) — Criativos otimizados:**

| Ad | Headline | Criativo | Formato |
|----|----------|----------|---------|
| 1 - WhatsApp GIF | Crie OS pelo WhatsApp com IA | GIF animado do fluxo WhatsApp (vídeo) | Vídeo |
| 2 - WhatsApp Estático | Crie OS pelo WhatsApp | Composição: gradiente azul + screenshot WhatsApp (OS criada) + texto overlay + logo + badge | Imagem 1080x1080 |
| 3 - App Completo | Chega de papel e planilha | Composição: gradiente azul + phone mockup com home.png + texto overlay + logo + badge | Imagem 1080x1080 |

**Copy por Anúncio:**

*Ad 1 (WhatsApp GIF):*
> Mande uma foto do veículo. A IA identifica modelo e placa.
> Diga o serviço e o valor. OS criada em segundos.
> ✓ Crie OS por voz, foto ou texto
> ✓ Cliente recebe link de acompanhamento
> ✓ Funciona 24h, direto no WhatsApp
> Usado por +500 empresas. Comece grátis.

*Ad 2 (WhatsApp Estático):*
> Crie ordens de serviço pelo WhatsApp.
> Mande uma foto, um áudio ou uma mensagem. O assistente IA do PraticOS cria a OS, cadastra o cliente e envia o link de acompanhamento. Tudo em segundos.
> ✓ OS por voz, foto ou texto
> ✓ Identifica veículos por foto da placa
> ✓ Envia orçamento pro cliente automaticamente
> Avaliação 4.8 nas lojas. Grátis para começar.

*Ad 3 (App Completo):*
> Chega de caderninho e planilha.
> O PraticOS organiza ordens de serviço, clientes e finanças em um app simples. Feito para técnicos e prestadores de serviço.
> ✓ Crie OS com fotos e valores
> ✓ Controle faturamento e recebimentos
> ✓ Agenda com lembretes
> +10.000 OS criadas. Comece grátis — sem cartão.

**IDs dos Anúncios v2 (Android):**
- 6916497000975 - WhatsApp GIF v2 - Geral Android
- 6916497004575 - WhatsApp Estático v2 - Geral Android
- 6916497008175 - App Completo v2 - Geral Android
- 6916497012175 - WhatsApp GIF v2 - Segmentos Android
- 6916497015775 - WhatsApp Estático v2 - Segmentos Android
- 6916497023175 - App Completo v2 - Segmentos Android

**IDs dos Anúncios v2 (iOS):**
- 6916497027175 - WhatsApp GIF v2 - Geral iOS
- 6916497032775 - WhatsApp Estático v2 - Geral iOS
- 6916497045775 - App Completo v2 - Geral iOS
- 6916497050575 - WhatsApp GIF v2 - Segmentos iOS
- 6916497054775 - WhatsApp Estático v2 - Segmentos iOS
- 6916497058375 - App Completo v2 - Segmentos iOS

**IDs dos Anúncios v1 (REMOVIDOS em 23/02/2026):**
- ~~6916483993975, 6916484006775, 6916484014775~~ (Android Geral)
- ~~6916484019375, 6916484023175, 6916484026975~~ (Android Segmentos)
- ~~6916487832775, 6916487844175, 6916487863775~~ (iOS Geral)
- ~~6916487875575, 6916487892175, 6916487901775~~ (iOS Segmentos)

**Creative IDs Gemini (atuais — gerados com Gemini 3 Pro + logo real):**
- 1999560020954235 - WhatsApp Gemini (Android)
- 2105918146909290 - WhatsApp Gemini (iOS)
- 767845742639495 - App Gemini (Android)
- 922296000738513 - App Gemini (iOS)
- 2157440651725740 - Dashboard Gemini (Android)
- 1441682600841993 - Dashboard Gemini (iOS)

**Image Hashes Gemini (atuais):**
- gemini_whatsapp: `08025e4ad08ba2024197443055a16c33`
- gemini_app: `d204a660a13314860562ce9c1405b2cd`
- gemini_dashboard: `739cb0e62002135eefe6858404d07b55`

**Video ID (GIF WhatsApp):** `1445062100614123`

**Image Hashes anteriores (Pillow v3):**
- whatsapp_feed: `b1c74f729c0fc30db571744ecd897a53`
- app_feed: `0bce2fba4b030bf36ec881263f1cde69`

**Image Hashes v1 (screenshots crus):**
- home: `32536b4f62babb6756cb04a2f8ff8bb0`
- order_detail: `aa6babcb1a1d17f0369e980097ab2508`
- dashboard: `2bdf938930cb2c16756887e138b521a0`

**Arquivos dos criativos:** `business/campaigns/meta-ads/creatives/`
- `generate_gemini_creatives.py` - Script Gemini 3 Pro (IA generativa com logo real)
- `gemini_whatsapp_1080x1080.png` - WhatsApp (Gemini)
- `gemini_app_1080x1080.png` - App (Gemini)
- `gemini_dashboard_1080x1080.png` - Dashboard (Gemini)
- `generate_creatives.py` - Script Pillow (composição manual)
- `whatsapp_feed_1080x1080.png` - WhatsApp estático (Pillow)
- `app_feed_1080x1080.png` - App (Pillow)

## Pendências

### Prioridade Alta

- [x] **Google Ads - Vinculação Analytics/iOS**: Revinculação do Google Analytics sincronizou o stream iOS. Concluída em 22/02/2026.
- [x] **Google Ads - Criar campanha App-iOS**: Campanha App-iOS criada (ID: 23598117814) via API em 23/02/2026. Mesmos criativos do Android. Status: ENABLED/SERVING.
- [x] **Meta Ads - Criar campanha de instalações**: Campanha Facebook/Instagram para installs do PraticOS (Android). Criada em 23/02/2026.
- [x] **Meta Ads - Criar ad sets iOS**: Ad sets iOS criados em 23/02/2026.
- [x] **Meta Ads - Ativar campanha**: Campanha ativada em 23/02/2026 (Android + iOS).

### Prioridade Média

- [ ] **Google Ads - Monitorar App-iOS**: Monitorar impressões e conversões do App-iOS nas primeiras 48h. Verificar se o app icon aparece corretamente na UI do Google Ads.
- [ ] **Meta Ads - Monitorar CTR criativos v2**: Monitorar CTR nas primeiras 24-48h dos novos criativos. Comparar WhatsApp GIF vs WhatsApp Estático vs App Completo. Pausar variações com CTR baixo após 72h.
- [ ] **Meta Ads - Criativos Stories dedicados**: As imagens 1080x1920 (Stories) foram geradas mas não vinculadas a creatives separados. Considerar criar ad creatives específicos para Stories/Reels com as imagens verticais.
- [x] **Google Ads - Acesso Padrão**: Aprovado em 23/02/2026. Escrita via API funcionando.
- [x] **Google Ads - Keywords negativas**: 25 keywords negativas adicionadas + 18 keywords convertidas para PHRASE match (23/02/2026).
- [ ] **Google Ads - Campanhas por segmento**: Considerar criar campanhas separadas por nicho (mecânica, refrigeração, CFTV, etc.) com sitelinks específicos de cada segmento.

### Prioridade Baixa

- [x] **Meta Ads - Token de longa duração**: Token de 60 dias gerado e salvo em `~/.meta-ads.yaml` (23/02/2026).
- [ ] **GoogleService-Info.plist**: Os flags `IS_ANALYTICS_ENABLED` e `IS_ADS_ENABLED` estão `false` no iOS. Embora o Analytics funcione via SDK, considerar atualizar para `true` em uma futura release.
- [ ] **Google Ads - Otimização contínua**: Depois de 2 semanas de dados, analisar termos de busca, pausar keywords ruins, ajustar bids.

## Histórico de Alterações

### 23/02/2026 (Campanha App-iOS - Google Ads)
- Criada campanha **App-iOS** (ID: 23598117814) via Google Ads API
  - Budget: R$10/dia (ID: 15389228376)
  - Tipo: MULTI_CHANNEL / APP_CAMPAIGN
  - App: 1534604555 (Apple App Store)
  - Bidding: Maximize Conversions (OPTIMIZE_INSTALLS_WITHOUT_TARGET_INSTALL_COST)
  - Targeting: Brasil + Português
  - Ad Group: Ad group 1 (ID: 192294584543)
  - App Ad: ID 798163564252 (5 headlines + 5 descriptions, mesmos do Android)
  - Status: ENABLED / SERVING
  - Sem conversion actions iOS dedicadas; usa conversões modeladas (SKAdNetwork)
  - Script: `business/campaigns/google-ads/create_ios_campaign.py`
  - 2 orphaned budgets de tentativas anteriores (22/02) removidos via API

### 23/02/2026 (Otimização Keywords - Search)
- **Adicionou 25 keywords negativas** (nível de campanha) para eliminar tráfego irrelevante:
  - Termos genéricos: consultoria, qualidade, erp, estoque, vendas, planilha, template
  - Educação/emprego: curso, emprego, vaga, concurso, faculdade, graduação
  - Fora do produto: fotovoltaico, proposta comercial, procedimentos operacionais, redução de custos, gestão da qualidade
  - Concorrentes: gestãoclick, gestaoclick
  - Downloads: gratuito download, download gratis
- **Converteu 18 keywords de BROAD → PHRASE** (as genéricas que geravam search terms irrelevantes):
  - Inclui: gestão de serviços, sistema de OS, sistema ordem de serviço, gerenciamento de serviços, controle de serviços, software de gestão de serviços, gestão de ordens de serviço, ordem de serviço digital/online, etc.
  - 38 keywords de nicho mantidas como BROAD (app para mecânico, sistema para refrigeração, etc.)
- **2 keywords removidas** por violação de política do Google ("empréstimos pessoais"):
  - controle financeiro prestador de serviço
  - sistema para prestador de serviço
- Total: 56 keywords (18 PHRASE + 38 BROAD) + 25 negativas
- Motivação: campanha gastou R$20,90 sem conversões; termos de busca ativados eram completamente fora do target (consultoria em sistemas, gestão da qualidade de produtos, planilha fotovoltaico, etc.)

### 23/02/2026 (Otimização de Targeting)
- Consolidou 4 ad sets em 2 (Android + iOS) para concentrar orçamento
  - Interesses dos ad sets "Segmentos Específicos" mesclados nos "Geral"
  - Ad sets de segmentos pausados
- Adicionou 4 novos interesses: Service (motor vehicle), Accounting software, Professional services, Encanamento
- Adicionou behavior "Proprietários de pequenas empresas" (OR com interesses)
- Habilitou **Advantage Audience** (expansão automática de público pelo Meta)
- Ampliou idade de 25-55 para 25-65 (exigido pelo Advantage+)
- Adicionou posicionamentos: Facebook Marketplace, Facebook Stories, Instagram Explore, Audience Network
- Criou novo ad set iOS (ID: 6916515435975) com targeting atualizado, pausou antigo
- Corrigiu `app_install_state: not_installed` que faltava no iOS
- Adicionou Bundle ID `br.com.rafsoft.praticos` no Meta Developer Dashboard
- Nota: `user_os` do iOS continua travado em `14.4` por cache do Meta; Advantage Audience compensa

### 23/02/2026 (Criativos Gemini IA)
- Criativos gerados com **Gemini 3 Pro** (image generation) com logo real do PraticOS
  - **WhatsApp Gemini**: Mockup iPhone com conversa WhatsApp + bot criando OS
  - **App Gemini**: Mockup iPhone com tela de lista de OS + checkmarks
  - **Dashboard Gemini**: Mockup iPhone com painel financeiro + gráficos
  - Logo real enviada como referência via API multimodal
  - 3 imagens uploaded, 6 creatives criados, 12 ads atualizados
  - Config: `~/.gemini.yaml` | Script: `generate_gemini_creatives.py`

### 23/02/2026 (Otimização de Criativos)
- Criativos v2→v3 da campanha Meta Ads com imagens compostas e copy otimizada
  - **WhatsApp GIF** (Criativo 1): GIF animado do fluxo de criação de OS pelo WhatsApp, uploaded como vídeo
  - **WhatsApp Estático** (Criativo 2): Composição Pillow — gradiente azul + screenshot WhatsApp (OS #175 criada) + texto overlay + logo + badge "4.8★ · +10.000 OS criadas"
  - **App Completo** (Criativo 3): Composição Pillow — gradiente azul + phone mockup com home.png + checklist + logo + badge "Grátis para começar · Sem cartão"
  - Copy reescrita focando em benefícios, não features. Usa prova social e CTA claro
  - 12 novos ads criados (3 variações × 4 ad sets), 12 ads antigos (v1) pausados
  - Imagens geradas via Python/Pillow: `business/campaigns/meta-ads/creatives/`
  - Script reproduzível: `generate_creatives.py`
  - **v3**: Mockups do celular e fontes aumentados para melhor aproveitamento do espaço. Screenshots "sangram" nas bordas para efeito mais impactante. Creatives v3 atualizados nos 12 ads.

### 23/02/2026 (Criação Inicial)
- Criada campanha Meta Ads "PraticOS - App Install" (ID: 6916166716575)
  - Objetivo: OUTCOME_APP_PROMOTION (App Installs)
  - 2 ad sets Android: Prestadores Geral + Segmentos Específicos
  - 6 anúncios (3 variações x 2 ad sets) com screenshots do app
  - Budget: R$5,50/dia por ad set (R$11/dia total)
  - Status: PAUSED (aguardando revisão e ativação manual)
- Token Meta Ads de longa duração gerado (60 dias)
- App "PraticOS Ads" configurado com plataformas Android/iOS e publicado (modo Live)
- Plataformas adicionadas ao app: Android (`br.com.rafsoft.praticos`) + iOS (Bundle ID + Store ID 1534604555)

### 22/02/2026
- Criada campanha Website traffic-Search-1 (Google Ads)
  - 15 headlines, 4 descrições, 58 keywords (BROAD)
  - 6 sitelinks adicionados
  - 15 frases de destaque adicionadas
  - Corrigido: emoji ⭐ removido do headline (APPROVED_LIMITED → APPROVED)
- Configurado acesso à API do Google Ads
  - Developer Token obtido na conta Manager
  - Credenciais OAuth criadas no Google Cloud Console
  - Refresh Token gerado
  - Conexão testada com sucesso
  - Documentação salva em `docs/GOOGLE_ADS_API.md`
- Solicitado upgrade para Acesso Padrão (Google Ads API)
  - Design document PDF gerado e enviado
- Configurado acesso à API do Meta Ads
  - App "PraticOS Ads" criado no Facebook Developers
  - API de Marketing habilitada
  - Conexão testada com sucesso
- Tentativa de criar campanha App-iOS (Google Ads)
  - Bloqueada: stream iOS não reconhecido pelo Google Ads
  - Causa: vinculação Analytics → Google Ads não incluía stream iOS
  - Ação: vinculação removida e recriada. Aguardando sincronização (24-48h)

## Referências

- `docs/GOOGLE_ADS_API.md` - Documentação completa da API Google Ads
- Credenciais Google Ads: `~/.google-ads.yaml`
- Credenciais Meta Ads: `~/.meta-ads.yaml`
- [Google Ads Query Builder](https://developers.google.com/google-ads/api/fields/v17/overview_query_builder)
- [Meta Marketing API Docs](https://developers.facebook.com/docs/marketing-apis)
- [Graph API Explorer](https://developers.facebook.com/tools/explorer)
