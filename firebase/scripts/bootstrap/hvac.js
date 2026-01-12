const { t } = require('./helpers');

module.exports = {
  _customer: {
    name: t('Maria Santos (Exemplo)', 'Mary Johnson (Example)', 'María López (Ejemplo)'),
    phone: '(11) 99999-0000',
    email: 'exemplo@praticos.app',
    address: t('Av. Exemplo, 456', '456 Example Ave', 'Av. Ejemplo, 456'),
  },

  residential: {
    services: [
      { name: t('Instalação de split', 'Split AC Installation', 'Instalación de split'), value: 350.00, description: t('Instalação completa de ar split', 'Complete split AC installation', 'Instalación completa de aire split') },
      { name: t('Manutenção preventiva', 'Preventive Maintenance', 'Mantenimiento preventivo'), value: 180.00, description: t('Limpeza e verificação geral', 'Cleaning and general inspection', 'Limpieza y verificación general') },
      { name: t('Higienização', 'Sanitization', 'Higienización'), value: 120.00, description: t('Limpeza profunda com produtos específicos', 'Deep cleaning with specific products', 'Limpieza profunda con productos específicos') },
      { name: t('Carga de gás', 'Gas Recharge', 'Carga de gas'), value: 250.00, description: t('Recarga de gás refrigerante', 'Refrigerant gas recharge', 'Recarga de gas refrigerante') },
      { name: t('Reparo de vazamento', 'Leak Repair', 'Reparación de fugas'), value: 200.00, description: t('Detecção e reparo de vazamentos', 'Leak detection and repair', 'Detección y reparación de fugas') },
      { name: t('Troca de capacitor', 'Capacitor Replacement', 'Cambio de capacitor'), value: 150.00, description: t('Substituição de capacitor queimado', 'Burnt capacitor replacement', 'Sustitución de capacitor quemado') },
      { name: t('Desinstalação', 'Uninstallation', 'Desinstalación'), value: 150.00, description: t('Remoção segura do equipamento', 'Safe equipment removal', 'Retiro seguro del equipo') },
      { name: t('Instalação de suporte', 'Bracket Installation', 'Instalación de soporte'), value: 120.00, description: t('Instalação de suporte para condensadora', 'Condenser bracket installation', 'Instalación de soporte para condensadora') },
    ],
    products: [
      { name: t('Gás R410A (kg)', 'R410A Gas (kg)', 'Gas R410A (kg)'), value: 120.00 },
      { name: t('Gás R32 (kg)', 'R32 Gas (kg)', 'Gas R32 (kg)'), value: 130.00 },
      { name: t('Capacitor 35μF', '35μF Capacitor', 'Capacitor 35μF'), value: 45.00 },
      { name: t('Capacitor 25μF', '25μF Capacitor', 'Capacitor 25μF'), value: 40.00 },
      { name: t('Filtro de ar (universal)', 'Air Filter (universal)', 'Filtro de aire (universal)'), value: 25.00 },
      { name: t('Suporte para condensadora', 'Condenser Bracket', 'Soporte para condensadora'), value: 85.00 },
      { name: t('Tubo de cobre 1/4 (metro)', '1/4 Copper Tube (meter)', 'Tubo de cobre 1/4 (metro)'), value: 35.00 },
      { name: t('Fita térmica (rolo)', 'Thermal Tape (roll)', 'Cinta térmica (rollo)'), value: 18.00 },
    ],
    devices: [
      { name: 'Split 12000 BTUs', manufacturer: 'Samsung', category: 'Split', customFields: { btus: '12000', voltage: '220V', gasType: 'R-410A' } },
      { name: 'Split 9000 BTUs', manufacturer: 'LG', category: 'Split', customFields: { btus: '9000', voltage: '220V', gasType: 'R-32' } },
    ],
  },

  commercial: {
    services: [
      { name: t('Instalação de VRF', 'VRF Installation', 'Instalación de VRF'), value: 2500.00, description: t('Instalação de sistema VRF', 'VRF system installation', 'Instalación de sistema VRF') },
      { name: t('Manutenção de chiller', 'Chiller Maintenance', 'Mantenimiento de chiller'), value: 800.00, description: t('Manutenção preventiva de chiller', 'Chiller preventive maintenance', 'Mantenimiento preventivo de chiller') },
      { name: t('Manutenção de câmara fria', 'Cold Room Maintenance', 'Mantenimiento de cámara fría'), value: 600.00, description: t('Verificação e ajustes de câmara fria', 'Cold room inspection and adjustments', 'Verificación y ajustes de cámara fría') },
      { name: t('Carga de gás industrial', 'Industrial Gas Recharge', 'Carga de gas industrial'), value: 450.00, description: t('Recarga de gás em equipamentos comerciais', 'Gas recharge for commercial equipment', 'Recarga de gas en equipos comerciales') },
      { name: t('Limpeza de dutos', 'Duct Cleaning', 'Limpieza de ductos'), value: 350.00, description: t('Limpeza de sistema de dutos', 'Duct system cleaning', 'Limpieza de sistema de ductos') },
      { name: t('Balanceamento de vazão', 'Airflow Balancing', 'Balanceo de flujo de aire'), value: 400.00, description: t('Ajuste de vazão de ar em ambientes', 'Airflow adjustment in environments', 'Ajuste de flujo de aire en ambientes') },
      { name: t('Manutenção preventiva predial', 'Building Preventive Maintenance', 'Mantenimiento preventivo de edificio'), value: 500.00, description: t('Contrato de manutenção mensal', 'Monthly maintenance contract', 'Contrato de mantenimiento mensual') },
      { name: t('Reparo de fancoil', 'Fancoil Repair', 'Reparación de fancoil'), value: 300.00, description: t('Manutenção de fancoil', 'Fancoil maintenance', 'Mantenimiento de fancoil') },
    ],
    products: [
      { name: t('Gás R410A (kg)', 'R410A Gas (kg)', 'Gas R410A (kg)'), value: 120.00 },
      { name: t('Gás R404A (kg)', 'R404A Gas (kg)', 'Gas R404A (kg)'), value: 150.00 },
      { name: t('Compressor rotativo', 'Rotary Compressor', 'Compresor rotativo'), value: 1200.00 },
      { name: t('Motor ventilador', 'Fan Motor', 'Motor ventilador'), value: 450.00 },
      { name: t('Filtro de ar industrial', 'Industrial Air Filter', 'Filtro de aire industrial'), value: 85.00 },
      { name: t('Termostato digital', 'Digital Thermostat', 'Termostato digital'), value: 180.00 },
      { name: t('Válvula de expansão', 'Expansion Valve', 'Válvula de expansión'), value: 350.00 },
      { name: t('Pressostato', 'Pressure Switch', 'Presostato'), value: 120.00 },
    ],
    devices: [
      { name: 'Cassete 36000 BTUs', manufacturer: 'Daikin', category: 'Cassete', customFields: { btus: '36000', voltage: '220V', gasType: 'R-410A' } },
      { name: t('Split Piso Teto 48000 BTUs', 'Floor Ceiling Split 48000 BTUs', 'Split Piso Techo 48000 BTUs'), manufacturer: 'Carrier', category: t('Piso Teto', 'Floor Ceiling', 'Piso Techo'), customFields: { btus: '48000', voltage: t('Bifásico', 'Biphasic', 'Bifásico'), gasType: 'R-410A' } },
      { name: t('Câmara Fria 10m³', 'Cold Room 10m³', 'Cámara Fría 10m³'), manufacturer: 'Elgin', category: t('Câmara Fria', 'Cold Room', 'Cámara Fría'), customFields: { voltage: '220V', gasType: 'R-404A' } },
    ],
  },

  automotive_ac: {
    services: [
      { name: t('Recarga de gás', 'Gas Recharge', 'Recarga de gas'), value: 200.00, description: t('Recarga de gás R134a', 'R134a gas recharge', 'Recarga de gas R134a') },
      { name: t('Higienização do sistema', 'System Sanitization', 'Higienización del sistema'), value: 120.00, description: t('Limpeza do sistema de ar', 'AC system cleaning', 'Limpieza del sistema de aire') },
      { name: t('Troca de filtro de cabine', 'Cabin Filter Replacement', 'Cambio de filtro de cabina'), value: 80.00, description: t('Substituição do filtro antipólen', 'Pollen filter replacement', 'Sustitución del filtro antipolen') },
      { name: t('Reparo de compressor', 'Compressor Repair', 'Reparación de compresor'), value: 450.00, description: t('Reparo ou substituição do compressor', 'Compressor repair or replacement', 'Reparación o sustitución del compresor') },
      { name: t('Troca de condensador', 'Condenser Replacement', 'Cambio de condensador'), value: 350.00, description: t('Substituição do condensador', 'Condenser replacement', 'Sustitución del condensador') },
      { name: t('Troca de evaporador', 'Evaporator Replacement', 'Cambio de evaporador'), value: 400.00, description: t('Substituição do evaporador', 'Evaporator replacement', 'Sustitución del evaporador') },
      { name: t('Diagnóstico de vazamento', 'Leak Diagnosis', 'Diagnóstico de fugas'), value: 100.00, description: t('Detecção de vazamentos no sistema', 'System leak detection', 'Detección de fugas en el sistema') },
      { name: t('Troca de válvula de expansão', 'Expansion Valve Replacement', 'Cambio de válvula de expansión'), value: 250.00, description: t('Substituição da válvula de expansão', 'Expansion valve replacement', 'Sustitución de la válvula de expansión') },
    ],
    products: [
      { name: t('Gás R134a (kg)', 'R134a Gas (kg)', 'Gas R134a (kg)'), value: 100.00 },
      { name: t('Gás R1234yf (kg)', 'R1234yf Gas (kg)', 'Gas R1234yf (kg)'), value: 350.00 },
      { name: t('Filtro secador', 'Receiver Drier', 'Filtro secador'), value: 85.00 },
      { name: t('Óleo PAG (250ml)', 'PAG Oil (250ml)', 'Aceite PAG (250ml)'), value: 65.00 },
      { name: t('Filtro de cabine', 'Cabin Filter', 'Filtro de cabina'), value: 45.00 },
      { name: t('Válvula de expansão universal', 'Universal Expansion Valve', 'Válvula de expansión universal'), value: 180.00 },
      { name: t('Pressostato automotivo', 'Automotive Pressure Switch', 'Presostato automotriz'), value: 95.00 },
      { name: t('Anel de vedação (kit)', 'O-Ring Kit', 'Kit de anillos de sellado'), value: 35.00 },
    ],
    devices: [
      { name: 'Civic EXL', manufacturer: 'Honda', category: 'Sedan', customFields: { year: 2022, mileage: 35000, gasType: 'R-134a' } },
      { name: 'Hilux SRV', manufacturer: 'Toyota', category: 'Pickup', customFields: { year: 2021, mileage: 62000, gasType: 'R-134a' } },
    ],
  },
};
