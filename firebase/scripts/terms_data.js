// Default Terms of Service per segment (i18n)
// Used by seed_segments.js to populate defaultTermsOfService in each segment document.
// Each segment has 7 clauses tailored to its industry, in 3 languages.

const DEFAULT_TERMS = {
  // ═══════════════════════════════════════════════════════════
  // AUTOMOTIVO
  // ═══════════════════════════════════════════════════════════
  automotive: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: O veículo deve ser retirado em até 5 dias úteis após a comunicação de conclusão do serviço. Após esse prazo, poderá ser cobrada taxa de permanência diária.

2. ABANDONO DE VEÍCULO: Veículos não retirados em até 90 dias após a conclusão do serviço serão considerados abandonados, podendo a oficina adotar as medidas legais cabíveis, incluindo leilão ou alienação para cobrir os custos do serviço.

3. GARANTIA: Serviços mecânicos têm garantia de 90 dias ou 3.000 km (o que ocorrer primeiro). Serviços de lataria e pintura têm garantia de 180 dias. A garantia não cobre desgaste natural, mau uso ou danos causados por terceiros.

4. SERVIÇOS ADICIONAIS: Problemas identificados durante o serviço serão comunicados ao cliente para aprovação prévia. Nenhum serviço adicional será realizado sem autorização expressa.

5. PAGAMENTO: O pagamento é devido na retirada do veículo. O veículo poderá ser retido como garantia de pagamento conforme previsto em lei.

6. OBJETOS PESSOAIS: A oficina não se responsabiliza por objetos pessoais deixados no interior do veículo. Recomendamos a remoção de todos os pertences antes da entrega.

7. PEÇAS SUBSTITUÍDAS: As peças substituídas ficam à disposição do cliente para retirada no ato da entrega. Não retiradas, serão descartadas em até 5 dias.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The vehicle must be picked up within 5 business days after notification of service completion. A daily storage fee may apply after this period.

2. ABANDONMENT POLICY: Vehicles not picked up within 90 days of service completion will be considered abandoned. The shop may take legal action, including auction or disposal, to recover service costs.

3. WARRANTY: Mechanical services carry a 90-day or 3,000 km warranty (whichever comes first). Body and paint work carries a 180-day warranty. Warranty does not cover normal wear, misuse, or damage caused by third parties.

4. ADDITIONAL SERVICES: Any issues found during service will be communicated to the customer for prior approval. No additional work will be performed without express authorization.

5. PAYMENT: Payment is due upon vehicle pickup. The vehicle may be held as payment guarantee as permitted by law.

6. PERSONAL BELONGINGS: The shop is not responsible for personal items left inside the vehicle. We recommend removing all belongings before drop-off.

7. REPLACED PARTS: Replaced parts are available for customer retrieval at pickup. Parts not claimed will be discarded within 5 days.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: El vehículo debe ser retirado dentro de los 5 días hábiles posteriores a la notificación de finalización del servicio. Pasado ese plazo, se podrá cobrar una tarifa diaria de estadía.

2. ABANDONO DE VEHÍCULO: Los vehículos no retirados en 90 días tras la finalización del servicio serán considerados abandonados. El taller podrá tomar las medidas legales correspondientes, incluyendo subasta o enajenación para cubrir los costos del servicio.

3. GARANTÍA: Los servicios mecánicos tienen garantía de 90 días o 3.000 km (lo que ocurra primero). Los trabajos de carrocería y pintura tienen garantía de 180 días. La garantía no cubre desgaste natural, mal uso o daños causados por terceros.

4. SERVICIOS ADICIONALES: Los problemas identificados durante el servicio serán comunicados al cliente para su aprobación previa. No se realizará ningún trabajo adicional sin autorización expresa.

5. PAGO: El pago se realiza al momento del retiro del vehículo. El vehículo podrá ser retenido como garantía de pago conforme a la ley.

6. OBJETOS PERSONALES: El taller no se responsabiliza por objetos personales dejados en el interior del vehículo. Recomendamos retirar todos los pertenencias antes de la entrega.

7. PIEZAS REEMPLAZADAS: Las piezas sustituidas quedan a disposición del cliente para su retiro al momento de la entrega. Las no retiradas serán descartadas en un plazo de 5 días.`,
  },

  // ═══════════════════════════════════════════════════════════
  // HVAC (Ar Condicionado / Refrigeração)
  // ═══════════════════════════════════════════════════════════
  hvac: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: Equipamentos levados para conserto devem ser retirados em até 5 dias úteis após a conclusão. Para serviços in loco, o cliente deve garantir acesso ao local na data agendada.

2. ABANDONO: Equipamentos não retirados em 90 dias serão considerados abandonados e poderão ser descartados ou alienados para cobrir os custos do serviço.

3. GARANTIA: Peças substituídas têm garantia conforme o fabricante. A mão de obra tem garantia de 90 dias. A garantia não cobre danos por falta de manutenção preventiva, instalação elétrica inadequada ou condições ambientais adversas.

4. SERVIÇOS ADICIONAIS: Qualquer necessidade de troca de gás refrigerante, peças adicionais ou adaptações na instalação será previamente comunicada e orçada.

5. PAGAMENTO: O pagamento é devido na conclusão do serviço ou na retirada do equipamento. Serviços parcelados seguem condições acordadas no orçamento.

6. ACESSO AO LOCAL: Para serviços in loco, o cliente é responsável por garantir acesso seguro ao equipamento. Deslocamentos extras por acesso não disponível podem gerar cobranças adicionais.

7. GÁS REFRIGERANTE: O gás removido durante o serviço é descartado conforme normas ambientais vigentes. A recarga de gás está sujeita à regulamentação específica.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: Equipment brought in for repair must be picked up within 5 business days of completion. For on-site services, the customer must ensure site access on the scheduled date.

2. ABANDONMENT POLICY: Equipment not picked up within 90 days will be considered abandoned and may be discarded or sold to cover service costs.

3. WARRANTY: Replacement parts carry the manufacturer's warranty. Labor carries a 90-day warranty. Warranty does not cover damage from lack of preventive maintenance, inadequate electrical installation, or adverse environmental conditions.

4. ADDITIONAL SERVICES: Any need for refrigerant recharge, additional parts, or installation modifications will be communicated and quoted in advance.

5. PAYMENT: Payment is due upon service completion or equipment pickup. Installment terms follow conditions agreed in the quote.

6. SITE ACCESS: For on-site services, the customer is responsible for ensuring safe access to the equipment. Additional travel charges may apply if access is unavailable.

7. REFRIGERANT GAS: Refrigerant removed during service is disposed of in accordance with applicable environmental regulations. Recharging is subject to specific regulatory requirements.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: Los equipos llevados a reparación deben retirarse dentro de los 5 días hábiles posteriores a la finalización. Para servicios in situ, el cliente debe garantizar el acceso al lugar en la fecha programada.

2. ABANDONO: Los equipos no retirados en 90 días serán considerados abandonados y podrán ser descartados o enajenados para cubrir los costos del servicio.

3. GARANTÍA: Las piezas sustituidas tienen garantía según el fabricante. La mano de obra tiene garantía de 90 días. La garantía no cubre daños por falta de mantenimiento preventivo, instalación eléctrica inadecuada o condiciones ambientales adversas.

4. SERVICIOS ADICIONALES: Cualquier necesidad de recarga de gas refrigerante, piezas adicionales o adaptaciones en la instalación será comunicada y presupuestada previamente.

5. PAGO: El pago se realiza al finalizar el servicio o al retirar el equipo. Los servicios en cuotas siguen las condiciones acordadas en el presupuesto.

6. ACCESO AL LUGAR: Para servicios in situ, el cliente es responsable de garantizar el acceso seguro al equipo. Los desplazamientos adicionales por acceso no disponible pueden generar cargos extra.

7. GAS REFRIGERANTE: El gas removido durante el servicio se descarta conforme a las normas ambientales vigentes. La recarga de gas está sujeta a la reglamentación específica.`,
  },

  // ═══════════════════════════════════════════════════════════
  // SMARTPHONES / CELULARES
  // ═══════════════════════════════════════════════════════════
  smartphones: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: O aparelho deve ser retirado em até 5 dias úteis após a conclusão do serviço. Após 90 dias sem retirada, o equipamento poderá ser considerado abandonado.

2. DADOS E PRIVACIDADE: A assistência não se responsabiliza por perda de dados, fotos, contatos ou aplicativos durante o reparo. Recomendamos fortemente realizar backup completo antes da entrega.

3. SENHAS E CONTAS: O cliente é responsável por desativar o bloqueio de ativação (iCloud/Google) quando solicitado. Aparelhos com bloqueio ativo podem ter o serviço impossibilitado, sem direito a reembolso da taxa de diagnóstico.

4. GARANTIA: Peças substituídas têm garantia de 90 dias. A garantia não cobre danos por queda, líquidos, mau uso ou oxidação pré-existente.

5. DANOS POR LÍQUIDO: Aparelhos com dano por líquido podem apresentar falhas secundárias após o reparo. A assistência não se responsabiliza por componentes adicionais afetados pela oxidação.

6. SERVIÇOS ADICIONAIS: Qualquer problema adicional encontrado será comunicado antes de qualquer intervenção. Nenhum serviço extra será realizado sem aprovação.

7. ACESSÓRIOS: Películas, capas e acessórios não são de responsabilidade da assistência. Recomendamos não entregar o aparelho com acessórios.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The device must be picked up within 5 business days of service completion. After 90 days without pickup, the device may be considered abandoned.

2. DATA AND PRIVACY: The repair shop is not responsible for loss of data, photos, contacts, or apps during repair. We strongly recommend performing a full backup before drop-off.

3. PASSWORDS AND ACCOUNTS: The customer is responsible for disabling activation lock (iCloud/Google) when requested. Devices with active locks may be unserviceable, with no refund of the diagnostic fee.

4. WARRANTY: Replacement parts carry a 90-day warranty. Warranty does not cover damage from drops, liquids, misuse, or pre-existing oxidation.

5. LIQUID DAMAGE: Devices with liquid damage may develop secondary failures after repair. The shop is not responsible for additional components affected by corrosion.

6. ADDITIONAL SERVICES: Any additional issues found will be communicated before any intervention. No extra work will be performed without customer approval.

7. ACCESSORIES: Screen protectors, cases, and accessories are not the shop's responsibility. We recommend not leaving accessories with the device.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: El dispositivo debe retirarse dentro de los 5 días hábiles posteriores a la finalización del servicio. Tras 90 días sin retiro, el equipo podrá considerarse abandonado.

2. DATOS Y PRIVACIDAD: El servicio técnico no se responsabiliza por la pérdida de datos, fotos, contactos o aplicaciones durante la reparación. Recomendamos realizar una copia de seguridad completa antes de la entrega.

3. CONTRASEÑAS Y CUENTAS: El cliente es responsable de desactivar el bloqueo de activación (iCloud/Google) cuando se solicite. Los dispositivos con bloqueo activo pueden impedir el servicio, sin derecho a reembolso de la tarifa de diagnóstico.

4. GARANTÍA: Las piezas sustituidas tienen garantía de 90 días. La garantía no cubre daños por caídas, líquidos, mal uso u oxidación preexistente.

5. DAÑOS POR LÍQUIDO: Los dispositivos con daño por líquido pueden presentar fallas secundarias tras la reparación. El servicio no se responsabiliza por componentes adicionales afectados por la oxidación.

6. SERVICIOS ADICIONALES: Cualquier problema adicional encontrado será comunicado antes de cualquier intervención. No se realizará ningún servicio extra sin aprobación.

7. ACCESORIOS: Los protectores de pantalla, fundas y accesorios no son responsabilidad del servicio técnico. Recomendamos no entregar el dispositivo con accesorios.`,
  },

  // ═══════════════════════════════════════════════════════════
  // COMPUTADORES / INFORMÁTICA
  // ═══════════════════════════════════════════════════════════
  computers: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: O equipamento deve ser retirado em até 5 dias úteis após a conclusão. Equipamentos não retirados em 90 dias poderão ser considerados abandonados.

2. BACKUP DE DADOS: A assistência não se responsabiliza por perda de dados durante o reparo. É obrigação do cliente realizar backup antes da entrega. Serviços de recuperação de dados são separados e orçados à parte.

3. SENHAS E ACESSO: O cliente deve fornecer senhas necessárias para execução do serviço. Dados acessados são tratados com confidencialidade e utilizados exclusivamente para fins técnicos.

4. SOFTWARES: A assistência não instala softwares sem licença. O cliente é responsável por fornecer licenças originais dos programas que necessitar reinstalar.

5. GARANTIA: Hardware substituído tem garantia de 90 dias. Serviços de formatação e instalação de sistema têm garantia de 30 dias. A garantia não cobre danos por vírus, mau uso ou alterações realizadas pelo cliente.

6. SERVIÇOS ADICIONAIS: Problemas identificados durante o diagnóstico serão comunicados ao cliente para aprovação antes de qualquer intervenção adicional.

7. PEÇAS SUBSTITUÍDAS: Peças trocadas ficam à disposição do cliente na retirada. Não solicitadas, serão descartadas em 5 dias.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: Equipment must be picked up within 5 business days of service completion. Equipment not retrieved within 90 days may be considered abandoned.

2. DATA BACKUP: The repair shop is not responsible for data loss during repair. It is the customer's responsibility to back up data before drop-off. Data recovery services are separate and quoted independently.

3. PASSWORDS AND ACCESS: The customer must provide necessary passwords for service execution. Any accessed data is treated confidentially and used solely for technical purposes.

4. SOFTWARE: The shop does not install unlicensed software. The customer is responsible for providing original licenses for any software that needs to be reinstalled.

5. WARRANTY: Replacement hardware carries a 90-day warranty. Formatting and OS installation services carry a 30-day warranty. Warranty does not cover damage from viruses, misuse, or changes made by the customer.

6. ADDITIONAL SERVICES: Issues identified during diagnosis will be communicated to the customer for approval before any additional intervention.

7. REPLACED PARTS: Replaced parts are available for retrieval at pickup. Unclaimed parts will be discarded within 5 days.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: El equipo debe retirarse dentro de los 5 días hábiles posteriores a la finalización. Los equipos no retirados en 90 días podrán considerarse abandonados.

2. COPIA DE SEGURIDAD: El servicio técnico no se responsabiliza por pérdida de datos durante la reparación. Es obligación del cliente realizar una copia de seguridad antes de la entrega. Los servicios de recuperación de datos son independientes y se presupuestan por separado.

3. CONTRASEÑAS Y ACCESO: El cliente debe proporcionar las contraseñas necesarias para la ejecución del servicio. Los datos accedidos se tratan con confidencialidad y se utilizan exclusivamente para fines técnicos.

4. SOFTWARE: El servicio técnico no instala software sin licencia. El cliente es responsable de proporcionar las licencias originales de los programas que necesite reinstalar.

5. GARANTÍA: El hardware sustituido tiene garantía de 90 días. Los servicios de formateo e instalación del sistema tienen garantía de 30 días. La garantía no cubre daños por virus, mal uso o modificaciones realizadas por el cliente.

6. SERVICIOS ADICIONALES: Los problemas identificados durante el diagnóstico serán comunicados al cliente para su aprobación antes de cualquier intervención adicional.

7. PIEZAS REEMPLAZADAS: Las piezas sustituidas quedan a disposición del cliente al momento del retiro. Las no reclamadas serán descartadas en 5 días.`,
  },

  // ═══════════════════════════════════════════════════════════
  // ELETRODOMÉSTICOS
  // ═══════════════════════════════════════════════════════════
  appliances: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: O eletrodoméstico deve ser retirado em até 5 dias úteis após a conclusão do serviço. Equipamentos não retirados em 90 dias serão considerados abandonados.

2. TRANSPORTE: O transporte do equipamento até a assistência e o retorno são de responsabilidade do cliente, salvo quando incluso no orçamento. Danos ocorridos durante transporte não são de responsabilidade da assistência.

3. GARANTIA: Peças substituídas têm garantia conforme fabricante, mínimo de 90 dias. A mão de obra tem garantia de 90 dias. A garantia não cobre danos causados por variação de tensão elétrica, mau uso, sobrecarga ou instalação inadequada.

4. CONDIÇÕES ELÉTRICAS: A assistência não se responsabiliza por danos causados por instabilidade na rede elétrica do cliente. Recomendamos o uso de estabilizadores e aterramento adequado.

5. SERVIÇOS ADICIONAIS: Qualquer necessidade de troca de peças adicionais encontrada durante o reparo será comunicada e orçada previamente.

6. PAGAMENTO: O pagamento é devido na conclusão do serviço ou na retirada do equipamento.

7. PEÇAS SUBSTITUÍDAS: As peças trocadas ficam disponíveis para retirada pelo cliente. Não retiradas em 5 dias, serão descartadas.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The appliance must be picked up within 5 business days of service completion. Equipment not retrieved within 90 days will be considered abandoned.

2. TRANSPORT: Transportation of the appliance to and from the shop is the customer's responsibility unless included in the quote. Damage occurring during transport is not the shop's responsibility.

3. WARRANTY: Replacement parts carry the manufacturer's warranty, with a minimum of 90 days. Labor carries a 90-day warranty. Warranty does not cover damage from electrical surges, misuse, overload, or improper installation.

4. ELECTRICAL CONDITIONS: The shop is not responsible for damage caused by electrical instability at the customer's location. We recommend the use of surge protectors and proper grounding.

5. ADDITIONAL SERVICES: Any additional parts found necessary during repair will be communicated and quoted in advance.

6. PAYMENT: Payment is due upon service completion or appliance pickup.

7. REPLACED PARTS: Replaced parts are available for customer retrieval. Parts not claimed within 5 days will be discarded.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: El electrodoméstico debe retirarse dentro de los 5 días hábiles posteriores a la finalización del servicio. Los equipos no retirados en 90 días serán considerados abandonados.

2. TRANSPORTE: El transporte del equipo hacia y desde el servicio técnico es responsabilidad del cliente, salvo cuando esté incluido en el presupuesto. Los daños ocurridos durante el transporte no son responsabilidad del servicio.

3. GARANTÍA: Las piezas sustituidas tienen garantía según el fabricante, con un mínimo de 90 días. La mano de obra tiene garantía de 90 días. La garantía no cubre daños causados por variaciones de tensión eléctrica, mal uso, sobrecarga o instalación inadecuada.

4. CONDICIONES ELÉCTRICAS: El servicio no se responsabiliza por daños causados por inestabilidad en la red eléctrica del cliente. Recomendamos el uso de estabilizadores y una puesta a tierra adecuada.

5. SERVICIOS ADICIONALES: Cualquier necesidad de piezas adicionales encontrada durante la reparación será comunicada y presupuestada previamente.

6. PAGO: El pago se realiza al finalizar el servicio o al retirar el equipo.

7. PIEZAS REEMPLAZADAS: Las piezas sustituidas quedan disponibles para su retiro por el cliente. Las no retiradas en 5 días serán descartadas.`,
  },

  // ═══════════════════════════════════════════════════════════
  // ELÉTRICA
  // ═══════════════════════════════════════════════════════════
  electrical: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. ACESSO AO LOCAL: O cliente deve garantir acesso livre e seguro ao local de trabalho na data agendada. O adiamento por falta de acesso poderá gerar cobrança de taxa de deslocamento.

2. CONDIÇÕES PRÉ-EXISTENTES: A empresa não se responsabiliza por danos em equipamentos ou instalações decorrentes de condições elétricas pré-existentes inadequadas (fiação antiga, ausência de aterramento, etc.) não informadas previamente.

3. GARANTIA: Os serviços elétricos têm garantia de 90 dias sobre a mão de obra. Materiais e equipamentos fornecidos têm garantia conforme fabricante. A garantia não cobre danos causados por terceiros ou alterações na instalação.

4. MATERIAIS: Os materiais utilizados seguem as normas técnicas vigentes. Substituições por materiais de especificação inferior, quando solicitadas pelo cliente, isentam a empresa de responsabilidade sobre o resultado.

5. SERVIÇOS ADICIONAIS: Irregularidades encontradas durante a execução serão comunicadas imediatamente. Nenhum serviço adicional será realizado sem autorização do cliente.

6. PAGAMENTO: O pagamento é devido na conclusão do serviço. Serviços de maior porte podem exigir sinal antecipado conforme acordado no orçamento.

7. SEGURANÇA: O cliente deve manter crianças e animais afastados da área de trabalho durante a execução dos serviços.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. SITE ACCESS: The customer must ensure free and safe access to the work area on the scheduled date. Rescheduling due to lack of access may result in a travel fee.

2. PRE-EXISTING CONDITIONS: The company is not responsible for damage to equipment or installations resulting from pre-existing inadequate electrical conditions (old wiring, lack of grounding, etc.) not disclosed in advance.

3. WARRANTY: Electrical services carry a 90-day labor warranty. Supplied materials and equipment carry the manufacturer's warranty. Warranty does not cover damage caused by third parties or alterations to the installation.

4. MATERIALS: All materials used comply with applicable technical standards. Substitution with lower-specification materials at the customer's request releases the company from liability for the outcome.

5. ADDITIONAL SERVICES: Any irregularities found during execution will be communicated immediately. No additional work will be performed without customer authorization.

6. PAYMENT: Payment is due upon service completion. Larger projects may require an advance deposit as agreed in the quote.

7. SAFETY: The customer must keep children and animals away from the work area during service execution.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. ACCESO AL LUGAR: El cliente debe garantizar el acceso libre y seguro al lugar de trabajo en la fecha programada. La reprogramación por falta de acceso podrá generar cobro de tarifa de desplazamiento.

2. CONDICIONES PREEXISTENTES: La empresa no se responsabiliza por daños en equipos o instalaciones derivados de condiciones eléctricas preexistentes inadecuadas (cableado antiguo, ausencia de puesta a tierra, etc.) no informadas previamente.

3. GARANTÍA: Los servicios eléctricos tienen garantía de 90 días sobre la mano de obra. Los materiales y equipos suministrados tienen garantía según el fabricante. La garantía no cubre daños causados por terceros o modificaciones en la instalación.

4. MATERIALES: Los materiales utilizados cumplen con las normas técnicas vigentes. La sustitución por materiales de especificación inferior, cuando sea solicitada por el cliente, exime a la empresa de responsabilidad sobre el resultado.

5. SERVICIOS ADICIONALES: Las irregularidades encontradas durante la ejecución serán comunicadas de inmediato. No se realizará ningún servicio adicional sin autorización del cliente.

6. PAGO: El pago se realiza al finalizar el servicio. Los proyectos de mayor envergadura pueden requerir un anticipo según lo acordado en el presupuesto.

7. SEGURIDAD: El cliente debe mantener a niños y animales alejados del área de trabajo durante la ejecución de los servicios.`,
  },

  // ═══════════════════════════════════════════════════════════
  // HIDRÁULICA
  // ═══════════════════════════════════════════════════════════
  plumbing: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. ACESSO AO LOCAL: O cliente deve garantir acesso ao local de trabalho e ao registro geral de água. O adiamento por falta de acesso poderá gerar cobrança de deslocamento.

2. CONDIÇÕES PRÉ-EXISTENTES: A empresa não se responsabiliza por danos decorrentes de tubulações, conexões ou instalações hidráulicas pré-existentes em mau estado não identificadas antes do serviço.

3. GARANTIA: A mão de obra tem garantia de 90 dias. Materiais fornecidos têm garantia conforme fabricante. A garantia não cobre danos causados por pressão de água irregular, entupimentos por mau uso ou alterações realizadas por terceiros.

4. DANOS POR ÁGUA: A empresa tomará todas as precauções para evitar danos. No entanto, não se responsabiliza por danos causados por condições hidráulicas ocultas ou pré-existentes reveladas durante a execução.

5. SERVIÇOS ADICIONAIS: Qualquer problema adicional identificado durante a execução será comunicado imediatamente ao cliente. Nenhuma intervenção extra será feita sem aprovação.

6. PAGAMENTO: O pagamento é devido na conclusão do serviço. Projetos maiores podem exigir pagamento parcial antecipado.

7. MATERIAIS: Os materiais utilizados atendem às normas técnicas vigentes. A empresa não se responsabiliza por resultados de materiais de qualidade inferior solicitados pelo cliente.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. SITE ACCESS: The customer must ensure access to the work area and the main water shutoff valve. Rescheduling due to lack of access may result in a travel fee.

2. PRE-EXISTING CONDITIONS: The company is not responsible for damage resulting from pre-existing pipes, fittings, or plumbing installations in poor condition that were not identified before the service.

3. WARRANTY: Labor carries a 90-day warranty. Supplied materials carry the manufacturer's warranty. Warranty does not cover damage from irregular water pressure, blockages caused by misuse, or modifications made by third parties.

4. WATER DAMAGE: The company will take all precautions to avoid damage. However, it is not responsible for damage caused by hidden or pre-existing hydraulic conditions revealed during execution.

5. ADDITIONAL SERVICES: Any additional issues identified during execution will be immediately communicated to the customer. No extra intervention will be made without approval.

6. PAYMENT: Payment is due upon service completion. Larger projects may require partial advance payment.

7. MATERIALS: All materials used comply with applicable technical standards. The company is not responsible for outcomes resulting from lower-quality materials requested by the customer.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. ACCESO AL LUGAR: El cliente debe garantizar el acceso al lugar de trabajo y a la llave de paso general del agua. La reprogramación por falta de acceso podrá generar cobro de desplazamiento.

2. CONDICIONES PREEXISTENTES: La empresa no se responsabiliza por daños derivados de tuberías, conexiones o instalaciones hidráulicas preexistentes en mal estado no identificadas antes del servicio.

3. GARANTÍA: La mano de obra tiene garantía de 90 días. Los materiales suministrados tienen garantía según el fabricante. La garantía no cubre daños por presión de agua irregular, obstrucciones por mal uso o modificaciones realizadas por terceros.

4. DAÑOS POR AGUA: La empresa tomará todas las precauciones para evitar daños. Sin embargo, no se responsabiliza por daños causados por condiciones hidráulicas ocultas o preexistentes reveladas durante la ejecución.

5. SERVICIOS ADICIONALES: Cualquier problema adicional identificado durante la ejecución será comunicado de inmediato al cliente. No se realizará ninguna intervención extra sin aprobación.

6. PAGO: El pago se realiza al finalizar el servicio. Los proyectos de mayor envergadura pueden requerir un pago parcial anticipado.

7. MATERIALES: Los materiales utilizados cumplen con las normas técnicas vigentes. La empresa no se responsabiliza por los resultados de materiales de calidad inferior solicitados por el cliente.`,
  },

  // ═══════════════════════════════════════════════════════════
  // SEGURANÇA ELETRÔNICA
  // ═══════════════════════════════════════════════════════════
  security: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. ACESSO AO LOCAL: O cliente deve garantir acesso ao local de instalação/manutenção na data agendada. O adiamento por falta de acesso poderá gerar cobrança de deslocamento.

2. PRAZO DE RETIRADA: Equipamentos levados para reparo devem ser retirados em até 5 dias úteis após a conclusão. Equipamentos não retirados em 90 dias serão considerados abandonados.

3. GARANTIA: Equipamentos têm garantia conforme fabricante. A mão de obra tem garantia de 90 dias. A garantia não cobre danos por vandalismo, raios, surtos de tensão ou mau uso.

4. DADOS E PRIVACIDADE: Gravações e dados armazenados nos equipamentos são de exclusiva responsabilidade do cliente. A empresa não acessa, armazena ou compartilha gravações sem autorização expressa.

5. MONITORAMENTO: Serviços de monitoramento, quando contratados, são regidos por contrato específico. A empresa não se responsabiliza por danos decorrentes de falhas de conectividade fora de seu controle.

6. SERVIÇOS ADICIONAIS: Qualquer necessidade de pontos adicionais, cabeamento extra ou ajustes de configuração será comunicada e orçada previamente.

7. PAGAMENTO: O pagamento é devido na conclusão da instalação ou do serviço. Equipamentos e materiais fornecidos são cobrados separadamente da mão de obra.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. SITE ACCESS: The customer must ensure access to the installation/maintenance site on the scheduled date. Rescheduling due to lack of access may result in a travel fee.

2. PICKUP DEADLINE: Equipment brought in for repair must be picked up within 5 business days of completion. Equipment not retrieved within 90 days will be considered abandoned.

3. WARRANTY: Equipment carries the manufacturer's warranty. Labor carries a 90-day warranty. Warranty does not cover damage from vandalism, lightning, power surges, or misuse.

4. DATA AND PRIVACY: Recordings and data stored on the equipment are the customer's sole responsibility. The company does not access, store, or share recordings without express authorization.

5. MONITORING: Monitoring services, when contracted, are governed by a specific agreement. The company is not responsible for damages resulting from connectivity failures outside its control.

6. ADDITIONAL SERVICES: Any need for additional points, extra cabling, or configuration adjustments will be communicated and quoted in advance.

7. PAYMENT: Payment is due upon completion of installation or service. Equipment and materials are billed separately from labor.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. ACCESO AL LUGAR: El cliente debe garantizar el acceso al lugar de instalación/mantenimiento en la fecha programada. La reprogramación por falta de acceso podrá generar cobro de desplazamiento.

2. PLAZO DE RETIRO: Los equipos llevados a reparación deben retirarse dentro de los 5 días hábiles posteriores a la finalización. Los equipos no retirados en 90 días serán considerados abandonados.

3. GARANTÍA: Los equipos tienen garantía según el fabricante. La mano de obra tiene garantía de 90 días. La garantía no cubre daños por vandalismo, rayos, sobretensiones o mal uso.

4. DATOS Y PRIVACIDAD: Las grabaciones y los datos almacenados en los equipos son responsabilidad exclusiva del cliente. La empresa no accede, almacena ni comparte grabaciones sin autorización expresa.

5. MONITOREO: Los servicios de monitoreo, cuando se contraten, se rigen por un contrato específico. La empresa no se responsabiliza por daños derivados de fallas de conectividad fuera de su control.

6. SERVICIOS ADICIONALES: Cualquier necesidad de puntos adicionales, cableado extra o ajustes de configuración será comunicada y presupuestada previamente.

7. PAGO: El pago se realiza al finalizar la instalación o el servicio. Los equipos y materiales suministrados se cobran por separado de la mano de obra.`,
  },

  // ═══════════════════════════════════════════════════════════
  // ENERGIA SOLAR
  // ═══════════════════════════════════════════════════════════
  solar: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. CONDIÇÕES DO LOCAL: O cliente declara que o telhado/estrutura está em boas condições para suportar a instalação. A empresa não se responsabiliza por danos decorrentes de estruturas pré-existentes inadequadas não informadas.

2. GARANTIA DE EQUIPAMENTOS: Painéis solares têm garantia conforme fabricante (tipicamente 10-25 anos de performance e 10 anos de produto). Inversores têm garantia conforme fabricante. A mão de obra tem garantia de 1 ano.

3. DESEMPENHO: A geração estimada é baseada em dados de irradiação solar históricos. Variações climáticas, sombreamento e degradação natural dos painéis podem afetar a produção real, sem constituir defeito.

4. CONEXÃO À REDE: A homologação junto à concessionária de energia é de responsabilidade da empresa, salvo quando explicitamente excluída do escopo. Taxas da concessionária são de responsabilidade do cliente.

5. SERVIÇOS ADICIONAIS: Qualquer necessidade de adequação da instalação elétrica, reforço estrutural ou equipamentos adicionais será comunicada e orçada previamente.

6. MANUTENÇÃO: Recomenda-se limpeza periódica dos painéis para manter a eficiência. Danos causados por falta de manutenção não são cobertos pela garantia.

7. PAGAMENTO: Projetos de energia solar tipicamente exigem pagamento parcelado conforme etapas de execução definidas no contrato.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. SITE CONDITIONS: The customer declares that the roof/structure is in good condition to support the installation. The company is not responsible for damage resulting from pre-existing inadequate structures not disclosed in advance.

2. EQUIPMENT WARRANTY: Solar panels carry the manufacturer's warranty (typically 10-25 years performance and 10 years product warranty). Inverters carry the manufacturer's warranty. Labor carries a 1-year warranty.

3. PERFORMANCE: Estimated generation is based on historical solar irradiation data. Climate variations, shading, and natural panel degradation may affect actual production without constituting a defect.

4. GRID CONNECTION: Grid interconnection approval with the utility company is the company's responsibility unless explicitly excluded from scope. Utility fees are the customer's responsibility.

5. ADDITIONAL SERVICES: Any need for electrical installation upgrades, structural reinforcement, or additional equipment will be communicated and quoted in advance.

6. MAINTENANCE: Periodic panel cleaning is recommended to maintain efficiency. Damage caused by lack of maintenance is not covered by warranty.

7. PAYMENT: Solar energy projects typically require installment payments according to execution milestones defined in the contract.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. CONDICIONES DEL LUGAR: El cliente declara que el techo/estructura está en buenas condiciones para soportar la instalación. La empresa no se responsabiliza por daños derivados de estructuras preexistentes inadecuadas no informadas.

2. GARANTÍA DE EQUIPOS: Los paneles solares tienen garantía según el fabricante (típicamente 10-25 años de rendimiento y 10 años de producto). Los inversores tienen garantía según el fabricante. La mano de obra tiene garantía de 1 año.

3. RENDIMIENTO: La generación estimada se basa en datos históricos de irradiación solar. Las variaciones climáticas, el sombreado y la degradación natural de los paneles pueden afectar la producción real sin que esto constituya un defecto.

4. CONEXIÓN A LA RED: La homologación ante la distribuidora de energía es responsabilidad de la empresa, salvo cuando esté explícitamente excluida del alcance. Las tarifas de la distribuidora son responsabilidad del cliente.

5. SERVICIOS ADICIONALES: Cualquier necesidad de adecuación de la instalación eléctrica, refuerzo estructural o equipos adicionales será comunicada y presupuestada previamente.

6. MANTENIMIENTO: Se recomienda la limpieza periódica de los paneles para mantener la eficiencia. Los daños causados por falta de mantenimiento no están cubiertos por la garantía.

7. PAGO: Los proyectos de energía solar típicamente requieren pagos en cuotas según las etapas de ejecución definidas en el contrato.`,
  },

  // ═══════════════════════════════════════════════════════════
  // IMPRESSORAS
  // ═══════════════════════════════════════════════════════════
  printers: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: A impressora deve ser retirada em até 5 dias úteis após a conclusão do serviço. Equipamentos não retirados em 90 dias serão considerados abandonados e poderão ser descartados.

2. CONSUMÍVEIS: Cartuchos, toners e suprimentos não são reaproveitados após a abertura do equipamento. A assistência não se responsabiliza pelo nível de toner/tinta consumido durante testes de funcionamento.

3. DADOS NA MEMÓRIA: Impressoras com disco rígido ou memória interna podem conter dados do cliente. A assistência pode realizar formatação da memória quando necessário para o reparo, sem responsabilidade por dados armazenados.

4. GARANTIA: Peças substituídas têm garantia de 90 dias. A garantia não cobre danos causados por uso de suprimentos não originais ou de qualidade inferior, obstruções por corpo estranho ou mau uso.

5. SUPRIMENTOS NÃO ORIGINAIS: O uso de cartuchos ou toners não originais pode causar danos ao equipamento. A assistência não garante reparos decorrentes de danos causados por suprimentos inadequados.

6. SERVIÇOS ADICIONAIS: Quaisquer problemas adicionais encontrados serão comunicados antes de qualquer intervenção adicional.

7. PEÇAS SUBSTITUÍDAS: Peças e suprimentos trocados ficam à disposição na retirada. Não solicitados, serão descartados em 5 dias.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The printer must be picked up within 5 business days of service completion. Equipment not retrieved within 90 days will be considered abandoned and may be discarded.

2. CONSUMABLES: Cartridges, toners, and supplies are not reused after the device is opened. The shop is not responsible for toner/ink levels consumed during functionality tests.

3. DATA IN MEMORY: Printers with hard drives or internal memory may contain customer data. The shop may format the memory when necessary for repair, with no liability for stored data.

4. WARRANTY: Replacement parts carry a 90-day warranty. Warranty does not cover damage caused by non-original or low-quality supplies, foreign object obstructions, or misuse.

5. NON-ORIGINAL SUPPLIES: Use of non-original cartridges or toners may damage the device. The shop does not warranty repairs resulting from damage caused by inadequate supplies.

6. ADDITIONAL SERVICES: Any additional issues found will be communicated before any further intervention.

7. REPLACED PARTS: Replaced parts and supplies are available for retrieval at pickup. Unclaimed items will be discarded within 5 days.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: La impresora debe retirarse dentro de los 5 días hábiles posteriores a la finalización del servicio. Los equipos no retirados en 90 días serán considerados abandonados y podrán ser descartados.

2. CONSUMIBLES: Los cartuchos, tóneres y suministros no se reutilizan tras la apertura del equipo. El servicio no se responsabiliza por el nivel de tóner/tinta consumido durante las pruebas de funcionamiento.

3. DATOS EN MEMORIA: Las impresoras con disco duro o memoria interna pueden contener datos del cliente. El servicio puede formatear la memoria cuando sea necesario para la reparación, sin responsabilidad por los datos almacenados.

4. GARANTÍA: Las piezas sustituidas tienen garantía de 90 días. La garantía no cubre daños causados por el uso de suministros no originales o de calidad inferior, obstrucciones por cuerpos extraños o mal uso.

5. SUMINISTROS NO ORIGINALES: El uso de cartuchos o tóneres no originales puede dañar el equipo. El servicio no garantiza las reparaciones derivadas de daños causados por suministros inadecuados.

6. SERVICIOS ADICIONALES: Cualquier problema adicional encontrado será comunicado antes de cualquier intervención adicional.

7. PIEZAS REEMPLAZADAS: Las piezas y suministros sustituidos quedan a disposición al momento del retiro. Los no reclamados serán descartados en 5 días.`,
  },

  // ═══════════════════════════════════════════════════════════
  // MANUTENÇÃO PREDIAL
  // ═══════════════════════════════════════════════════════════
  building_maintenance: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. ACESSO AO LOCAL: O cliente ou responsável deve garantir acesso às áreas de trabalho nas datas e horários agendados. Atrasos ou impedimentos de acesso poderão gerar cobranças adicionais.

2. CONDIÇÕES PRÉ-EXISTENTES: A empresa não se responsabiliza por danos em estruturas, instalações ou revestimentos pré-existentes em condições inadequadas não identificadas ou não informadas antes do serviço.

3. GARANTIA: Serviços têm garantia de 90 dias sobre a mão de obra. Materiais e equipamentos fornecidos têm garantia conforme fabricante. A garantia não cobre danos causados por mau uso, vandalismo ou alterações por terceiros.

4. SEGURO: A empresa mantém seguro de responsabilidade civil para execução dos serviços. Danos não cobertos pelo seguro causados por negligência do contratante não são de responsabilidade da empresa.

5. SERVIÇOS ADICIONAIS: Problemas encontrados durante a execução serão comunicados imediatamente. Nenhum serviço adicional será realizado sem aprovação e ajuste no orçamento.

6. MATERIAIS: Os materiais utilizados atendem às normas técnicas vigentes. A empresa reserva o direito de recusar o uso de materiais fornecidos pelo cliente que não atendam aos requisitos mínimos de qualidade.

7. PAGAMENTO: Obras de maior porte podem exigir pagamento por etapas conforme cronograma definido no contrato.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. SITE ACCESS: The customer or responsible party must ensure access to work areas on the scheduled dates and times. Delays or access issues may result in additional charges.

2. PRE-EXISTING CONDITIONS: The company is not responsible for damage to pre-existing structures, installations, or finishes in inadequate condition that were not identified or disclosed before the service.

3. WARRANTY: Services carry a 90-day labor warranty. Supplied materials and equipment carry the manufacturer's warranty. Warranty does not cover damage from misuse, vandalism, or modifications by third parties.

4. INSURANCE: The company maintains liability insurance for service execution. Damages not covered by insurance caused by the contractor's negligence are not the company's responsibility.

5. ADDITIONAL SERVICES: Issues found during execution will be communicated immediately. No additional work will be performed without approval and quote adjustment.

6. MATERIALS: All materials used comply with applicable technical standards. The company reserves the right to refuse customer-supplied materials that do not meet minimum quality requirements.

7. PAYMENT: Larger projects may require staged payments according to a schedule defined in the contract.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. ACCESO AL LUGAR: El cliente o responsable debe garantizar el acceso a las áreas de trabajo en las fechas y horarios programados. Los retrasos o impedimentos de acceso podrán generar cargos adicionales.

2. CONDICIONES PREEXISTENTES: La empresa no se responsabiliza por daños en estructuras, instalaciones o revestimientos preexistentes en condiciones inadecuadas no identificadas o no informadas antes del servicio.

3. GARANTÍA: Los servicios tienen garantía de 90 días sobre la mano de obra. Los materiales y equipos suministrados tienen garantía según el fabricante. La garantía no cubre daños causados por mal uso, vandalismo o modificaciones por terceros.

4. SEGURO: La empresa mantiene un seguro de responsabilidad civil para la ejecución de los servicios. Los daños no cubiertos por el seguro causados por negligencia del contratante no son responsabilidad de la empresa.

5. SERVICIOS ADICIONALES: Los problemas encontrados durante la ejecución serán comunicados de inmediato. No se realizará ningún servicio adicional sin aprobación y ajuste en el presupuesto.

6. MATERIALES: Los materiales utilizados cumplen con las normas técnicas vigentes. La empresa se reserva el derecho de rechazar materiales proporcionados por el cliente que no cumplan los requisitos mínimos de calidad.

7. PAGO: Las obras de mayor envergadura pueden requerir pagos por etapas según el cronograma definido en el contrato.`,
  },

  // ═══════════════════════════════════════════════════════════
  // BICICLETAS
  // ═══════════════════════════════════════════════════════════
  bicycles: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: A bicicleta deve ser retirada em até 5 dias úteis após a conclusão do serviço. Bicicletas não retiradas em 90 dias serão consideradas abandonadas.

2. ABANDONO: Bicicletas consideradas abandonadas poderão ser doadas, leiloadas ou descartadas para cobrir os custos do serviço, conforme previsão legal.

3. GARANTIA: Peças substituídas têm garantia de 90 dias. A mão de obra tem garantia de 30 dias. A garantia não cobre desgaste natural, danos por quedas, mau uso ou exposição prolongada ao tempo.

4. ACESSÓRIOS: A bicicletaria não se responsabiliza por acessórios (capacetes, bolsas, lanternas, etc.) deixados com a bicicleta. Recomendamos a retirada de todos os acessórios antes da entrega.

5. SERVIÇOS ADICIONAIS: Problemas adicionais identificados durante o serviço serão comunicados ao cliente. Nenhuma intervenção extra será realizada sem aprovação.

6. PAGAMENTO: O pagamento é devido na retirada da bicicleta. A bicicleta poderá ser retida como garantia de pagamento.

7. PEÇAS SUBSTITUÍDAS: Componentes trocados ficam à disposição na retirada. Não solicitados, serão descartados em 5 dias.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The bicycle must be picked up within 5 business days of service completion. Bicycles not retrieved within 90 days will be considered abandoned.

2. ABANDONMENT POLICY: Bicycles considered abandoned may be donated, auctioned, or discarded to cover service costs, as permitted by law.

3. WARRANTY: Replacement parts carry a 90-day warranty. Labor carries a 30-day warranty. Warranty does not cover normal wear, crash damage, misuse, or prolonged weather exposure.

4. ACCESSORIES: The shop is not responsible for accessories (helmets, bags, lights, etc.) left with the bicycle. We recommend removing all accessories before drop-off.

5. ADDITIONAL SERVICES: Any additional issues identified during service will be communicated to the customer. No extra work will be performed without approval.

6. PAYMENT: Payment is due at bicycle pickup. The bicycle may be held as payment guarantee.

7. REPLACED PARTS: Replaced components are available for retrieval at pickup. Unclaimed parts will be discarded within 5 days.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: La bicicleta debe retirarse dentro de los 5 días hábiles posteriores a la finalización del servicio. Las bicicletas no retiradas en 90 días serán consideradas abandonadas.

2. ABANDONO: Las bicicletas consideradas abandonadas podrán ser donadas, subastadas o descartadas para cubrir los costos del servicio, conforme a la ley.

3. GARANTÍA: Las piezas sustituidas tienen garantía de 90 días. La mano de obra tiene garantía de 30 días. La garantía no cubre desgaste natural, daños por caídas, mal uso o exposición prolongada a la intemperie.

4. ACCESORIOS: La bicicletería no se responsabiliza por los accesorios (cascos, bolsas, luces, etc.) dejados con la bicicleta. Recomendamos retirar todos los accesorios antes de la entrega.

5. SERVICIOS ADICIONALES: Los problemas adicionales identificados durante el servicio serán comunicados al cliente. No se realizará ninguna intervención extra sin aprobación.

6. PAGO: El pago se realiza al momento del retiro de la bicicleta. La bicicleta podrá ser retenida como garantía de pago.

7. PIEZAS REEMPLAZADAS: Los componentes sustituidos quedan a disposición al momento del retiro. Los no reclamados serán descartados en 5 días.`,
  },

  // ═══════════════════════════════════════════════════════════
  // OUTRO (Genérico)
  // ═══════════════════════════════════════════════════════════
  other: {
    'pt-BR': `Ao aprovar este orçamento, o cliente declara estar ciente e de acordo com as seguintes condições:

1. PRAZO DE RETIRADA: O item/equipamento deve ser retirado em até 5 dias úteis após a conclusão do serviço e notificação ao cliente.

2. ABANDONO: Itens não retirados em até 90 dias após a conclusão do serviço serão considerados abandonados. A empresa poderá adotar as medidas legais cabíveis para recuperação dos custos, incluindo retenção, doação ou descarte do item.

3. GARANTIA: Os serviços prestados têm garantia de 90 dias. Peças e materiais fornecidos têm garantia conforme o fabricante. A garantia não cobre danos decorrentes de mau uso, acidentes, alterações realizadas por terceiros ou desgaste natural.

4. SERVIÇOS ADICIONAIS: Quaisquer necessidades identificadas durante a execução do serviço serão comunicadas ao cliente para aprovação antes de qualquer intervenção adicional. Nenhum serviço ou custo extra será gerado sem autorização expressa.

5. PAGAMENTO: O pagamento é devido na conclusão e entrega do serviço. A empresa reserva o direito de reter o item até a quitação integral do valor acordado.

6. LIMITAÇÃO DE RESPONSABILIDADE: A empresa não se responsabiliza por danos indiretos, lucros cessantes ou perdas consequentes. A responsabilidade máxima da empresa limita-se ao valor do serviço contratado.

7. PEÇAS SUBSTITUÍDAS: Peças ou componentes substituídos ficam à disposição do cliente para retirada no ato da entrega. Não retirados, serão descartados em até 5 dias úteis.`,

    'en-US': `By approving this quote, the customer acknowledges and agrees to the following terms and conditions:

1. PICKUP DEADLINE: The item/equipment must be picked up within 5 business days of service completion and customer notification.

2. ABANDONMENT POLICY: Items not retrieved within 90 days of service completion will be considered abandoned. The company may take legal measures to recover costs, including retention, donation, or disposal of the item.

3. WARRANTY: Services carry a 90-day warranty. Parts and materials carry the manufacturer's warranty. Warranty does not cover damage from misuse, accidents, modifications by third parties, or normal wear and tear.

4. ADDITIONAL SERVICES: Any needs identified during service execution will be communicated to the customer for approval before any additional intervention. No extra service or cost will be incurred without express authorization.

5. PAYMENT: Payment is due upon service completion and delivery. The company reserves the right to retain the item until full payment of the agreed amount.

6. LIABILITY LIMITATION: The company is not responsible for indirect damages, lost profits, or consequential losses. The company's maximum liability is limited to the value of the contracted service.

7. REPLACED PARTS: Replaced parts or components are available for customer retrieval at pickup. Unclaimed items will be discarded within 5 business days.`,

    'es-ES': `Al aprobar este presupuesto, el cliente declara estar al tanto y de acuerdo con las siguientes condiciones:

1. PLAZO DE RETIRO: El artículo/equipo debe retirarse dentro de los 5 días hábiles posteriores a la finalización del servicio y la notificación al cliente.

2. ABANDONO: Los artículos no retirados en 90 días tras la finalización del servicio serán considerados abandonados. La empresa podrá adoptar las medidas legales correspondientes para recuperar los costos, incluyendo la retención, donación o descarte del artículo.

3. GARANTÍA: Los servicios prestados tienen garantía de 90 días. Las piezas y materiales suministrados tienen garantía según el fabricante. La garantía no cubre daños por mal uso, accidentes, modificaciones por terceros o desgaste natural.

4. SERVICIOS ADICIONALES: Cualquier necesidad identificada durante la ejecución del servicio será comunicada al cliente para su aprobación antes de cualquier intervención adicional. No se generará ningún servicio o costo extra sin autorización expresa.

5. PAGO: El pago se realiza al finalizar y entregar el servicio. La empresa se reserva el derecho de retener el artículo hasta el pago íntegro del valor acordado.

6. LIMITACIÓN DE RESPONSABILIDAD: La empresa no se responsabiliza por daños indirectos, lucro cesante o pérdidas consecuentes. La responsabilidad máxima de la empresa se limita al valor del servicio contratado.

7. PIEZAS REEMPLAZADAS: Las piezas o componentes sustituidos quedan a disposición del cliente para su retiro al momento de la entrega. Los no retirados serán descartados en un plazo de 5 días hábiles.`,
  },
};

module.exports = { DEFAULT_TERMS };
