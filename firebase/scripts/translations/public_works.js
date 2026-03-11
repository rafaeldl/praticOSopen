// ═══════════════════════════════════════════════════════════════════════════
// TRADUÇÕES - OBRAS PÚBLICAS / PREFEITURAS
// ═══════════════════════════════════════════════════════════════════════════

const PUBLIC_WORKS_TRANSLATIONS = {
  medicao_obra: {
    title: {
      pt: 'Medição de Obra',
      en: 'Work Measurement',
      es: 'Medición de Obra',
    },
    description: {
      pt: 'Registro de medição para liberação de recursos.',
      en: 'Measurement record for resource release.',
      es: 'Registro de medición para liberación de recursos.',
    },
    items: {
      milestone_id: {
        label: {
          pt: 'Etapa/Marco',
          en: 'Milestone',
          es: 'Etapa/Hito',
        },
      },
      planned_percentage: {
        label: {
          pt: '% Previsto',
          en: 'Planned %',
          es: '% Previsto',
        },
      },
      executed_percentage: {
        label: {
          pt: '% Executado',
          en: 'Executed %',
          es: '% Ejecutado',
        },
      },
      quality_assessment: {
        label: {
          pt: 'Avaliação de Qualidade',
          en: 'Quality Assessment',
          es: 'Evaluación de Calidad',
        },
        options: {
          pt: ['Conforme', 'Com Ressalvas', 'Não Conforme'],
          en: ['Compliant', 'With Reservations', 'Non-Compliant'],
          es: ['Conforme', 'Con Reservas', 'No Conforme'],
        },
      },
      materials_conformity: {
        label: {
          pt: 'Materiais em Conformidade',
          en: 'Materials Compliant',
          es: 'Materiales en Conformidad',
        },
      },
      safety_conditions: {
        label: {
          pt: 'Condições de Segurança Adequadas',
          en: 'Adequate Safety Conditions',
          es: 'Condiciones de Seguridad Adecuadas',
        },
      },
      environmental_compliance: {
        label: {
          pt: 'Conformidade Ambiental',
          en: 'Environmental Compliance',
          es: 'Conformidad Ambiental',
        },
      },
      observations: {
        label: {
          pt: 'Observações',
          en: 'Observations',
          es: 'Observaciones',
        },
      },
      photo_evidence: {
        label: {
          pt: 'Evidência Fotográfica',
          en: 'Photo Evidence',
          es: 'Evidencia Fotográfica',
        },
      },
    },
  },

  vistoria_andamento: {
    title: {
      pt: 'Vistoria de Andamento',
      en: 'Progress Inspection',
      es: 'Inspección de Avance',
    },
    description: {
      pt: 'Registro de vistoria periódica da obra.',
      en: 'Periodic project inspection record.',
      es: 'Registro de inspección periódica de la obra.',
    },
    items: {
      site_access: {
        label: {
          pt: 'Acesso ao Local Liberado',
          en: 'Site Access Available',
          es: 'Acceso al Sitio Liberado',
        },
      },
      worker_count: {
        label: {
          pt: 'Nº de Trabalhadores no Local',
          en: 'Number of Workers on Site',
          es: 'Nº de Trabajadores en el Sitio',
        },
      },
      equipment_on_site: {
        label: {
          pt: 'Equipamentos no Local',
          en: 'Equipment on Site',
          es: 'Equipos en el Sitio',
        },
        options: {
          pt: ['Betoneira', 'Guindaste', 'Escavadeira', 'Compactador', 'Andaime', 'Outros'],
          en: ['Concrete Mixer', 'Crane', 'Excavator', 'Compactor', 'Scaffolding', 'Other'],
          es: ['Hormigonera', 'Grúa', 'Excavadora', 'Compactador', 'Andamio', 'Otros'],
        },
      },
      schedule_compliance: {
        label: {
          pt: 'Cumprimento do Cronograma',
          en: 'Schedule Compliance',
          es: 'Cumplimiento del Cronograma',
        },
        options: {
          pt: ['No Prazo', 'Atrasado', 'Adiantado'],
          en: ['On Schedule', 'Delayed', 'Ahead'],
          es: ['En Plazo', 'Atrasado', 'Adelantado'],
        },
      },
      delay_justification: {
        label: {
          pt: 'Justificativa de Atraso',
          en: 'Delay Justification',
          es: 'Justificación de Atraso',
        },
      },
      daily_work_log: {
        label: {
          pt: 'Registro de Atividades do Dia',
          en: 'Daily Work Log',
          es: 'Registro de Actividades del Día',
        },
      },
      infrastructure_conditions: {
        label: {
          pt: 'Condições de Infraestrutura Adequadas',
          en: 'Adequate Infrastructure Conditions',
          es: 'Condiciones de Infraestructura Adecuadas',
        },
      },
      photo_evidence: {
        label: {
          pt: 'Evidência Fotográfica',
          en: 'Photo Evidence',
          es: 'Evidencia Fotográfica',
        },
      },
    },
  },

  termo_recebimento: {
    title: {
      pt: 'Termo de Recebimento',
      en: 'Acceptance Certificate',
      es: 'Acta de Recepción',
    },
    description: {
      pt: 'Registro de recebimento provisório ou definitivo da obra.',
      en: 'Provisional or final acceptance record.',
      es: 'Registro de recepción provisional o definitiva de la obra.',
    },
    items: {
      reception_type: {
        label: {
          pt: 'Tipo de Recebimento',
          en: 'Reception Type',
          es: 'Tipo de Recepción',
        },
        options: {
          pt: ['Provisório', 'Definitivo'],
          en: ['Provisional', 'Final'],
          es: ['Provisional', 'Definitivo'],
        },
      },
      scope_compliance: {
        label: {
          pt: 'Escopo Atendido Integralmente',
          en: 'Scope Fully Met',
          es: 'Alcance Cumplido Integralmente',
        },
      },
      specification_compliance: {
        label: {
          pt: 'Especificações Técnicas Atendidas',
          en: 'Technical Specifications Met',
          es: 'Especificaciones Técnicas Cumplidas',
        },
      },
      pending_corrections: {
        label: {
          pt: 'Correções Pendentes',
          en: 'Pending Corrections',
          es: 'Correcciones Pendientes',
        },
      },
      final_assessment: {
        label: {
          pt: 'Avaliação Final',
          en: 'Final Assessment',
          es: 'Evaluación Final',
        },
        options: {
          pt: ['Aceito', 'Rejeitado', 'Condicional'],
          en: ['Accepted', 'Rejected', 'Conditional'],
          es: ['Aceptado', 'Rechazado', 'Condicional'],
        },
      },
      photo_evidence: {
        label: {
          pt: 'Evidência Fotográfica',
          en: 'Photo Evidence',
          es: 'Evidencia Fotográfica',
        },
      },
    },
  },

  checklist_conformidade_legal: {
    title: {
      pt: 'Checklist de Conformidade Legal',
      en: 'Legal Compliance Checklist',
      es: 'Checklist de Conformidad Legal',
    },
    description: {
      pt: 'Verificação de documentação e conformidade da empresa contratada.',
      en: 'Contractor documentation and compliance verification.',
      es: 'Verificación de documentación y conformidad de la empresa contratada.',
    },
    items: {
      documentation_complete: {
        label: {
          pt: 'Documentação Completa',
          en: 'Documentation Complete',
          es: 'Documentación Completa',
        },
      },
      insurance_valid: {
        label: {
          pt: 'Seguro em Dia',
          en: 'Insurance Valid',
          es: 'Seguro Vigente',
        },
      },
      safety_plan: {
        label: {
          pt: 'Plano de Segurança Apresentado',
          en: 'Safety Plan Submitted',
          es: 'Plan de Seguridad Presentado',
        },
      },
      environmental_license: {
        label: {
          pt: 'Licença Ambiental (se aplicável)',
          en: 'Environmental License (if applicable)',
          es: 'Licencia Ambiental (si aplica)',
        },
      },
      worker_registration: {
        label: {
          pt: 'Registro de Funcionários em Dia',
          en: 'Worker Registration Up to Date',
          es: 'Registro de Empleados al Día',
        },
      },
      tax_compliance: {
        label: {
          pt: 'Certidões Negativas de Débito',
          en: 'Tax Clearance Certificates',
          es: 'Certificados Negativos de Deuda',
        },
      },
      cnpj_regular: {
        label: {
          pt: 'CNPJ Regular',
          en: 'Business Registration Active',
          es: 'Registro Empresarial Activo',
        },
      },
    },
  },
};

module.exports = { PUBLIC_WORKS_TRANSLATIONS };
