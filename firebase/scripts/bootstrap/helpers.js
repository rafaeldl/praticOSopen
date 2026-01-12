/**
 * Helper para criar objetos de tradução
 * @param {string} ptBR - Texto em português
 * @param {string} enUS - Texto em inglês
 * @param {string} esES - Texto em espanhol
 * @returns {Object} Objeto com traduções
 */
const t = (ptBR, enUS, esES) => ({
  'pt-BR': ptBR,
  'en-US': enUS,
  'es-ES': esES,
});

module.exports = { t };
