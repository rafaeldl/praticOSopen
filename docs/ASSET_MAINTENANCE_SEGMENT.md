# Segmento: Manutenção de Ativos (Asset Maintenance)

## Visão Geral

Segmento horizontal para empresas que fazem manutenção de equipamentos industriais e comerciais. Diferente dos segmentos verticais (elevadores, refrigeração, predial), este cobre **qualquer tipo de ativo/equipamento**: geradores, máquinas industriais, frotas, equipamentos médicos, cozinhas industriais, HVAC comercial, etc.

## Configuração do Segmento

| Campo | Valor |
|-------|-------|
| **Segment ID** | `asset_maintenance` |
| **Icon** | 🏭 |
| **fieldService** | `true` |
| **useDeviceManagement** | `true` |
| **useContracts** | `true` |
| **active** | `true` |

### Nomes i18n

| Idioma | Nome |
|--------|------|
| pt-BR | Manutenção de Ativos |
| en-US | Asset Maintenance |
| es-ES | Mantenimiento de Activos |

## Sub-especialidades

| ID | pt-BR | en-US | es-ES |
|----|-------|-------|-------|
| `industrial_equipment` | Equipamentos Industriais | Industrial Equipment | Equipos Industriales |
| `generators` | Geradores | Generators | Generadores |
| `hvac_commercial` | HVAC Comercial | Commercial HVAC | HVAC Comercial |
| `fleet_vehicles` | Veículos e Frotas | Fleet Vehicles | Vehículos y Flotas |
| `medical_equipment` | Equipamentos Médicos | Medical Equipment | Equipos Médicos |
| `commercial_kitchen` | Cozinhas Industriais | Commercial Kitchen | Cocinas Industriales |

## Custom Labels

Labels que sobrescrevem os padrões do sistema para adaptar a terminologia ao contexto de gestão de ativos.

| Chave | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `device._entity` | Ativo | Asset | Activo |
| `device._entity_plural` | Ativos | Assets | Activos |
| `device.brand` | Fabricante | Manufacturer | Fabricante |
| `device.serial` | Número de Série | Serial Number | Número de Serie |
| `actions.create_device` | Adicionar Ativo | Add Asset | Agregar Activo |
| `status.in_progress` | Em Manutenção | Under Maintenance | En Mantenimiento |
| `status.completed` | Operacional | Operational | Operativo |

## Custom Fields

Campos adicionais específicos do domínio de gestão de ativos.

### Seção: Identificação

| # | Chave | Tipo | pt-BR | en-US | es-ES |
|---|-------|------|-------|-------|-------|
| 1 | `device.assetTag` | text | Tag do Ativo | Asset Tag | Etiqueta del Activo |
| 2 | `device.manufacturer` | text | Fabricante | Manufacturer | Fabricante |
| 3 | `device.assetLocation` | text | Localização do Ativo | Asset Location | Ubicación del Activo |
| 4 | `device.assetCategory` | select | Categoria | Category | Categoría |

**Opções de `assetCategory`:**

| Valor | pt-BR | en-US | es-ES |
|-------|-------|-------|-------|
| `mechanical` | Mecânico | Mechanical | Mecánico |
| `electrical` | Elétrico | Electrical | Eléctrico |
| `hydraulic` | Hidráulico | Hydraulic | Hidráulico |
| `pneumatic` | Pneumático | Pneumatic | Neumático |
| `thermal` | Térmico | Thermal | Térmico |
| `electronic` | Eletrônico | Electronic | Electrónico |

### Seção: Manutenção

| # | Chave | Tipo | pt-BR | en-US | es-ES |
|---|-------|------|-------|-------|-------|
| 5 | `device.installationDate` | date | Data de Instalação | Installation Date | Fecha de Instalación |
| 6 | `device.warrantyExpiration` | date | Vencimento da Garantia | Warranty Expiration | Vencimiento de Garantía |
| 7 | `device.lastMaintenanceDate` | date | Última Manutenção | Last Maintenance | Último Mantenimiento |
| 8 | `device.operatingHours` | number | Horas de Operação | Operating Hours | Horas de Operación |

## Estrutura Firestore

### Documento do Segmento
**Path:** `segments/asset_maintenance`

### Campos padrão herdados
- `terms` (mesclado de `DEFAULT_TERMS` via seed script)
- `customFields` (labels + campos listados acima)
- `subspecialties` (6 sub-especialidades)

## Distinção de Segmentos Existentes

| Segmento | Foco | Como este é diferente |
|----------|------|-----------------------|
| Manutenção Predial (`building_maintenance`) | Estrutura do prédio (hidráulica, elétrica, pintura) | Ativos foca em **equipamentos** dentro do prédio |
| Elevadores (`elevators`) | Apenas elevadores | Ativos cobre **qualquer tipo** de equipamento |
| Refrigeração (`hvac`) | Apenas HVAC/ar-condicionado | Ativos cobre geradores, máquinas, frotas, etc. |
| Automotivo (`automotive`) | Veículos em oficina | Ativos cobre frotas em campo + outros equipamentos |

## Regulamentação Relevante

- **NR-12:** Segurança em máquinas e equipamentos (manutenção documentada obrigatória)
- **NR-13:** Caldeiras, vasos de pressão (inspeções periódicas obrigatórias)
- **NR-10:** Segurança em instalações elétricas
- **NBR 5462:** Confiabilidade e mantenabilidade — terminologia
- **ISO 55000/55001:** Gestão de ativos — requisitos e diretrizes
- **PMOC:** Plano de manutenção para ar condicionado (Lei 13.589/2018)
