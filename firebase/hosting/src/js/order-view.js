/**
 * PraticOS - Order Tracking Page
 * Customer-facing order view via magic link
 */

(function() {
    'use strict';

    // API Configuration - auto-detect local vs production
    const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    const API_BASE = isLocalhost
        ? 'http://localhost:5000/praticos/southamerica-east1/api'
        : 'https://southamerica-east1-praticos.cloudfunctions.net/api';

    // DOM Elements
    const orderPage = document.getElementById('order-page');
    const loadingState = document.getElementById('loading-state');
    const errorState = document.getElementById('error-state');
    const orderContent = document.getElementById('order-content');

    // State
    let orderData = null;
    let token = null;

    // Language detection: use early-detection from HTML inline script, fallback to navigator
    const lang = window.__orderLang || (navigator.language || 'pt').split('-')[0];

    // Country-to-currency mapping for company-based currency formatting
    const countryCurrencyMap = {
        BR: { currency: 'BRL', locale: 'pt-BR' },
        US: { currency: 'USD', locale: 'en-US' },
        PT: { currency: 'EUR', locale: 'pt-PT' },
        ES: { currency: 'EUR', locale: 'es-ES' },
        MX: { currency: 'MXN', locale: 'es-MX' },
        AR: { currency: 'ARS', locale: 'es-AR' },
        CL: { currency: 'CLP', locale: 'es-CL' },
        CO: { currency: 'COP', locale: 'es-CO' },
        PE: { currency: 'PEN', locale: 'es-PE' },
        UY: { currency: 'UYU', locale: 'es-UY' },
        PY: { currency: 'PYG', locale: 'es-PY' },
        BO: { currency: 'BOB', locale: 'es-BO' },
        GB: { currency: 'GBP', locale: 'en-GB' },
        CA: { currency: 'CAD', locale: 'en-CA' },
        AO: { currency: 'AOA', locale: 'pt-AO' },
        MZ: { currency: 'MZN', locale: 'pt-MZ' },
    };

    // Company currency config — set when order data arrives
    let companyCurrency = { currency: 'BRL', locale: 'pt-BR' };

    // Status translations
    const statusLabels = {
        'pt': {
            quote: 'Orçamento',
            approved: 'Aprovado',
            progress: 'Em Andamento',
            done: 'Concluído',
            canceled: 'Cancelado'
        },
        'en': {
            quote: 'Quote',
            approved: 'Approved',
            progress: 'In Progress',
            done: 'Completed',
            canceled: 'Canceled'
        },
        'es': {
            quote: 'Presupuesto',
            approved: 'Aprobado',
            progress: 'En Progreso',
            done: 'Completado',
            canceled: 'Cancelado'
        }
    };

    const t = statusLabels[lang] || statusLabels['pt'];

    // Translations for UI text
    const ui = {
        pt: {
            pageTitle: 'Acompanhe sua OS - PraticOS',
            pageDescription: 'Acompanhe o status da sua ordem de serviço',
            loading: 'Carregando...',
            errorTitle: 'Link inválido',
            errorMessage: 'Este link expirou ou é inválido. Por favor, solicite um novo link.',
            customer: 'Cliente',
            device: 'Equipamento',
            name: 'Nome',
            phone: 'Telefone',
            forecast: 'Previsão',
            serviceDefault: 'Serviço',
            productDefault: 'Produto',
            qty: 'Qtd',
            photo: 'Foto',
            you: 'Você',
            services: 'Serviços',
            products: 'Produtos',
            photos: 'Fotos',
            subtotal: 'Subtotal',
            discount: 'Desconto',
            paid: 'Pago',
            total: 'Total a Pagar',
            approve: 'Aprovar Orçamento',
            reject: 'Rejeitar',
            comments: 'Comentários',
            noComments: 'Nenhum comentário ainda',
            addComment: 'Adicionar comentário...',
            send: 'Enviar',
            approveTitle: 'Aprovar Orçamento?',
            approveMessage: 'Ao aprovar, você autoriza a execução dos serviços listados.',
            rejectTitle: 'Rejeitar Orçamento?',
            rejectMessage: 'Por favor, informe o motivo da rejeição (opcional):',
            rejectPlaceholder: 'Motivo da rejeição...',
            confirm: 'Confirmar',
            cancel: 'Cancelar',
            approved: 'Orçamento aprovado com sucesso!',
            rejected: 'Orçamento rejeitado',
            commentSent: 'Comentário enviado',
            error: 'Ocorreu um erro. Tente novamente.',
            alreadyApproved: 'Este orçamento já foi aprovado',
            alreadyRejected: 'Este orçamento foi rejeitado',
            poweredBy: 'Powered by',
            team: 'Equipe',
            rateService: 'Avalie nosso serviço',
            rateDescription: 'Como foi sua experiência? Sua avaliação nos ajuda a melhorar.',
            rateCommentPlaceholder: 'Deixe um comentário sobre o serviço (opcional)',
            rateSubmit: 'Enviar Avaliação',
            rateSuccess: 'Obrigado pela sua avaliação!',
            rateAlreadyRated: 'Este serviço já foi avaliado',
            yourRating: 'Sua Avaliação',
            devices: 'Equipamentos',
            general: 'Geral'
        },
        en: {
            pageTitle: 'Track your Order - PraticOS',
            pageDescription: 'Track the status of your service order',
            loading: 'Loading...',
            errorTitle: 'Invalid link',
            errorMessage: 'This link has expired or is invalid. Please request a new link.',
            customer: 'Customer',
            device: 'Device',
            name: 'Name',
            phone: 'Phone',
            forecast: 'Expected',
            serviceDefault: 'Service',
            productDefault: 'Product',
            qty: 'Qty',
            photo: 'Photo',
            you: 'You',
            services: 'Services',
            products: 'Products',
            photos: 'Photos',
            subtotal: 'Subtotal',
            discount: 'Discount',
            paid: 'Paid',
            total: 'Total Due',
            approve: 'Approve Quote',
            reject: 'Reject',
            comments: 'Comments',
            noComments: 'No comments yet',
            addComment: 'Add a comment...',
            send: 'Send',
            approveTitle: 'Approve Quote?',
            approveMessage: 'By approving, you authorize the execution of the listed services.',
            rejectTitle: 'Reject Quote?',
            rejectMessage: 'Please provide a reason for rejection (optional):',
            rejectPlaceholder: 'Reason for rejection...',
            confirm: 'Confirm',
            cancel: 'Cancel',
            approved: 'Quote approved successfully!',
            rejected: 'Quote rejected',
            commentSent: 'Comment sent',
            error: 'An error occurred. Please try again.',
            alreadyApproved: 'This quote has already been approved',
            alreadyRejected: 'This quote has been rejected',
            poweredBy: 'Powered by',
            team: 'Team',
            rateService: 'Rate our service',
            rateDescription: 'How was your experience? Your feedback helps us improve.',
            rateCommentPlaceholder: 'Leave a comment about the service (optional)',
            rateSubmit: 'Submit Rating',
            rateSuccess: 'Thank you for your rating!',
            rateAlreadyRated: 'This service has already been rated',
            yourRating: 'Your Rating',
            devices: 'Devices',
            general: 'General'
        },
        es: {
            pageTitle: 'Seguí tu OS - PraticOS',
            pageDescription: 'Seguí el estado de tu orden de servicio',
            loading: 'Cargando...',
            errorTitle: 'Enlace inválido',
            errorMessage: 'Este enlace ha expirado o es inválido. Por favor, solicita un nuevo enlace.',
            customer: 'Cliente',
            device: 'Dispositivo',
            name: 'Nombre',
            phone: 'Teléfono',
            forecast: 'Previsión',
            serviceDefault: 'Servicio',
            productDefault: 'Producto',
            qty: 'Cant',
            photo: 'Foto',
            you: 'Usted',
            services: 'Servicios',
            products: 'Productos',
            photos: 'Fotos',
            subtotal: 'Subtotal',
            discount: 'Descuento',
            paid: 'Pagado',
            total: 'Total a Pagar',
            approve: 'Aprobar Presupuesto',
            reject: 'Rechazar',
            comments: 'Comentarios',
            noComments: 'Sin comentarios todavía',
            addComment: 'Agregar comentario...',
            send: 'Enviar',
            approveTitle: '¿Aprobar Presupuesto?',
            approveMessage: 'Al aprobar, autorizas la ejecución de los servicios listados.',
            rejectTitle: '¿Rechazar Presupuesto?',
            rejectMessage: 'Por favor, indica el motivo del rechazo (opcional):',
            rejectPlaceholder: 'Motivo del rechazo...',
            confirm: 'Confirmar',
            cancel: 'Cancelar',
            approved: '¡Presupuesto aprobado exitosamente!',
            rejected: 'Presupuesto rechazado',
            commentSent: 'Comentario enviado',
            error: 'Ocurrió un error. Intenta de nuevo.',
            alreadyApproved: 'Este presupuesto ya ha sido aprobado',
            alreadyRejected: 'Este presupuesto ha sido rechazado',
            poweredBy: 'Powered by',
            team: 'Equipo',
            rateService: 'Califica nuestro servicio',
            rateDescription: '¿Cómo fue tu experiencia? Tu opinión nos ayuda a mejorar.',
            rateCommentPlaceholder: 'Deja un comentario sobre el servicio (opcional)',
            rateSubmit: 'Enviar Calificación',
            rateSuccess: '¡Gracias por tu calificación!',
            rateAlreadyRated: 'Este servicio ya ha sido calificado',
            yourRating: 'Tu Calificación',
            devices: 'Dispositivos',
            general: 'General'
        }
    };
    const text = ui[lang] || ui['pt'];

    // Initialize
    function init() {
        // Translate static HTML elements immediately
        document.title = text.pageTitle;
        const loadingText = document.getElementById('loading-text');
        if (loadingText) loadingText.textContent = text.loading;
        const errorTitle = document.getElementById('error-title');
        if (errorTitle) errorTitle.textContent = text.errorTitle;
        const errorMessage = document.getElementById('error-message');
        if (errorMessage) errorMessage.textContent = text.errorMessage;

        // Extract token from URL path (/q/TOKEN) or query param (?token=TOKEN for local dev)
        const path = window.location.pathname;
        const match = path.match(/\/q\/([^/]+)/);
        const urlParams = new URLSearchParams(window.location.search);
        const queryToken = urlParams.get('token');

        token = match?.[1] || queryToken;

        if (!token) {
            showError();
            return;
        }

        fetchOrder();
    }

    // Fetch order data
    async function fetchOrder() {
        try {
            const response = await fetch(`${API_BASE}/public/orders/${token}`);
            const result = await response.json();

            if (!result.success) {
                throw new Error(result.error?.message || 'Failed to load order');
            }

            orderData = result.data;
            renderOrder();
        } catch (error) {
            console.error('Error fetching order:', error);
            showError(error.message);
        }
    }

    // Show error state
    function showError(message) {
        loadingState.style.display = 'none';
        errorState.style.display = 'flex';
        orderContent.style.display = 'none';

        const titleEl = document.getElementById('error-title');
        if (titleEl) titleEl.textContent = text.errorTitle;
        const msgEl = document.getElementById('error-message');
        if (msgEl) msgEl.textContent = message || text.errorMessage;
    }

    // Format currency using company's country (not viewer's locale)
    function formatCurrency(value) {
        const num = typeof value === 'number' ? value : parseFloat(value) || 0;
        return new Intl.NumberFormat(companyCurrency.locale, {
            style: 'currency',
            currency: companyCurrency.currency
        }).format(num);
    }

    // Format date
    function formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr);
        return date.toLocaleDateString(lang === 'en' ? 'en-US' : lang === 'es' ? 'es-ES' : 'pt-BR', {
            day: '2-digit',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    // Get status class
    function getStatusClass(status) {
        return status || 'quote';
    }

    // Render order
    function renderOrder() {
        loadingState.style.display = 'none';
        errorState.style.display = 'none';
        orderContent.style.display = 'block';

        const { order, company, comments, permissions, customer } = orderData;

        // Set company currency from country
        if (company?.country && countryCurrencyMap[company.country]) {
            companyCurrency = countryCurrencyMap[company.country];
        }

        // Render header
        renderHeader(order, company);

        // Render cards
        renderInfoCard(order, customer);
        renderPhotosCard(order);
        renderServicesCard(order);
        renderProductsCard(order);
        renderTotal(order);

        // Render action buttons if quote status and has approve permission
        if (order.status === 'quote' && permissions.includes('approve')) {
            renderActionButtons();
        }

        // Render rating section BEFORE comments if not yet rated (encourage rating)
        if (order.status === 'done' && !order.rating?.score) {
            renderRatingSection(order);
        }

        // Render comments if has comment permission
        if (permissions.includes('comment') || permissions.includes('view')) {
            renderComments(comments, permissions.includes('comment'));
        }

        // Render rating section AFTER comments if already rated (just for reference)
        if (order.status === 'done' && order.rating?.score) {
            renderRatingSection(order);
        }

        // Render footer
        renderFooter();

        // Render language switcher
        renderLanguageSwitcher();
    }

    // Render header
    function renderHeader(order, company) {
        const header = document.querySelector('.order-header');
        const statusLabel = t[order.status] || order.status;

        let logoHtml = '';
        if (company?.logo) {
            logoHtml = `<img src="${company.logo}" alt="${company.name}" class="company-logo">`;
        } else if (company?.name) {
            const initial = company.name.charAt(0).toUpperCase();
            logoHtml = `<div class="company-logo placeholder">${initial}</div>`;
        }

        header.innerHTML = `
            <div class="container">
                <div class="company-info">
                    ${logoHtml}
                    ${company?.name ? `<h1 class="company-name">${company.name}</h1>` : ''}
                    <div class="order-number">
                        <span>OS</span>
                        <strong>#${order.number || '---'}</strong>
                    </div>
                    <div class="status-badge ${getStatusClass(order.status)}">
                        ${statusLabel}
                    </div>
                </div>
            </div>
        `;
    }

    // Build device map from order data
    function buildDeviceMap(order) {
        const devices = order.devices?.length
            ? order.devices
            : (order.device ? [{ id: order.device.id || '_single', name: order.device.name, serial: order.device.serial }] : []);
        const map = {};
        devices.forEach(d => { map[d.id] = d.name; });
        return { map, isMulti: devices.length >= 2 };
    }

    // Render grouped items (services or products) by device
    function renderGroupedItems(items, deviceMap, renderFn) {
        const groups = {};
        items.forEach(item => {
            const key = item.deviceId || '_general';
            if (!groups[key]) groups[key] = [];
            groups[key].push(item);
        });

        let html = '';
        // Render items by device order, then general at the end
        const deviceIds = Object.keys(deviceMap.map);
        const orderedKeys = [...deviceIds.filter(k => groups[k]), ...(['_general' in groups ? ['_general'] : []])];

        // Add any deviceId keys not in the map (safety)
        Object.keys(groups).forEach(k => {
            if (!orderedKeys.includes(k)) orderedKeys.push(k);
        });

        orderedKeys.forEach(key => {
            if (!groups[key]) return;
            const label = key === '_general' ? text.general : (deviceMap.map[key] || text.general);
            html += `<div class="device-group-header">${label}</div>`;
            html += groups[key].map(renderFn).join('');
        });

        return html;
    }

    // Render info card
    function renderInfoCard(order, customer) {
        const container = document.querySelector('.order-cards');

        const customerName = order.customer?.name || customer?.name || '-';
        const customerPhone = order.customer?.phone || customer?.phone || '';
        const { map: deviceNameMap, isMulti } = buildDeviceMap(order);
        const deviceNames = Object.values(deviceNameMap);

        // Build device display
        let deviceHtml = '';
        if (deviceNames.length === 1) {
            deviceHtml = `
                    <div class="info-item">
                        <span class="info-label">${text.device}</span>
                        <span class="info-value">${deviceNames[0]}</span>
                    </div>`;
        } else if (deviceNames.length >= 2) {
            const extra = deviceNames.length - 1;
            deviceHtml = `
                    <div class="info-item">
                        <span class="info-label">${text.devices}</span>
                        <span class="info-value">${deviceNames[0]} <span class="device-more">+${extra}</span></span>
                    </div>`;
        }

        const card = document.createElement('div');
        card.className = 'order-card';
        card.innerHTML = `
            <div class="card-header">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                </svg>
                <h3>${text.customer}</h3>
            </div>
            <div class="card-body">
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-label">${text.name}</span>
                        <span class="info-value">${customerName}</span>
                    </div>
                    ${customerPhone ? `
                    <div class="info-item">
                        <span class="info-label">${text.phone}</span>
                        <span class="info-value highlight">${customerPhone}</span>
                    </div>
                    ` : ''}
                    ${deviceHtml}
                    ${order.dueDate ? `
                    <div class="info-item">
                        <span class="info-label">${text.forecast}</span>
                        <span class="info-value">${formatDate(order.dueDate)}</span>
                    </div>
                    ` : ''}
                </div>
            </div>
        `;
        container.appendChild(card);
    }

    // Render services card
    function renderServicesCard(order) {
        if (!order.services || order.services.length === 0) return;

        const container = document.querySelector('.order-cards');
        const card = document.createElement('div');
        card.className = 'order-card';

        const { map: deviceNameMap, isMulti } = buildDeviceMap(order);
        const renderServiceItem = s => `
            <div class="item-row">
                <div class="item-info">
                    <div class="item-name">${s.name || text.serviceDefault}</div>
                    ${s.description ? `<div class="item-description">${s.description}</div>` : ''}
                </div>
                <div class="item-value">${formatCurrency(s.value)}</div>
            </div>
        `;

        const itemsHtml = isMulti
            ? renderGroupedItems(order.services, { map: deviceNameMap }, renderServiceItem)
            : order.services.map(renderServiceItem).join('');

        card.innerHTML = `
            <div class="card-header">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
                </svg>
                <h3>${text.services}</h3>
            </div>
            <div class="card-body">
                <div class="items-list">${itemsHtml}</div>
            </div>
        `;
        container.appendChild(card);
    }

    // Render products card
    function renderProductsCard(order) {
        if (!order.products || order.products.length === 0) return;

        const container = document.querySelector('.order-cards');
        const card = document.createElement('div');
        card.className = 'order-card';

        const { map: deviceNameMap, isMulti } = buildDeviceMap(order);
        const renderProductItem = p => `
            <div class="item-row">
                <div class="item-info">
                    <div class="item-name">${p.name || text.productDefault}</div>
                    ${p.description ? `<div class="item-description">${p.description}</div>` : ''}
                    <div class="item-qty">${text.qty}: ${p.quantity || 1}</div>
                </div>
                <div class="item-value">${formatCurrency(p.value * (p.quantity || 1))}</div>
            </div>
        `;

        const itemsHtml = isMulti
            ? renderGroupedItems(order.products, { map: deviceNameMap }, renderProductItem)
            : order.products.map(renderProductItem).join('');

        card.innerHTML = `
            <div class="card-header">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>
                    <polyline points="3.27 6.96 12 12.01 20.73 6.96"/>
                    <line x1="12" y1="22.08" x2="12" y2="12"/>
                </svg>
                <h3>${text.products}</h3>
            </div>
            <div class="card-body">
                <div class="items-list">${itemsHtml}</div>
            </div>
        `;
        container.appendChild(card);
    }

    // Render photos card
    function renderPhotosCard(order) {
        if (!order.photos || order.photos.length === 0) return;

        const container = document.querySelector('.order-cards');
        const card = document.createElement('div');
        card.className = 'order-card photos-card';

        const photosHtml = order.photos.map((p, index) => `
            <div class="photo-item" onclick="orderView.openLightbox(${index})">
                <img src="${p.url}" alt="${p.description || text.photo}" loading="lazy">
                ${p.description ? `<div class="photo-description">${p.description}</div>` : ''}
            </div>
        `).join('');

        card.innerHTML = `
            <div class="card-header">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                    <circle cx="8.5" cy="8.5" r="1.5"/>
                    <polyline points="21 15 16 10 5 21"/>
                </svg>
                <h3>${text.photos}</h3>
            </div>
            <div class="card-body">
                <div class="photos-grid">${photosHtml}</div>
            </div>
        `;
        container.appendChild(card);
    }

    // Lightbox state
    let lightboxIndex = 0;
    let lightboxPhotos = [];
    let touchStartX = 0;
    let touchEndX = 0;

    // Open lightbox
    function openLightbox(index) {
        lightboxPhotos = orderData.order.photos || [];
        if (lightboxPhotos.length === 0) return;

        lightboxIndex = index;

        const overlay = document.createElement('div');
        overlay.className = 'lightbox-overlay';
        overlay.id = 'lightbox';
        overlay.innerHTML = `
            <div class="lightbox-header">
                <span class="lightbox-counter">${index + 1} / ${lightboxPhotos.length}</span>
                <button class="lightbox-close" onclick="orderView.closeLightbox()">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>
            <div class="lightbox-content">
                <button class="lightbox-nav lightbox-prev" onclick="orderView.prevPhoto()" ${index === 0 ? 'disabled' : ''}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="15 18 9 12 15 6"/>
                    </svg>
                </button>
                <img class="lightbox-image" src="${lightboxPhotos[index].url}" alt="${lightboxPhotos[index].description || text.photo}">
                <button class="lightbox-nav lightbox-next" onclick="orderView.nextPhoto()" ${index === lightboxPhotos.length - 1 ? 'disabled' : ''}>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="9 18 15 12 9 6"/>
                    </svg>
                </button>
            </div>
            <div class="lightbox-description">${lightboxPhotos[index].description || ''}</div>
        `;

        document.body.appendChild(overlay);
        document.body.style.overflow = 'hidden';

        // Add touch events for swipe
        const content = overlay.querySelector('.lightbox-content');
        content.addEventListener('touchstart', handleTouchStart, { passive: true });
        content.addEventListener('touchend', handleTouchEnd, { passive: true });

        // Add keyboard navigation
        document.addEventListener('keydown', handleLightboxKeydown);

        requestAnimationFrame(() => overlay.classList.add('active'));
    }

    // Close lightbox
    function closeLightbox() {
        const overlay = document.getElementById('lightbox');
        if (!overlay) return;

        document.removeEventListener('keydown', handleLightboxKeydown);
        overlay.classList.remove('active');
        document.body.style.overflow = '';

        setTimeout(() => overlay.remove(), 300);
    }

    // Navigate photos
    function updateLightbox() {
        const overlay = document.getElementById('lightbox');
        if (!overlay) return;

        const photo = lightboxPhotos[lightboxIndex];
        overlay.querySelector('.lightbox-counter').textContent = `${lightboxIndex + 1} / ${lightboxPhotos.length}`;
        overlay.querySelector('.lightbox-image').src = photo.url;
        overlay.querySelector('.lightbox-image').alt = photo.description || text.photo;
        overlay.querySelector('.lightbox-description').textContent = photo.description || '';
        overlay.querySelector('.lightbox-prev').disabled = lightboxIndex === 0;
        overlay.querySelector('.lightbox-next').disabled = lightboxIndex === lightboxPhotos.length - 1;
    }

    function prevPhoto() {
        if (lightboxIndex > 0) {
            lightboxIndex--;
            updateLightbox();
        }
    }

    function nextPhoto() {
        if (lightboxIndex < lightboxPhotos.length - 1) {
            lightboxIndex++;
            updateLightbox();
        }
    }

    // Touch handlers for swipe
    function handleTouchStart(e) {
        touchStartX = e.changedTouches[0].screenX;
    }

    function handleTouchEnd(e) {
        touchEndX = e.changedTouches[0].screenX;
        handleSwipe();
    }

    function handleSwipe() {
        const swipeThreshold = 50;
        const diff = touchStartX - touchEndX;

        if (Math.abs(diff) > swipeThreshold) {
            if (diff > 0) {
                nextPhoto(); // Swipe left = next
            } else {
                prevPhoto(); // Swipe right = prev
            }
        }
    }

    // Keyboard navigation
    function handleLightboxKeydown(e) {
        if (e.key === 'Escape') {
            closeLightbox();
        } else if (e.key === 'ArrowLeft') {
            prevPhoto();
        } else if (e.key === 'ArrowRight') {
            nextPhoto();
        }
    }

    // Render total
    function renderTotal(order) {
        const container = document.querySelector('.order-cards');
        const total = order.total || 0;
        const discount = order.discount || 0;
        const paidAmount = order.paidAmount || 0;

        // Note: order.total from the app already has discount subtracted
        // So we add it back to show the subtotal (before discount)
        const subtotal = total + discount;

        // Remaining is total minus paid (discount already applied in total)
        const remaining = total - paidAmount;

        const section = document.createElement('div');
        section.className = 'total-section';

        let html = `
            <div class="total-row">
                <span class="total-label">${text.subtotal}</span>
                <span class="total-value">${formatCurrency(subtotal)}</span>
            </div>
        `;

        if (discount > 0) {
            html += `
                <div class="total-row discount">
                    <span class="total-label">${text.discount}</span>
                    <span class="total-value">-${formatCurrency(discount)}</span>
                </div>
            `;
        }

        if (paidAmount > 0) {
            html += `
                <div class="total-row paid">
                    <span class="total-label">${text.paid}</span>
                    <span class="total-value">-${formatCurrency(paidAmount)}</span>
                </div>
            `;
        }

        html += `
            <div class="total-row grand-total">
                <span class="total-label">${text.total}</span>
                <span class="total-value">${formatCurrency(remaining)}</span>
            </div>
        `;

        section.innerHTML = html;
        container.appendChild(section);
    }

    // Rating state
    let selectedRating = 0;

    // Render rating section (for completed orders)
    function renderRatingSection(order) {
        const container = document.querySelector('.order-cards');
        const section = document.createElement('div');
        section.className = 'rating-section order-card';

        // Star SVG
        const starSvg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;

        // Check if already rated
        if (order.rating?.score) {
            // Display existing rating (read-only)
            let starsHtml = '';
            for (let i = 1; i <= 5; i++) {
                const isFilled = i <= order.rating.score;
                starsHtml += `<svg viewBox="0 0 24 24" ${isFilled ? 'fill="#FFD700" stroke="#FFD700"' : 'fill="none" stroke="currentColor" class="empty"'} stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;
            }

            section.innerHTML = `
                <div class="card-header">
                    <svg viewBox="0 0 24 24" fill="#FFD700" stroke="#FFD700" stroke-width="2">
                        <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                    </svg>
                    <h3>${text.yourRating}</h3>
                </div>
                <div class="card-body">
                    <div class="rating-display">
                        <div class="rating-stars-display">${starsHtml}</div>
                        <div class="rating-score-text">${order.rating.score}/5</div>
                        ${order.rating.comment ? `<div class="rating-comment-display">"${order.rating.comment}"</div>` : ''}
                        <div class="rating-customer-name">— ${order.rating.customerName}</div>
                    </div>
                </div>
            `;
        } else {
            // Show rating form
            let starsHtml = '';
            for (let i = 1; i <= 5; i++) {
                starsHtml += `<button class="star-rating-btn" data-rating="${i}" onclick="orderView.setRating(${i})">${starSvg}</button>`;
            }

            section.innerHTML = `
                <div class="card-header">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                    </svg>
                    <h3>${text.rateService}</h3>
                </div>
                <div class="card-body">
                    <p class="rating-description">${text.rateDescription}</p>
                    <div class="star-rating" id="star-rating">${starsHtml}</div>
                    <textarea class="rating-comment-input" id="rating-comment" placeholder="${text.rateCommentPlaceholder}" maxlength="500"></textarea>
                    <button class="btn-rating-submit" id="rating-submit" disabled onclick="orderView.submitRating()">${text.rateSubmit}</button>
                </div>
            `;
        }

        container.appendChild(section);

        // Add hover effects for stars
        if (!order.rating?.score) {
            const starBtns = section.querySelectorAll('.star-rating-btn');
            starBtns.forEach((btn, index) => {
                btn.addEventListener('mouseenter', () => {
                    starBtns.forEach((b, i) => {
                        b.classList.toggle('hover', i <= index);
                    });
                });
                btn.addEventListener('mouseleave', () => {
                    starBtns.forEach((b, i) => {
                        b.classList.remove('hover');
                        b.classList.toggle('active', i < selectedRating);
                    });
                });
            });
        }
    }

    // Set rating
    function setRating(rating) {
        selectedRating = rating;
        const starBtns = document.querySelectorAll('.star-rating-btn');
        starBtns.forEach((btn, i) => {
            btn.classList.toggle('active', i < rating);
        });
        document.getElementById('rating-submit').disabled = false;
    }

    // Submit rating
    async function submitRating() {
        if (selectedRating < 1 || selectedRating > 5) return;

        const btn = document.getElementById('rating-submit');
        const comment = document.getElementById('rating-comment')?.value?.trim() || '';

        btn.disabled = true;
        btn.textContent = '...';

        try {
            const response = await fetch(`${API_BASE}/public/orders/${token}/rating`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    score: selectedRating,
                    comment: comment || undefined
                })
            });

            const result = await response.json();

            if (result.success) {
                showToast(text.rateSuccess, 'success');
                setTimeout(() => location.reload(), 1500);
            } else {
                throw new Error(result.error?.message);
            }
        } catch (error) {
            showToast(error.message || text.error, 'error');
            btn.disabled = false;
            btn.textContent = text.rateSubmit;
        }
    }

    // Render action buttons
    function renderActionButtons() {
        const container = document.querySelector('.order-cards');
        const buttons = document.createElement('div');
        buttons.className = 'action-buttons';
        buttons.innerHTML = `
            <button class="btn btn-approve" onclick="orderView.showApproveModal()">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"/>
                </svg>
                ${text.approve}
            </button>
            <button class="btn btn-reject" onclick="orderView.showRejectModal()">
                ${text.reject}
            </button>
        `;
        container.appendChild(buttons);
    }

    // Render comments
    function renderComments(comments, canComment) {
        const container = document.querySelector('.order-cards');

        const section = document.createElement('div');
        section.className = 'comments-section order-card';

        let commentsHtml = '';
        if (comments && comments.length > 0) {
            commentsHtml = `
                <div class="comments-list" id="comments-list">
                    ${comments.map(c => `
                        <div class="comment-bubble ${c.authorType}">
                            <div class="comment-author">
                                ${c.authorType === 'customer' ?
                                    `<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/></svg>` :
                                    `<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>`
                                }
                                ${c.authorName || (c.authorType === 'customer' ? orderData.customer?.name : text.team)}
                            </div>
                            <div class="comment-text">${c.text}</div>
                            <div class="comment-time">${formatDate(c.createdAt)}</div>
                        </div>
                    `).join('')}
                </div>
            `;
        } else {
            commentsHtml = `
                <div class="no-comments">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                    </svg>
                    <p>${text.noComments}</p>
                </div>
            `;
        }

        section.innerHTML = `
            <div class="card-header">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                </svg>
                <h3>${text.comments}</h3>
            </div>
            <div class="card-body">
                ${commentsHtml}
                ${canComment ? `
                    <div class="comment-input-container">
                        <textarea
                            class="comment-input"
                            id="comment-input"
                            placeholder="${text.addComment}"
                            rows="1"
                        ></textarea>
                        <button class="btn-send" id="send-comment" onclick="orderView.sendComment()">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <line x1="22" y1="2" x2="11" y2="13"/>
                                <polygon points="22 2 15 22 11 13 2 9 22 2"/>
                            </svg>
                        </button>
                    </div>
                ` : ''}
            </div>
        `;
        container.appendChild(section);

        // Auto-resize textarea
        if (canComment) {
            const textarea = document.getElementById('comment-input');
            textarea.addEventListener('input', function() {
                this.style.height = 'auto';
                this.style.height = Math.min(this.scrollHeight, 120) + 'px';
            });
        }
    }

    // Render footer
    function renderFooter() {
        const footer = document.createElement('div');
        footer.className = 'order-footer';
        footer.innerHTML = `
            ${text.poweredBy} <a href="https://praticos.web.app" target="_blank">PraticOS</a>
        `;
        orderContent.appendChild(footer);
    }

    // Render language switcher
    function renderLanguageSwitcher() {
        const switcher = document.createElement('div');
        switcher.className = 'lang-switcher';

        const languages = [
            { code: 'pt', label: 'PT' },
            { code: 'en', label: 'EN' },
            { code: 'es', label: 'ES' }
        ];

        switcher.innerHTML = languages.map(l =>
            `<button class="lang-btn ${l.code === lang ? 'active' : ''}" data-lang="${l.code}">${l.label}</button>`
        ).join('');

        document.body.appendChild(switcher);

        switcher.addEventListener('click', (e) => {
            const btn = e.target.closest('.lang-btn');
            if (!btn || btn.classList.contains('active')) return;
            const newLang = btn.dataset.lang;
            const url = new URL(window.location);
            url.searchParams.set('lang', newLang);
            window.location.href = url.toString();
        });
    }

    // Show approve modal
    function showApproveModal() {
        showModal({
            type: 'approve',
            title: text.approveTitle,
            message: text.approveMessage,
            confirmText: text.confirm,
            cancelText: text.cancel,
            onConfirm: async () => {
                await approveOrder();
            }
        });
    }

    // Show reject modal
    function showRejectModal() {
        showModal({
            type: 'reject',
            title: text.rejectTitle,
            message: text.rejectMessage,
            placeholder: text.rejectPlaceholder,
            showInput: true,
            confirmText: text.confirm,
            cancelText: text.cancel,
            onConfirm: async (reason) => {
                await rejectOrder(reason);
            }
        });
    }

    // Generic modal
    function showModal(options) {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = `
            <div class="modal">
                <div class="modal-icon ${options.type}">
                    ${options.type === 'approve' ?
                        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>' :
                        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>'
                    }
                </div>
                <h3>${options.title}</h3>
                <p>${options.message}</p>
                ${options.showInput ? `
                    <textarea class="modal-input" id="modal-input" placeholder="${options.placeholder}" rows="3"></textarea>
                ` : ''}
                <div class="modal-buttons">
                    <button class="btn btn-secondary" id="modal-cancel">${options.cancelText}</button>
                    <button class="btn ${options.type === 'approve' ? 'btn-approve' : 'btn-reject'}" id="modal-confirm">${options.confirmText}</button>
                </div>
            </div>
        `;

        document.body.appendChild(overlay);
        requestAnimationFrame(() => overlay.classList.add('active'));

        const closeModal = () => {
            overlay.classList.remove('active');
            setTimeout(() => overlay.remove(), 300);
        };

        overlay.querySelector('#modal-cancel').onclick = closeModal;
        overlay.onclick = (e) => { if (e.target === overlay) closeModal(); };

        overlay.querySelector('#modal-confirm').onclick = async () => {
            const input = document.getElementById('modal-input');
            const value = input ? input.value : '';
            closeModal();
            await options.onConfirm(value);
        };
    }

    // Approve order
    async function approveOrder() {
        try {
            const response = await fetch(`${API_BASE}/public/orders/${token}/approve`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });

            const result = await response.json();

            if (result.success) {
                showToast(text.approved, 'success');
                setTimeout(() => location.reload(), 1500);
            } else {
                throw new Error(result.error?.message);
            }
        } catch (error) {
            showToast(error.message || text.error, 'error');
        }
    }

    // Reject order
    async function rejectOrder(reason) {
        try {
            const response = await fetch(`${API_BASE}/public/orders/${token}/reject`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reason })
            });

            const result = await response.json();

            if (result.success) {
                showToast(text.rejected, 'success');
                setTimeout(() => location.reload(), 1500);
            } else {
                throw new Error(result.error?.message);
            }
        } catch (error) {
            showToast(error.message || text.error, 'error');
        }
    }

    // Send comment
    async function sendComment() {
        const input = document.getElementById('comment-input');
        const btn = document.getElementById('send-comment');
        const commentText = input.value.trim();

        if (!commentText) return;

        btn.disabled = true;

        try {
            const response = await fetch(`${API_BASE}/public/orders/${token}/comments`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ text: commentText })
            });

            const result = await response.json();

            if (result.success) {
                input.value = '';
                input.style.height = 'auto';
                showToast(text.commentSent, 'success');

                // Add comment to list
                const list = document.getElementById('comments-list') || document.querySelector('.no-comments').parentNode;
                const noComments = document.querySelector('.no-comments');
                if (noComments) {
                    noComments.outerHTML = '<div class="comments-list" id="comments-list"></div>';
                }

                const commentsContainer = document.getElementById('comments-list');
                const newComment = document.createElement('div');
                newComment.className = 'comment-bubble customer';
                newComment.innerHTML = `
                    <div class="comment-author">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="7" r="4"/><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/></svg>
                        ${orderData.customer?.name || text.you}
                    </div>
                    <div class="comment-text">${commentText}</div>
                    <div class="comment-time">${formatDate(new Date().toISOString())}</div>
                `;
                commentsContainer.appendChild(newComment);
                commentsContainer.scrollTop = commentsContainer.scrollHeight;
            } else {
                throw new Error(result.error?.message);
            }
        } catch (error) {
            showToast(error.message || text.error, 'error');
        } finally {
            btn.disabled = false;
        }
    }

    // Toast notification
    function showToast(message, type = 'success') {
        const existing = document.querySelector('.toast');
        if (existing) existing.remove();

        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            ${type === 'success' ?
                '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>' :
                '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>'
            }
            <span>${message}</span>
        `;
        document.body.appendChild(toast);

        requestAnimationFrame(() => toast.classList.add('show'));

        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // Public API
    window.orderView = {
        showApproveModal,
        showRejectModal,
        sendComment,
        openLightbox,
        closeLightbox,
        prevPhoto,
        nextPhoto,
        setRating,
        submitRating
    };

    // Start
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
