# Growth: CTA na Página de Rastreamento de OS

## Visão Geral

Transformar o footer "Powered by PraticOS" na página de rastreamento de OS (`/q/{token}`) em um CTA promocional real. Cada ordem de serviço compartilhada é uma oportunidade de aquisição: o cliente final que recebe o link é um potencial novo usuário do PraticOS.

**Motivação:** Com 17 novos usuários em 7 dias (R$50 em Google Play Ads), o canal mais eficiente é o viral loop orgânico — todo cliente de OS que visualiza a página já demonstrou estar no contexto de "serviço técnico". Um CTA bem posicionado converte essa atenção em cadastros gratuitos.

**Estimativa de implementação:** ~4h

## Arquitetura Atual

### Footer existente

O footer atual é um simples texto "Powered by PraticOS" com link para o site:

**Arquivo:** `firebase/hosting/src/js/order-view.js` — função `renderFooter()` (linha 953)

```javascript
// Render footer
function renderFooter() {
    const footer = document.createElement('div');
    footer.className = 'order-footer';
    footer.innerHTML = `
        ${text.poweredBy} <a href="https://praticos.app" target="_blank">PraticOS</a>
    `;
    orderContent.appendChild(footer);
}
```

**Arquivo:** `firebase/hosting/src/css/order-view.css` — estilos `.order-footer` (linha 921)

```css
/* Footer Info */
.order-footer {
    text-align: center;
    padding: 40px 20px;
    color: var(--text-tertiary);
    font-size: 0.875rem;
}

.order-footer a {
    color: var(--color-primary);
}
```

### Tradução existente

O objeto `ui` em `order-view.js` (linha 79) já tem a chave `poweredBy` nos 3 idiomas:

```javascript
const ui = {
    pt: { ..., poweredBy: 'Powered by', ... },
    en: { ..., poweredBy: 'Powered by', ... },
    es: { ..., poweredBy: 'Powered by', ... }
};
```

A variável `text` é resolvida assim: `const text = ui[lang] || ui['pt'];`

### CSS Variables disponíveis

O design system da página de OS já expõe estas variáveis (via `style.css` base + `order-view.css`):

| Variável | Uso |
|----------|-----|
| `--gradient-primary` | Gradiente do botão principal (approve) |
| `--color-primary` | Cor de destaque (azul) |
| `--bg-card` | Background de cards |
| `--bg-tertiary` | Background alternativo |
| `--border-color` | Borda padrão |
| `--radius-lg` | Border radius grande |
| `--radius-md` | Border radius médio |
| `--text-primary` | Texto principal |
| `--text-secondary` | Texto secundário |
| `--text-tertiary` | Texto terciário |
| `--shadow-lg` | Sombra grande |
| `--transition-normal` | Transição padrão |

## Design do Novo CTA

### Conceito visual

Substituir o texto simples por um card promocional no footer com:

1. **Ícone/emoji** — foguete ou estrela para chamar atenção
2. **Headline i18n** — frase que conecta com o contexto (o cliente acabou de ver uma OS profissional)
3. **Subtext i18n** — proposta de valor curta
4. **Botão WhatsApp** — CTA primário que leva ao bot (maior conversão via conversa)
5. **Link secundário** — "Saiba mais" para o site

### Layout proposto

```
┌──────────────────────────────────────────────┐
│                                              │
│  🚀  Quer organizar seu negócio assim?       │
│                                              │
│  Crie OS profissionais, envie orçamentos e   │
│  acompanhe tudo pelo celular. Grátis!        │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  💬 Começar pelo WhatsApp            │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Saiba mais sobre o PraticOS →               │
│                                              │
│  Powered by PraticOS                         │
│                                              │
└──────────────────────────────────────────────┘
```

## Implementação

### 1. Adicionar chaves i18n ao objeto `ui`

**Arquivo:** `firebase/hosting/src/js/order-view.js`

Adicionar as seguintes chaves a cada idioma no objeto `ui` (após `yourRating`):

```javascript
// CTA footer
ctaHeadline: 'Quer organizar seu negócio assim?',
ctaSubtext: 'Crie OS profissionais, envie orçamentos e acompanhe tudo pelo celular. Grátis!',
ctaWhatsApp: 'Começar pelo WhatsApp',
ctaLearnMore: 'Saiba mais sobre o PraticOS',
```

**pt:**
```javascript
ctaHeadline: 'Quer organizar seu negócio assim?',
ctaSubtext: 'Crie OS profissionais, envie orçamentos e acompanhe tudo pelo celular. Grátis!',
ctaWhatsApp: 'Começar pelo WhatsApp',
ctaLearnMore: 'Saiba mais sobre o PraticOS',
```

**en:**
```javascript
ctaHeadline: 'Want to organize your business like this?',
ctaSubtext: 'Create professional work orders, send quotes, and track everything from your phone. Free!',
ctaWhatsApp: 'Start on WhatsApp',
ctaLearnMore: 'Learn more about PraticOS',
```

**es:**
```javascript
ctaHeadline: '¿Quieres organizar tu negocio así?',
ctaSubtext: 'Crea OS profesionales, envía presupuestos y controla todo desde tu celular. ¡Gratis!',
ctaWhatsApp: 'Empezar por WhatsApp',
ctaLearnMore: 'Conoce más sobre PraticOS',
```

### 2. Reescrever a função `renderFooter()`

**Arquivo:** `firebase/hosting/src/js/order-view.js` — substituir a função `renderFooter()` (linha 953)

```javascript
// Render footer with promotional CTA
function renderFooter() {
    const footer = document.createElement('div');
    footer.className = 'order-footer';

    // UTM params for tracking
    const utmParams = 'utm_source=order_page&utm_medium=cta&utm_campaign=viral';

    // WhatsApp bot number (same as site.json)
    const botNumber = '554888794742';
    const whatsappMessages = {
        pt: 'Olá! Vi o PraticOS numa OS e quero criar minha conta',
        en: 'Hello! I saw PraticOS on a work order and want to create my account',
        es: '¡Hola! Vi PraticOS en una OS y quiero crear mi cuenta'
    };
    const whatsappMsg = encodeURIComponent(whatsappMessages[lang] || whatsappMessages['pt']);
    const whatsappLink = `https://wa.me/${botNumber}?text=${whatsappMsg}`;

    // Site link with UTM
    const siteLink = `https://praticos.app?${utmParams}`;

    footer.innerHTML = `
        <div class="cta-card">
            <div class="cta-icon">🚀</div>
            <h3 class="cta-headline">${text.ctaHeadline}</h3>
            <p class="cta-subtext">${text.ctaSubtext}</p>
            <a href="${whatsappLink}" target="_blank" rel="noopener" class="cta-btn-whatsapp">
                <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
                    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                </svg>
                ${text.ctaWhatsApp}
            </a>
            <a href="${siteLink}" target="_blank" rel="noopener" class="cta-link-more">
                ${text.ctaLearnMore} →
            </a>
        </div>
        <div class="cta-powered">
            ${text.poweredBy} <a href="${siteLink}" target="_blank" rel="noopener">PraticOS</a>
        </div>
    `;
    orderContent.appendChild(footer);
}
```

### 3. Adicionar estilos CSS do CTA

**Arquivo:** `firebase/hosting/src/css/order-view.css` — substituir o bloco `.order-footer` (linha 921)

```css
/* Footer CTA */
.order-footer {
    padding: 24px 20px 40px;
}

.cta-card {
    max-width: 480px;
    margin: 0 auto 24px;
    padding: 28px 24px;
    background: linear-gradient(135deg, var(--bg-tertiary) 0%, var(--bg-card) 100%);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    text-align: center;
}

.cta-icon {
    font-size: 2rem;
    margin-bottom: 12px;
}

.cta-headline {
    font-family: var(--font-heading);
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 8px;
}

.cta-subtext {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin: 0 0 20px;
    line-height: 1.5;
}

.cta-btn-whatsapp {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    max-width: 320px;
    padding: 14px 24px;
    background: #25D366;
    color: #fff;
    font-size: 1rem;
    font-weight: 600;
    border-radius: var(--radius-lg);
    text-decoration: none;
    transition: var(--transition-normal);
}

.cta-btn-whatsapp:hover {
    background: #1FAD54;
    transform: translateY(-1px);
}

.cta-btn-whatsapp svg {
    width: 20px;
    height: 20px;
    flex-shrink: 0;
}

.cta-link-more {
    display: inline-block;
    margin-top: 16px;
    font-size: 0.875rem;
    color: var(--color-primary);
    text-decoration: none;
    transition: var(--transition-normal);
}

.cta-link-more:hover {
    opacity: 0.8;
}

.cta-powered {
    text-align: center;
    color: var(--text-tertiary);
    font-size: 0.8rem;
}

.cta-powered a {
    color: var(--color-primary);
    text-decoration: none;
}
```

## UTM Tracking

Todos os links do CTA incluem UTM params para rastrear a origem no Google Analytics:

| Param | Valor | Significado |
|-------|-------|-------------|
| `utm_source` | `order_page` | Página de rastreamento de OS |
| `utm_medium` | `cta` | Call-to-action no footer |
| `utm_campaign` | `viral` | Campanha de crescimento viral |

O link do WhatsApp inclui uma mensagem pré-preenchida que identifica a origem:
- **pt:** "Olá! Vi o PraticOS numa OS e quero criar minha conta"
- **en:** "Hello! I saw PraticOS on a work order and want to create my account"
- **es:** "¡Hola! Vi PraticOS en una OS y quiero crear mi cuenta"

O bot já detecta mensagens de primeiro contato e inicia o fluxo de cadastro (ver `registration.md`).

## Arquivos a Modificar

| Arquivo | Alteração |
|---------|-----------|
| `firebase/hosting/src/js/order-view.js` | Adicionar 4 chaves i18n ao objeto `ui` (pt/en/es) + reescrever `renderFooter()` |
| `firebase/hosting/src/css/order-view.css` | Substituir estilos `.order-footer` por novo bloco CTA |

**Total: 2 arquivos modificados, 0 criados.**

## Conexão com Outras Fases

- **Fase 2 (Referral System):** O CTA pode ser enriquecido com o `referralCode` da empresa que enviou a OS. Quando implementado, o link do WhatsApp incluirá `REF_XXXXXXXX` na mensagem, permitindo atribuição da conversão ao referrer.
- **Fase 3 (Business Directory):** Se a empresa tiver perfil público (`isPublicProfile`), o "Saiba mais" pode linkar para o perfil da empresa no diretório em vez do site genérico.

Estas conexões são melhorias futuras — o CTA funciona 100% de forma independente.

## Critérios de Verificação

- [ ] Footer da página `/q/{token}` mostra card CTA com headline, subtext, botão WhatsApp e link "saiba mais"
- [ ] Textos aparecem em português quando `lang=pt`, inglês quando `lang=en`, espanhol quando `lang=es`
- [ ] Botão WhatsApp abre `wa.me/554888794742` com mensagem pré-preenchida no idioma correto
- [ ] Link "Saiba mais" abre `praticos.app` com UTM params corretos
- [ ] CTA respeita dark/light mode (usa CSS vars do design system)
- [ ] Layout responsivo: card centralizado em desktop, full-width em mobile
- [ ] "Powered by PraticOS" permanece visível abaixo do card CTA (com UTM params)
- [ ] Nenhuma quebra visual na página — header, cards de OS, comentários, rating continuam funcionando
- [ ] Build do Eleventy roda sem erros: `cd firebase/hosting && npm run build`
