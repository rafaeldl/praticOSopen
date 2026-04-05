# Segmento: Obras Públicas / Prefeituras (Public Works)

## Visão Geral

Segmento para prefeituras e órgãos públicos que precisam gerenciar contratos de licitação, acompanhar execução de obras, realizar medições e vistorias com registro fotográfico.

## Configuração do Segmento

| Campo | Valor |
|-------|-------|
| **Segment ID** | `public_works` |
| **Icon** | 🏛️ |
| **fieldService** | `true` |
| **useDeviceManagement** | `true` |
| **useContracts** | `true` |
| **useScheduling** | `true` |
| **active** | `true` |

### Nomes i18n

| Idioma | Nome |
|--------|------|
| pt-BR | Obras Públicas / Prefeituras |
| en-US | Public Works / Municipalities |
| es-ES | Obras Públicas / Municipios |

## Sub-especialidades

| ID | pt-BR | en-US | es-ES |
|----|-------|-------|-------|
| `infrastructure` | Obras de Infraestrutura | Infrastructure Works | Obras de Infraestructura |
| `maintenance_services` | Serviços de Manutenção | Maintenance Services | Servicios de Mantenimiento |
| `material_supply` | Fornecimento de Materiais | Material Supply | Suministro de Materiales |
| `it_services` | Serviços de TI | IT Services | Servicios de TI |
| `cleaning_conservation` | Limpeza e Conservação | Cleaning & Conservation | Limpieza y Conservación |
| `consulting` | Consultoria e Projetos | Consulting & Projects | Consultoría y Proyectos |

## Mapeamento de Conceitos

| Conceito Municipal | Abstração PraticOS |
|---|---|
| Prefeitura | Company (tenant) |
| Empresa Contratada | Collaborator + Customer |
| Obra / Projeto | Device |
| Contrato de Licitação | Order |
| Medição / Liberação | PaymentTransaction |
| Vistoria / Inspeção | Dynamic Form |
| Fiscal do Contrato | assignedTo |

## Custom Labels

Labels que sobrescrevem os padrões do sistema para adaptar a terminologia ao contexto de gestão de obras públicas.

### Entidades

| Chave | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `device._entity` | Obra | Project | Obra |
| `device._entity_plural` | Obras | Projects | Obras |
| `device.brand` | Construtora | Contractor | Constructora |
| `device.serial` | Código da Obra | Project Code | Código de Obra |
| `customer._entity` | Empresa Contratada | Contracted Company | Empresa Contratada |
| `customer._entity_plural` | Empresas Contratadas | Contracted Companies | Empresas Contratadas |
| `order._entity` | Contrato | Contract | Contrato |
| `order._entity_plural` | Contratos | Contracts | Contratos |
| `product._entity` | Serviço / Etapa | Service / Phase | Servicio / Etapa |
| `product._entity_plural` | Serviços / Etapas | Services / Phases | Servicios / Etapas |

### Status

| Chave | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `status.pending` | Aguardando Licitação | Awaiting Bid | Pendiente de Licitación |
| `status.approved` | Contrato Firmado | Contract Signed | Contrato Firmado |
| `status.in_progress` | Em Execução | Under Execution | En Ejecución |
| `status.completed` | Obra Concluída | Project Completed | Obra Concluida |
| `status.cancelled` | Contrato Rescindido | Contract Terminated | Contrato Rescindido |

### Ações

| Chave | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `actions.create_device` | Cadastrar Obra | Register Project | Registrar Obra |
| `actions.create_order` | Novo Contrato | New Contract | Nuevo Contrato |
| `actions.approve` | Firmar Contrato | Sign Contract | Firmar Contrato |
| `actions.complete` | Concluir Obra | Complete Project | Concluir Obra |

### Financeiro

| Chave | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `financial.payment` | Medição | Measurement | Medición |
| `financial.payment_plural` | Medições | Measurements | Mediciones |
| `financial.total` | Valor do Contrato | Contract Value | Valor del Contrato |
| `financial.paid` | Valor Medido | Measured Value | Valor Medido |
| `financial.remaining` | Saldo Remanescente | Remaining Balance | Saldo Remanente |

## Custom Fields

Campos adicionais específicos do domínio de obras públicas.

### Seção: Dados do Contrato

| # | Chave | Tipo | pt-BR | en-US | es-ES |
|---|-------|------|-------|-------|-------|
| 1 | `order.bidModality` | select | Modalidade de Licitação | Bid Modality | Modalidad de Licitación |
| 2 | `order.bidNumber` | text | Nº da Licitação | Bid Number | Nº de Licitación |
| 3 | `order.contractNumber` | text | Nº do Contrato | Contract Number | Nº de Contrato |
| 4 | `order.contractStartDate` | date | Início do Contrato | Contract Start Date | Inicio del Contrato |
| 5 | `order.contractEndDate` | date | Término do Contrato | Contract End Date | Fin del Contrato |
| 6 | `order.contractValue` | currency | Valor Global do Contrato | Total Contract Value | Valor Global del Contrato |
| 7 | `order.fundingSource` | text | Fonte de Recurso | Funding Source | Fuente de Recursos |
| 8 | `order.inspector` | text | Fiscal do Contrato | Contract Inspector | Fiscal del Contrato |

**Opções de `bidModality`:**

| Valor | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `competition` | Concorrência | Open Competition | Concurso Público |
| `price_taking` | Tomada de Preços | Price Taking | Toma de Precios |
| `invitation` | Convite | Invitation | Invitación |
| `electronic_auction` | Pregão Eletrônico | Electronic Auction | Subasta Electrónica |
| `in_person_auction` | Pregão Presencial | In-Person Auction | Subasta Presencial |
| `competitive_dialogue` | Diálogo Competitivo | Competitive Dialogue | Diálogo Competitivo |
| `contest` | Concurso | Contest | Concurso |
| `direct_procurement` | Dispensa de Licitação | Direct Procurement | Contratación Directa |
| `unenforceability` | Inexigibilidade | Unenforceability | Inexigibilidad |

### Seção: Dados da Execução

| # | Chave | Tipo | pt-BR | en-US | es-ES |
|---|-------|------|-------|-------|-------|
| 9 | `device.projectAddress` | text | Endereço da Obra | Project Address | Dirección de la Obra |
| 10 | `device.estimatedArea` | number | Área Estimada (m²) | Estimated Area (m²) | Área Estimada (m²) |
| 11 | `device.executionPercentage` | number | Percentual Executado (%) | Execution Percentage (%) | Porcentaje Ejecutado (%) |
| 12 | `device.workOrderNumber` | text | Nº da Ordem de Serviço | Work Order Number | Nº de Orden de Servicio |
| 13 | `device.startDate` | date | Data de Início da Obra | Project Start Date | Fecha de Inicio de la Obra |
| 14 | `device.expectedCompletionDate` | date | Previsão de Conclusão | Expected Completion | Previsión de Conclusión |

## Form Templates

Templates de formulários dinâmicos pré-configurados para o segmento.

### 1. Medição de Obra (`medicao_obra`)

Formulário para registrar medições periódicas de etapas da obra.

| # | Campo | Tipo | Obrigatório |
|---|-------|------|-------------|
| 1 | Período da Medição (início) | date | Sim |
| 2 | Período da Medição (fim) | date | Sim |
| 3 | Nº da Medição | number | Sim |
| 4 | Etapa / Serviço Medido | text | Sim |
| 5 | Quantidade Executada | number | Sim |
| 6 | Unidade de Medida | select (m², m³, m, un, vb, kg) | Sim |
| 7 | Valor Unitário | currency | Sim |
| 8 | Valor Total da Etapa | currency | Sim (calculado) |
| 9 | Percentual Executado da Etapa | number | Sim |
| 10 | Registro Fotográfico | photo | Sim |
| 11 | Observações | text_multiline | Não |

### 2. Vistoria de Andamento (`vistoria_andamento`)

Formulário para vistorias periódicas de acompanhamento da obra.

| # | Campo | Tipo | Obrigatório |
|---|-------|------|-------------|
| 1 | Data da Vistoria | date | Sim |
| 2 | Fiscal Responsável | text | Sim |
| 3 | Situação Geral da Obra | select (conforme, com_ressalvas, irregular) | Sim |
| 4 | Cronograma | select (adiantado, em_dia, atrasado) | Sim |
| 5 | Qualidade dos Materiais | select (conforme, nao_conforme) | Sim |
| 6 | Segurança do Trabalho | select (conforme, nao_conforme) | Sim |
| 7 | Limpeza e Organização | select (conforme, nao_conforme) | Sim |
| 8 | Registro Fotográfico Geral | photo | Sim |
| 9 | Não Conformidades Encontradas | text_multiline | Não |
| 10 | Prazo para Correção | date | Não |
| 11 | Parecer do Fiscal | text_multiline | Sim |

### 3. Termo de Recebimento (`termo_recebimento`)

Formulário para recebimento provisório ou definitivo da obra.

| # | Campo | Tipo | Obrigatório |
|---|-------|------|-------------|
| 1 | Tipo de Recebimento | select (provisorio, definitivo) | Sim |
| 2 | Data do Recebimento | date | Sim |
| 3 | Comissão de Recebimento | text_multiline | Sim |
| 4 | Conformidade com o Projeto | select (conforme, com_ressalvas) | Sim |
| 5 | Conformidade com Especificações | select (conforme, com_ressalvas) | Sim |
| 6 | Pendências Identificadas | text_multiline | Não |
| 7 | Prazo para Correção de Pendências | date | Não |
| 8 | Registro Fotográfico Final | photo | Sim |
| 9 | Parecer Final | text_multiline | Sim |
| 10 | Assinatura Digital | signature | Sim |

### 4. Checklist de Conformidade Legal (`checklist_conformidade_legal`)

Formulário para verificação de conformidade com exigências legais e contratuais.

| # | Campo | Tipo | Obrigatório |
|---|-------|------|-------------|
| 1 | ART/RRT Registrada | select (sim, nao, nao_aplicavel) | Sim |
| 2 | Alvará de Construção | select (sim, nao, nao_aplicavel) | Sim |
| 3 | Licença Ambiental | select (sim, nao, nao_aplicavel) | Sim |
| 4 | Seguro de Obra | select (sim, nao) | Sim |
| 5 | Garantia Contratual | select (sim, nao) | Sim |
| 6 | Regularidade Fiscal (CNDT, CRF, CND) | select (regular, irregular) | Sim |
| 7 | Diário de Obra Atualizado | select (sim, nao) | Sim |
| 8 | Planilha Orçamentária Aprovada | select (sim, nao) | Sim |
| 9 | Cronograma Físico-Financeiro | select (sim, nao) | Sim |
| 10 | Registro Fotográfico | photo | Não |
| 11 | Observações | text_multiline | Não |

## Fluxo Completo do Usuário

```
1. Cadastrar Empresa Contratada (Customer)
   └── CNPJ, Razão Social, Responsável Técnico

2. Cadastrar Obra (Device)
   └── Nome da obra, endereço, área, código
   └── Vincular à empresa contratada

3. Criar Contrato (Order)
   └── Nº da licitação, modalidade, nº do contrato
   └── Valor global, prazo, fiscal responsável
   └── Vincular à obra e à empresa contratada
   └── Status: "Aguardando Licitação" → "Contrato Firmado"

4. Registrar Medições (PaymentTransaction + Dynamic Form)
   └── Preencher formulário de medição (medicao_obra)
   └── Registrar valor medido como transação financeira
   └── Anexar fotos e documentos
   └── Status do contrato: "Em Execução"

5. Realizar Vistorias (Dynamic Form)
   └── Preencher vistoria de andamento (vistoria_andamento)
   └── Registrar conformidades e não conformidades
   └── Anexar registro fotográfico

6. Verificar Conformidade Legal (Dynamic Form)
   └── Preencher checklist (checklist_conformidade_legal)
   └── Garantir documentação em dia

7. Concluir Obra
   └── Preencher termo de recebimento provisório (termo_recebimento)
   └── Aguardar prazo contratual
   └── Preencher termo de recebimento definitivo
   └── Status: "Obra Concluída"
```

## Estrutura Firestore

### Documento do Segmento
**Path:** `segments/public_works`

### Campos padrão herdados
- `terms` (mesclado de `DEFAULT_TERMS` via seed script)
- `customFields` (labels + campos listados acima)
- `subspecialties` (6 sub-especialidades)

## Distinção de Segmentos Existentes

| Segmento | Foco | Como este é diferente |
|----------|------|-----------------------|
| Manutenção Predial (`building_maintenance`) | Manutenção de estrutura predial | Obras Públicas foca em **construção e contratos de licitação** |
| Manutenção de Ativos (`asset_maintenance`) | Equipamentos e ativos | Obras Públicas gerencia **obras civis e contratos governamentais** |
| Construção Civil (`construction`) | Construtoras privadas | Obras Públicas atende **setor público** com licitações e fiscalização |

## Regulamentação Relevante

- **Lei 14.133/2021:** Nova Lei de Licitações e Contratos Administrativos (substitui a Lei 8.666/1993)
- **Lei 8.666/1993:** Lei de Licitações (ainda aplicável em contratos vigentes)
- **Lei 10.520/2002:** Pregão (parcialmente revogada pela Lei 14.133)
- **Decreto 10.024/2019:** Regulamenta o pregão eletrônico
- **Lei 12.462/2011:** Regime Diferenciado de Contratações Públicas (RDC)
- **NBR 12.721:** Critérios para avaliação de custos de construção
- **NBR 15.575:** Norma de desempenho de edificações
- **TCU/TCE:** Orientações dos Tribunais de Contas para fiscalização de obras públicas
- **SINAPI:** Sistema Nacional de Pesquisa de Custos e Índices da Construção Civil (referência de preços)
