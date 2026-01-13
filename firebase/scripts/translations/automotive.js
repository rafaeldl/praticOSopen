// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - AUTOMOTIVO (Oficina Mecânica)
// ═══════════════════════════════════════════════════════════════════════════

const AUTOMOTIVE_TRANSLATIONS = {
  checklist_entrada_auto: {
    title: {
      pt: 'Entrada do Veículo',
      en: 'Vehicle Check-in',
      es: 'Entrada del Vehículo',
    },
    description: {
      pt: 'Registre fotos e o estado inicial do veículo ao receber.',
      en: 'Record photos and initial condition of the vehicle upon receipt.',
      es: 'Registre fotos y el estado inicial del vehículo al recibirlo.',
    },
    items: {
      lataria_fotos: {
        label: {
          pt: 'Fotos da Lataria (Avarias)',
          en: 'Body Photos (Damages)',
          es: 'Fotos de la Carrocería (Daños)',
        },
      },
      nivel_combustivel: {
        label: {
          pt: 'Nível de Combustível',
          en: 'Fuel Level',
          es: 'Nivel de Combustible',
        },
        options: {
          pt: ['Reserva', '1/4', '1/2', '3/4', 'Cheio'],
          en: ['Reserve', '1/4', '1/2', '3/4', 'Full'],
          es: ['Reserva', '1/4', '1/2', '3/4', 'Lleno'],
        },
      },
      luzes_painel: {
        label: {
          pt: 'Luzes no Painel Acesas',
          en: 'Dashboard Warning Lights',
          es: 'Luces del Tablero Encendidas',
        },
        options: {
          pt: ['Injeção', 'Freio ABS', 'Airbag', 'Bateria', 'Óleo', 'Motor', 'Temperatura'],
          en: ['Injection', 'ABS Brake', 'Airbag', 'Battery', 'Oil', 'Engine', 'Temperature'],
          es: ['Inyección', 'Freno ABS', 'Airbag', 'Batería', 'Aceite', 'Motor', 'Temperatura'],
        },
      },
      km_atual: {
        label: {
          pt: 'Quilometragem Atual',
          en: 'Current Mileage',
          es: 'Kilometraje Actual',
        },
      },
      pertences: {
        label: {
          pt: 'Pertences no Veículo',
          en: 'Belongings in Vehicle',
          es: 'Pertenencias en el Vehículo',
        },
      },
    },
  },

  revisao_basica: {
    title: {
      pt: 'Revisão Básica',
      en: 'Basic Service',
      es: 'Revisión Básica',
    },
    description: {
      pt: 'Confirma troca de óleo, filtros e níveis de fluidos.',
      en: 'Confirms oil change, filters and fluid levels.',
      es: 'Confirma cambio de aceite, filtros y niveles de fluidos.',
    },
    items: {
      oleo_motor: {
        label: {
          pt: 'Óleo do Motor Trocado',
          en: 'Engine Oil Changed',
          es: 'Aceite del Motor Cambiado',
        },
      },
      filtro_oleo: {
        label: {
          pt: 'Filtro de Óleo Trocado',
          en: 'Oil Filter Changed',
          es: 'Filtro de Aceite Cambiado',
        },
      },
      filtro_ar: {
        label: {
          pt: 'Filtro de Ar Verificado',
          en: 'Air Filter Checked',
          es: 'Filtro de Aire Verificado',
        },
      },
      filtro_cabine: {
        label: {
          pt: 'Filtro de Cabine Verificado',
          en: 'Cabin Filter Checked',
          es: 'Filtro de Cabina Verificado',
        },
      },
      nivel_liquidos: {
        label: {
          pt: 'Verificação dos Níveis',
          en: 'Fluid Levels Check',
          es: 'Verificación de Niveles',
        },
        options: {
          pt: ['Arrefecimento', 'Freio', 'Direção Hidráulica', 'Limpador'],
          en: ['Coolant', 'Brake', 'Power Steering', 'Washer'],
          es: ['Refrigerante', 'Freno', 'Dirección Hidráulica', 'Limpiaparabrisas'],
        },
      },
    },
  },

  inspecao_freios: {
    title: {
      pt: 'Inspeção de Freios',
      en: 'Brake Inspection',
      es: 'Inspección de Frenos',
    },
    description: {
      pt: 'Avalie pastilhas, discos e fluido para indicar trocas.',
      en: 'Evaluate pads, rotors and fluid to indicate replacements.',
      es: 'Evalúe pastillas, discos y fluido para indicar cambios.',
    },
    items: {
      pastilhas_dianteiras: {
        label: {
          pt: 'Estado das Pastilhas Dianteiras',
          en: 'Front Brake Pads Condition',
          es: 'Estado de las Pastillas Delanteras',
        },
        options: {
          pt: ['Bom (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Trocar'],
          en: ['Good (>50%)', 'Fair (30-50%)', 'Worn (<30%)', 'Replace'],
          es: ['Bueno (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Cambiar'],
        },
      },
      pastilhas_traseiras: {
        label: {
          pt: 'Estado das Pastilhas Traseiras',
          en: 'Rear Brake Pads Condition',
          es: 'Estado de las Pastillas Traseras',
        },
        options: {
          pt: ['Bom (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Trocar'],
          en: ['Good (>50%)', 'Fair (30-50%)', 'Worn (<30%)', 'Replace'],
          es: ['Bueno (>50%)', 'Regular (30-50%)', 'Desgastado (<30%)', 'Cambiar'],
        },
      },
      discos_dianteiros: {
        label: {
          pt: 'Discos Dianteiros',
          en: 'Front Rotors',
          es: 'Discos Delanteros',
        },
        options: {
          pt: ['OK', 'Empenado', 'Desgastado', 'Trocar'],
          en: ['OK', 'Warped', 'Worn', 'Replace'],
          es: ['OK', 'Deformado', 'Desgastado', 'Cambiar'],
        },
      },
      fluido_freio: {
        label: {
          pt: 'Fluido de Freio',
          en: 'Brake Fluid',
          es: 'Fluido de Freno',
        },
        options: {
          pt: ['OK', 'Baixo', 'Contaminado', 'Trocar'],
          en: ['OK', 'Low', 'Contaminated', 'Replace'],
          es: ['OK', 'Bajo', 'Contaminado', 'Cambiar'],
        },
      },
      freio_mao: {
        label: {
          pt: 'Freio de Mão Funcionando',
          en: 'Parking Brake Working',
          es: 'Freno de Mano Funcionando',
        },
      },
      observacoes_freios: {
        label: {
          pt: 'Observações',
          en: 'Notes',
          es: 'Observaciones',
        },
      },
    },
  },

  teste_rodagem: {
    title: {
      pt: 'Teste de Rodagem',
      en: 'Road Test',
      es: 'Prueba de Rodaje',
    },
    description: {
      pt: 'Valide o veículo após o serviço em curto trajeto.',
      en: 'Validate the vehicle after service with a short drive.',
      es: 'Valide el vehículo después del servicio en un trayecto corto.',
    },
    items: {
      km_teste: {
        label: {
          pt: 'Quilometragem do Teste',
          en: 'Test Mileage',
          es: 'Kilometraje de Prueba',
        },
      },
      ruidos: {
        label: {
          pt: 'Ruídos Identificados',
          en: 'Noises Identified',
          es: 'Ruidos Identificados',
        },
        options: {
          pt: ['Motor', 'Suspensão', 'Freios', 'Câmbio', 'Direção', 'Nenhum'],
          en: ['Engine', 'Suspension', 'Brakes', 'Transmission', 'Steering', 'None'],
          es: ['Motor', 'Suspensión', 'Frenos', 'Transmisión', 'Dirección', 'Ninguno'],
        },
      },
      vibracao: {
        label: {
          pt: 'Vibração no Volante',
          en: 'Steering Wheel Vibration',
          es: 'Vibración en el Volante',
        },
      },
      freio_ok: {
        label: {
          pt: 'Frenagem Normal',
          en: 'Normal Braking',
          es: 'Frenado Normal',
        },
      },
      direcao_ok: {
        label: {
          pt: 'Direção Alinhada',
          en: 'Steering Aligned',
          es: 'Dirección Alineada',
        },
      },
      aprovado: {
        label: {
          pt: 'Veículo Aprovado no Teste',
          en: 'Vehicle Approved in Test',
          es: 'Vehículo Aprobado en Prueba',
        },
      },
    },
  },

  entrega_veiculo: {
    title: {
      pt: 'Entrega do Veículo',
      en: 'Vehicle Delivery',
      es: 'Entrega del Vehículo',
    },
    description: {
      pt: 'Confirme limpeza, itens devolvidos e serviços com o cliente.',
      en: 'Confirm cleaning, returned items and services with the customer.',
      es: 'Confirme limpieza, artículos devueltos y servicios con el cliente.',
    },
    items: {
      veiculo_limpo: {
        label: {
          pt: 'Veículo Lavado/Limpo',
          en: 'Vehicle Washed/Cleaned',
          es: 'Vehículo Lavado/Limpio',
        },
      },
      servicos_conferidos: {
        label: {
          pt: 'Serviços Conferidos com Cliente',
          en: 'Services Reviewed with Customer',
          es: 'Servicios Revisados con el Cliente',
        },
      },
      itens_devolvidos: {
        label: {
          pt: 'Itens Devolvidos',
          en: 'Items Returned',
          es: 'Artículos Devueltos',
        },
        options: {
          pt: ['Documentos', 'Chaves', 'Estepe', 'Triângulo', 'Macaco'],
          en: ['Documents', 'Keys', 'Spare Tire', 'Triangle', 'Jack'],
          es: ['Documentos', 'Llaves', 'Rueda de Repuesto', 'Triángulo', 'Gato'],
        },
      },
      foto_painel: {
        label: {
          pt: 'Foto do Painel (km final)',
          en: 'Dashboard Photo (final mileage)',
          es: 'Foto del Tablero (km final)',
        },
      },
    },
  },

  termo_autorizacao_automotive: {
    title: {
      pt: 'Autorização do Cliente (Veículo)',
      en: 'Customer Authorization (Vehicle)',
      es: 'Autorización del Cliente (Vehículo)',
    },
    description: {
      pt: 'Registra consentimento para testes, movimentação e fotos.',
      en: 'Records consent for tests, movement and photos.',
      es: 'Registra consentimiento para pruebas, movimiento y fotos.',
    },
    items: {
      autorizacao_movimentacao: {
        label: {
          pt: 'Autorizo a movimentação do veículo na oficina',
          en: 'I authorize the movement of the vehicle in the shop',
          es: 'Autorizo el movimiento del vehículo en el taller',
        },
      },
      autorizacao_teste_rodagem: {
        label: {
          pt: 'Autorizo teste de rodagem quando necessário',
          en: 'I authorize road test when necessary',
          es: 'Autorizo prueba de rodaje cuando sea necesario',
        },
      },
      ciencia_registro_fotos: {
        label: {
          pt: 'Ciente do registro de fotos para evidências do serviço',
          en: 'Aware of photo documentation for service evidence',
          es: 'Enterado del registro fotográfico para evidencias del servicio',
        },
      },
      itens_sensiveis: {
        label: {
          pt: 'Itens sensíveis/valor no veículo',
          en: 'Sensitive/valuable items in vehicle',
          es: 'Artículos sensibles/de valor en el vehículo',
        },
        options: {
          pt: ['Dashcam', 'Som/Multimídia', 'Ferramentas', 'Objetos de valor', 'Sem itens'],
          en: ['Dashcam', 'Audio/Multimedia', 'Tools', 'Valuables', 'No items'],
          es: ['Dashcam', 'Audio/Multimedia', 'Herramientas', 'Objetos de valor', 'Sin artículos'],
        },
      },
      observacoes_cliente: {
        label: {
          pt: 'Observações do Cliente',
          en: 'Customer Notes',
          es: 'Observaciones del Cliente',
        },
      },
    },
  },

  checklist_seguranca_final_auto: {
    title: {
      pt: 'Segurança Final do Veículo',
      en: 'Final Vehicle Safety Check',
      es: 'Seguridad Final del Vehículo',
    },
    description: {
      pt: 'Revisão final de itens críticos antes da liberação.',
      en: 'Final review of critical items before release.',
      es: 'Revisión final de ítems críticos antes de la liberación.',
    },
    items: {
      torque_rodas: {
        label: {
          pt: 'Torque/Reaperto das rodas conferido (se aplicável)',
          en: 'Wheel torque checked (if applicable)',
          es: 'Torque de ruedas verificado (si aplica)',
        },
      },
      nivel_oleo: {
        label: {
          pt: 'Nível de óleo verificado',
          en: 'Oil level checked',
          es: 'Nivel de aceite verificado',
        },
        options: {
          pt: ['OK', 'Baixo', 'Não aplicável'],
          en: ['OK', 'Low', 'Not applicable'],
          es: ['OK', 'Bajo', 'No aplica'],
        },
      },
      nivel_fluido_freio: {
        label: {
          pt: 'Nível do fluido de freio verificado',
          en: 'Brake fluid level checked',
          es: 'Nivel de fluido de freno verificado',
        },
        options: {
          pt: ['OK', 'Baixo', 'Não aplicável'],
          en: ['OK', 'Low', 'Not applicable'],
          es: ['OK', 'Bajo', 'No aplica'],
        },
      },
      verificacao_vazamentos: {
        label: {
          pt: 'Verificação de vazamentos',
          en: 'Leak check',
          es: 'Verificación de fugas',
        },
        options: {
          pt: ['Sem vazamentos', 'Vazamento identificado'],
          en: ['No leaks', 'Leak identified'],
          es: ['Sin fugas', 'Fuga identificada'],
        },
      },
      luzes_externas: {
        label: {
          pt: 'Luzes externas testadas',
          en: 'External lights tested',
          es: 'Luces externas probadas',
        },
        options: {
          pt: ['Farol baixo', 'Farol alto', 'Lanterna', 'Freio', 'Ré', 'Setas', 'Não aplicável'],
          en: ['Low beam', 'High beam', 'Tail light', 'Brake', 'Reverse', 'Turn signals', 'Not applicable'],
          es: ['Luz baja', 'Luz alta', 'Luz trasera', 'Freno', 'Reversa', 'Direccionales', 'No aplica'],
        },
      },
      foto_compartimento_motor: {
        label: {
          pt: 'Foto do compartimento do motor (pós-serviço)',
          en: 'Engine compartment photo (post-service)',
          es: 'Foto del compartimento del motor (post-servicio)',
        },
      },
      observacoes: {
        label: {
          pt: 'Observações',
          en: 'Notes',
          es: 'Observaciones',
        },
      },
    },
  },
};

module.exports = { AUTOMOTIVE_TRANSLATIONS };
