// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - MANUTENÇÃO DE ATIVOS (máquinas e equipamentos)
// ═══════════════════════════════════════════════════════════════════════════

const ASSET_MAINTENANCE_TRANSLATIONS = {
  checklist_entrada_asset: {
    title: {
      pt: 'Entrada do Equipamento',
      en: 'Equipment Check-in',
      es: 'Entrada del Equipo',
    },
    description: {
      pt: 'Registre fotos, horímetro e o estado do equipamento ao receber.',
      en: 'Record photos, hour meter and the condition of the equipment upon receipt.',
      es: 'Registre fotos, horómetro y el estado del equipo al recibirlo.',
    },
    items: {
      fotos: { label: { pt: 'Fotos do equipamento', en: 'Equipment photos', es: 'Fotos del equipo' } },
      horas_operacao: {
        label: {
          pt: 'Horas de operação (horímetro)',
          en: 'Operating hours (hour meter)',
          es: 'Horas de operación (horómetro)',
        },
      },
      numero_serie: { label: { pt: 'Número de série', en: 'Serial number', es: 'Número de serie' } },
      estado: {
        label: { pt: 'Estado geral', en: 'General condition', es: 'Estado general' },
        options: {
          pt: ['Bom', 'Regular', 'Ruim', 'Parado'],
          en: ['Good', 'Fair', 'Poor', 'Not running'],
          es: ['Bueno', 'Regular', 'Malo', 'Parado'],
        },
      },
      defeito: { label: { pt: 'Defeito relatado', en: 'Reported issue', es: 'Falla reportada' } },
    },
  },
};

module.exports = { ASSET_MAINTENANCE_TRANSLATIONS };
