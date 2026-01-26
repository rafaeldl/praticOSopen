/**
 * Simple HTML include loader for static sites
 * Usage: <div data-include="/components/pricing-pt.html"></div>
 */
(function() {
    document.addEventListener('DOMContentLoaded', function() {
        const includes = document.querySelectorAll('[data-include]');
        
        includes.forEach(function(el) {
            const file = el.getAttribute('data-include');
            
            fetch(file)
                .then(response => {
                    if (!response.ok) throw new Error('Failed to load ' + file);
                    return response.text();
                })
                .then(html => {
                    el.outerHTML = html;
                    
                    // Trigger animations for pricing cards if they exist
                    const cards = document.querySelectorAll('.pricing-card');
                    cards.forEach((card, index) => {
                        setTimeout(() => {
                            card.classList.add('visible');
                        }, index * 100);
                    });
                })
                .catch(err => {
                    console.error('Include error:', err);
                    el.innerHTML = '<!-- Failed to load component -->';
                });
        });
    });
})();
