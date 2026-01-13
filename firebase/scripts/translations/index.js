// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES DOS FORMULÁRIOS GLOBAIS - ÍNDICE
// ═══════════════════════════════════════════════════════════════════════════
// Importa e exporta todas as traduções de formulários por segmento

const { AUTOMOTIVE_TRANSLATIONS } = require('./automotive');
const { HVAC_TRANSLATIONS } = require('./hvac');
const { SMARTPHONES_TRANSLATIONS } = require('./smartphones');
const { COMPUTERS_TRANSLATIONS } = require('./computers');
const { APPLIANCES_TRANSLATIONS } = require('./appliances');
const { ELECTRICAL_TRANSLATIONS } = require('./electrical');
const { PLUMBING_TRANSLATIONS } = require('./plumbing');
const { SECURITY_TRANSLATIONS } = require('./security');
const { SOLAR_TRANSLATIONS } = require('./solar');
const { PRINTERS_TRANSLATIONS } = require('./printers');
const { GENERIC_TRANSLATIONS } = require('./generic');

// Combina todas as traduções em um único objeto
const FORM_TRANSLATIONS = {
  ...AUTOMOTIVE_TRANSLATIONS,
  ...HVAC_TRANSLATIONS,
  ...SMARTPHONES_TRANSLATIONS,
  ...COMPUTERS_TRANSLATIONS,
  ...APPLIANCES_TRANSLATIONS,
  ...ELECTRICAL_TRANSLATIONS,
  ...PLUMBING_TRANSLATIONS,
  ...SECURITY_TRANSLATIONS,
  ...SOLAR_TRANSLATIONS,
  ...PRINTERS_TRANSLATIONS,
  ...GENERIC_TRANSLATIONS,
};

/**
 * Aplica traduções i18n a um formulário
 * @param {Object} form - Formulário original (do seed_forms.js)
 * @returns {Object} - Formulário com campos i18n adicionados
 */
function applyTranslations(form) {
  const translations = FORM_TRANSLATIONS[form.id];
  if (!translations) {
    console.warn(`No translations found for form: ${form.id}`);
    return form;
  }

  // Aplica traduções ao formulário
  const translatedForm = {
    ...form,
    titleI18n: translations.title,
    descriptionI18n: translations.description,
    items: form.items.map((item) => {
      const itemTranslations = translations.items?.[item.id];
      if (!itemTranslations) {
        return item;
      }

      // Só adiciona campos i18n se eles existirem (não são undefined)
      const translatedItem = { ...item };
      if (itemTranslations.label) {
        translatedItem.labelI18n = itemTranslations.label;
      }
      if (itemTranslations.options) {
        translatedItem.optionsI18n = itemTranslations.options;
      }

      return translatedItem;
    }),
  };

  return translatedForm;
}

/**
 * Aplica traduções a todos os formulários de um segmento
 * @param {Array} forms - Array de formulários
 * @returns {Array} - Array de formulários com traduções
 */
function applyTranslationsToForms(forms) {
  return forms.map(applyTranslations);
}

module.exports = {
  FORM_TRANSLATIONS,
  applyTranslations,
  applyTranslationsToForms,
};
