# Company Bootstrap - Dados Iniciais por Segmento

## Visão Geral

Este documento especifica os dados iniciais (seed data) que devem ser criados automaticamente quando uma nova empresa (tenant) é registrada no sistema PraticOS. O objetivo é proporcionar uma experiência inicial mais rica, permitindo que o usuário explore o sistema com dados de exemplo relevantes ao seu segmento e especialidade.

## Princípios

1. **Relevância**: Dados devem ser condizentes com o segmento e subcategoria escolhidos
2. **Utilidade**: Exemplos devem ser práticos e comuns no dia a dia do segmento
3. **Simplicidade**: Quantidade mínima para demonstrar funcionalidades sem sobrecarregar
4. **Editabilidade**: Usuário deve poder editar/excluir os dados de exemplo facilmente

---

## Arquitetura: Segmentos e Subcategorias

### Estrutura Hierárquica

Alguns segmentos possuem **subcategorias (subspecialties)** que determinam os dados de bootstrap específicos.

```
Segmento (segment)
└── Subcategoria (subspecialty) [opcional]
    └── Dados de Bootstrap (services, products, devices, customer)
```

### Modelo de Dados

#### Firestore: Documento do Segmento

```javascript
// /segments/{segmentId}
{
  id: 'automotive',
  name: 'Automotivo',
  icon: '🚗',
  active: true,

  // Subcategorias (opcional - nem todo segmento tem)
  subspecialties: [
    {
      id: 'mechanical',
      name: 'Oficina Mecânica',
      icon: '🔧',
      description: 'Manutenção e reparo mecânico de veículos'
    },
    {
      id: 'carwash',
      name: 'Lava Car',
      icon: '🚿',
      description: 'Lavagem e limpeza de veículos'
    },
    {
      id: 'painting',
      name: 'Funilaria e Pintura',
      icon: '🎨',
      description: 'Pintura, polimento e reparos estéticos'
    },
    {
      id: 'bodywork',
      name: 'Lanternagem / Reparos',
      icon: '🛠️',
      description: 'Reparos de lataria e martelinho de ouro'
    },
  ],

  customFields: [...] // campos personalizados do segmento
}
```

#### Flutter: Model Company

```dart
@JsonSerializable(explicitToJson: true)
class Company extends BaseAudit {
  String? name;
  String? email;
  String? address;
  String? logo;
  String? phone;
  String? site;
  String? segment;            // ID do segmento: 'automotive', 'hvac', etc.
  List<String>? subspecialties; // IDs das subcategorias: ['mechanical', 'carwash'] (múltiplas)
  UserAggr? owner;
  List<UserRoleAggr>? users;
}
```

**Nota:** Uma empresa pode atuar em múltiplas subcategorias. Por exemplo:
- Oficina mecânica que também oferece lava car: `['mechanical', 'carwash']`
- Funilaria completa: `['painting', 'bodywork']`
- Centro automotivo completo: `['mechanical', 'carwash', 'painting', 'bodywork']`

### Fluxo de Onboarding

```
┌─────────────────────────────────────┐
│  1. Dados da Empresa                │
│     (nome, endereço, contato)       │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  2. Seleção de Segmento             │
│     (lista de segmentos ativos)     │
└──────────────┬──────────────────────┘
               ▼
       ┌───────┴───────┐
       │ Tem           │ Não
       │ subcategorias?│────────────────┐
       └───────┬───────┘                │
               │ Sim                    │
               ▼                        │
┌─────────────────────────────────────┐ │
│  3. Seleção de Subcategorias        │ │
│     (múltipla escolha - checkboxes) │ │
│     Ex: ☑ Mecânica ☑ Lava Car       │ │
└──────────────┬──────────────────────┘ │
               │                        │
               ▼                        ▼
┌─────────────────────────────────────────┐
│  4. Pergunta: Criar Dados de Exemplo?   │
│                                         │
│  "Deseja que criemos alguns serviços,   │
│   produtos e clientes de exemplo para   │
│   você começar?"                        │
│                                         │
│  [Sim, criar exemplos]  [Não, obrigado] │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  5. Criação da Empresa                  │
│     - Salva company com segment +       │
│       subspecialties[] (array)          │
│     - Se optou por exemplos:            │
│       → Executa bootstrap               │
└─────────────────────────────────────────┘
```

### Tela de Confirmação de Dados de Exemplo

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  🎉  Quase lá!                                          │
│                                                         │
│  Podemos criar alguns dados de exemplo para você        │
│  começar a usar o sistema imediatamente:                │
│                                                         │
│  ✓ 8 serviços comuns do seu segmento                   │
│  ✓ 8 produtos/peças mais utilizados                    │
│  ✓ 2-3 equipamentos de exemplo                          │
│  ✓ 1 cliente de demonstração                            │
│                                                         │
│  Você poderá editar ou excluir esses dados             │
│  a qualquer momento.                                    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │          Sim, criar dados de exemplo            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │          Não, começar do zero                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Comportamento do Bootstrap

**Com múltiplas subcategorias:**
- Os dados de bootstrap são a **união** de todas as subcategorias selecionadas
- Serviços/produtos duplicados são incluídos apenas uma vez (por nome)
- Equipamentos de exemplo são incluídos de cada subcategoria

**Prevenção de duplicação:**
- Antes de criar, verificar se já existe registro com mesmo nome
- Se existir, pular a criação daquele item
- Registrar no metadata quais itens foram criados

---

## Quantidades por Entidade

| Entidade | Quantidade | Justificativa |
|----------|------------|---------------|
| Serviços | 5-8 | Suficiente para demonstrar variedade |
| Produtos | 5-8 | Itens comuns usados no segmento |
| Equipamentos | 2-3 | Exemplos de cadastro de equipamentos |
| Clientes | 1 | Cliente de demonstração |

---

## 1. AUTOMOTIVO (automotive)

O segmento automotivo possui **4 subcategorias** com dados de bootstrap distintos:

### 1.1 Oficina Mecânica (mechanical)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Troca de óleo | 80.00 | Troca de óleo do motor com filtro |
| Alinhamento | 120.00 | Alinhamento de direção computadorizado |
| Balanceamento | 60.00 | Balanceamento das 4 rodas |
| Revisão de freios | 150.00 | Inspeção e ajuste do sistema de freios |
| Diagnóstico eletrônico | 100.00 | Scanner e diagnóstico de falhas |
| Troca de pastilhas de freio | 180.00 | Substituição de pastilhas dianteiras |
| Higienização do ar | 90.00 | Limpeza do sistema de ar condicionado |
| Troca de correia dentada | 350.00 | Substituição de correia e tensionadores |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Óleo 5W30 Sintético (1L) | 45.00 |
| Filtro de óleo | 35.00 |
| Filtro de ar | 55.00 |
| Filtro de combustível | 65.00 |
| Pastilha de freio dianteira (jogo) | 120.00 |
| Lâmpada farol H7 | 25.00 |
| Fluido de freio DOT 4 (500ml) | 35.00 |
| Vela de ignição | 28.00 |

#### Equipamentos (Veículos)

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Onix 1.0 | Chevrolet | Hatch | ano: 2022, km: 45000, cor: Prata |
| HB20 1.6 | Hyundai | Hatch | ano: 2021, km: 38000, cor: Branco |

---

### 1.2 Lava Car (carwash)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Lavagem simples | 40.00 | Lavagem externa básica |
| Lavagem completa | 70.00 | Lavagem externa + interna |
| Lavagem detalhada | 120.00 | Lavagem completa + motor + porta-malas |
| Higienização interna | 150.00 | Limpeza profunda de estofados e carpetes |
| Lavagem de motor | 80.00 | Limpeza e desengraxe do motor |
| Enceramento | 100.00 | Aplicação de cera protetora |
| Cristalização de vidros | 80.00 | Tratamento hidrofóbico nos vidros |
| Hidratação de couro | 90.00 | Tratamento de bancos de couro |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Shampoo automotivo (5L) | 35.00 |
| Cera líquida (500ml) | 45.00 |
| Pretinho para pneus (1L) | 25.00 |
| Limpa vidros (500ml) | 18.00 |
| Aromatizante (unidade) | 12.00 |
| Silicone para painel (300ml) | 22.00 |
| Desengraxante (1L) | 28.00 |
| Hidratante de couro (500ml) | 55.00 |

#### Equipamentos (Veículos)

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Corolla XEi | Toyota | Sedan | ano: 2023, cor: Preto |
| Tracker LT | Chevrolet | SUV | ano: 2022, cor: Branco |

---

### 1.3 Funilaria e Pintura (painting)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Pintura de para-choque | 450.00 | Pintura completa de para-choque |
| Pintura de porta | 600.00 | Pintura completa de porta |
| Pintura de capô | 700.00 | Pintura completa de capô |
| Polimento técnico | 250.00 | Polimento para remoção de riscos |
| Vitrificação | 800.00 | Proteção cerâmica da pintura |
| Retoque de pintura | 150.00 | Correção de pequenas avarias |
| Reparo de para-choque | 300.00 | Reparo de trincas e furos |
| Envelopamento parcial | 500.00 | Aplicação de película em peças |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Tinta automotiva (lata) | 180.00 |
| Verniz automotivo (1L) | 120.00 |
| Massa plástica (kg) | 35.00 |
| Lixa d'água (pacote) | 15.00 |
| Primer (1L) | 65.00 |
| Thinner (1L) | 28.00 |
| Cera de polimento (500g) | 85.00 |
| Fita crepe automotiva | 18.00 |

#### Equipamentos (Veículos)

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Civic Touring | Honda | Sedan | ano: 2022, cor: Cinza |
| Kicks Advance | Nissan | SUV | ano: 2021, cor: Vermelho |

---

### 1.4 Lanternagem / Reparos (bodywork)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Martelinho de ouro | 200.00 | Reparo de amassados sem pintura (PDR) |
| Desamassar porta | 350.00 | Reparo de amassado em porta |
| Desamassar capô | 400.00 | Reparo de amassado em capô |
| Desamassar teto | 500.00 | Reparo de amassado por granizo |
| Troca de para-lama | 250.00 | Substituição de para-lama |
| Alinhamento de carroceria | 600.00 | Correção estrutural de carroceria |
| Reparo de paralama | 300.00 | Reparo de amassado em paralama |
| Solda de lataria | 180.00 | Serviço de solda em peças |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Kit ferramentas PDR | 450.00 |
| Cola para PDR (kg) | 85.00 |
| Ventosa profissional | 120.00 |
| Martelo de borracha | 45.00 |
| Tas de repuxo (jogo) | 180.00 |
| Eletrodo de solda (kg) | 35.00 |
| Esmerilhadeira (disco) | 15.00 |
| Removedor de cola | 28.00 |

#### Equipamentos (Veículos)

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Creta Attitude | Hyundai | SUV | ano: 2023, cor: Prata |
| Polo TSI | Volkswagen | Hatch | ano: 2022, cor: Azul |

---

## 2. HVAC (hvac)

O segmento HVAC possui **3 subcategorias** com dados de bootstrap distintos:

### 2.1 Residencial (residential)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de split | 350.00 | Instalação completa de ar split |
| Manutenção preventiva | 180.00 | Limpeza e verificação geral |
| Higienização | 120.00 | Limpeza profunda com produtos específicos |
| Carga de gás | 250.00 | Recarga de gás refrigerante |
| Reparo de vazamento | 200.00 | Detecção e reparo de vazamentos |
| Troca de capacitor | 150.00 | Substituição de capacitor queimado |
| Desinstalação | 150.00 | Remoção segura do equipamento |
| Instalação de suporte | 120.00 | Instalação de suporte para condensadora |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Gás R410A (kg) | 120.00 |
| Gás R32 (kg) | 130.00 |
| Capacitor 35μF | 45.00 |
| Capacitor 25μF | 40.00 |
| Filtro de ar (universal) | 25.00 |
| Suporte para condensadora | 85.00 |
| Tubo de cobre 1/4 (metro) | 35.00 |
| Fita térmica (rolo) | 18.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Split 12000 BTUs | Samsung | Split | btus: 12000, voltagem: 220V, gas: R410A |
| Split 9000 BTUs | LG | Split | btus: 9000, voltagem: 220V, gas: R32 |

---

### 2.2 Comercial/Industrial (commercial)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de VRF | 2500.00 | Instalação de sistema VRF |
| Manutenção de chiller | 800.00 | Manutenção preventiva de chiller |
| Manutenção de câmara fria | 600.00 | Verificação e ajustes de câmara fria |
| Carga de gás industrial | 450.00 | Recarga de gás em equipamentos comerciais |
| Limpeza de dutos | 350.00 | Limpeza de sistema de dutos |
| Balanceamento de vazão | 400.00 | Ajuste de vazão de ar em ambientes |
| Manutenção preventiva predial | 500.00 | Contrato de manutenção mensal |
| Reparo de fancoil | 300.00 | Manutenção de fancoil |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Gás R410A (kg) | 120.00 |
| Gás R404A (kg) | 150.00 |
| Compressor rotativo | 1200.00 |
| Motor ventilador | 450.00 |
| Filtro de ar industrial | 85.00 |
| Termostato digital | 180.00 |
| Válvula de expansão | 350.00 |
| Pressostato | 120.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Cassete 36000 BTUs | Daikin | Cassete | btus: 36000, voltagem: 220V, gas: R410A |
| Split Piso Teto 48000 BTUs | Carrier | Piso Teto | btus: 48000, voltagem: Trifásico, gas: R410A |
| Câmara Fria 10m³ | Elgin | Câmara Fria | temperatura: -18°C, voltagem: 220V |

---

### 2.3 Ar Automotivo (automotive_ac)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Recarga de gás | 200.00 | Recarga de gás R134a |
| Higienização do sistema | 120.00 | Limpeza do sistema de ar |
| Troca de filtro de cabine | 80.00 | Substituição do filtro antipólen |
| Reparo de compressor | 450.00 | Reparo ou substituição do compressor |
| Troca de condensador | 350.00 | Substituição do condensador |
| Troca de evaporador | 400.00 | Substituição do evaporador |
| Diagnóstico de vazamento | 100.00 | Detecção de vazamentos no sistema |
| Troca de válvula de expansão | 250.00 | Substituição da válvula de expansão |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Gás R134a (kg) | 100.00 |
| Gás R1234yf (kg) | 350.00 |
| Filtro secador | 85.00 |
| Óleo PAG (250ml) | 65.00 |
| Filtro de cabine | 45.00 |
| Válvula de expansão universal | 180.00 |
| Pressostato automotivo | 95.00 |
| Anel de vedação (kit) | 35.00 |

#### Equipamentos (Veículos)

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Civic EXL | Honda | Sedan | ano: 2022, km: 35000, gas: R134a |
| Hilux SRV | Toyota | Pickup | ano: 2021, km: 62000, gas: R134a |

---

#### Cliente de Exemplo (HVAC)

Para todas as subcategorias do segmento HVAC, usar:

| Campo | Valor |
|-------|-------|
| Nome | Maria Santos (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Av. Exemplo, 456 |

---

## 3. Smartphones (smartphones)

> Sem subcategorias

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Troca de tela | 250.00 | Substituição de display LCD/OLED |
| Troca de bateria | 120.00 | Substituição de bateria |
| Troca de conector de carga | 100.00 | Reparo do conector USB/Lightning |
| Reparo de placa | 200.00 | Micro soldagem em placa |
| Atualização de software | 50.00 | Atualização do sistema operacional |
| Backup de dados | 80.00 | Backup completo do dispositivo |
| Limpeza interna | 60.00 | Limpeza de poeira e oxidação |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Tela iPhone 11 | 350.00 |
| Tela Samsung A54 | 280.00 |
| Bateria iPhone (genérica) | 80.00 |
| Bateria Samsung (genérica) | 70.00 |
| Conector de carga USB-C | 25.00 |
| Película de vidro | 15.00 |
| Capinha de silicone | 20.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| iPhone 13 | Apple | Smartphone |
| Galaxy S23 | Samsung | Smartphone |
| Moto G84 | Motorola | Smartphone |

#### Cliente de Exemplo

| Campo | Valor |
|-------|-------|
| Nome | Pedro Oliveira (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Rua Exemplo, 789 |

---

## 4. Computers (computers)

O segmento Informática possui **4 subcategorias** com dados de bootstrap distintos:

### 4.1 Desktop/PC (desktop)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Formatação e instalação | 150.00 | Formatação com instalação de SO |
| Limpeza interna | 80.00 | Limpeza de poeira e troca de pasta |
| Remoção de vírus | 100.00 | Scan e remoção de malware |
| Upgrade de memória | 80.00 | Instalação de memória RAM |
| Instalação de SSD | 100.00 | Migração de HD para SSD |
| Montagem de PC | 250.00 | Montagem de computador completo |
| Troca de fonte | 120.00 | Substituição de fonte de alimentação |
| Upgrade de placa de vídeo | 100.00 | Instalação de GPU |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Memória RAM DDR4 8GB | 180.00 |
| Memória RAM DDR4 16GB | 320.00 |
| SSD 240GB | 200.00 |
| SSD 480GB | 320.00 |
| Fonte 500W 80 Plus | 280.00 |
| Pasta térmica (5g) | 25.00 |
| Cabo SATA | 15.00 |
| Cooler para processador | 120.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| Desktop OptiPlex 3080 | Dell | Desktop |
| PC Gamer Custom | Montado | Desktop |

---

### 4.2 Notebooks (notebook)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Formatação e instalação | 150.00 | Formatação com instalação de SO |
| Troca de tela | 450.00 | Substituição de display LCD/LED |
| Troca de teclado | 200.00 | Substituição de teclado |
| Troca de bateria | 250.00 | Substituição de bateria |
| Reparo de dobradiça | 180.00 | Reparo ou troca de dobradiças |
| Troca de conector DC | 150.00 | Reparo do conector de energia |
| Upgrade de memória | 80.00 | Instalação de RAM |
| Troca de cooler | 120.00 | Substituição do sistema de refrigeração |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Tela 15.6" HD | 380.00 |
| Tela 14" Full HD | 450.00 |
| Bateria universal 6 células | 200.00 |
| Teclado notebook (compatível) | 150.00 |
| SSD M.2 NVMe 256GB | 250.00 |
| Memória DDR4 SODIMM 8GB | 190.00 |
| Cooler para notebook | 85.00 |
| Pasta térmica (5g) | 25.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| IdeaPad 3i | Lenovo | Notebook |
| MacBook Air M1 | Apple | Notebook |
| Inspiron 15 | Dell | Notebook |

---

### 4.3 Redes (networks)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de rede cabeada | 350.00 | Instalação de pontos de rede |
| Configuração de roteador | 100.00 | Setup de roteador Wi-Fi |
| Instalação de rack | 250.00 | Montagem de rack de rede |
| Crimpagem de cabos (ponto) | 25.00 | Conectorização de cabo UTP |
| Configuração de switch | 150.00 | Setup de switch gerenciável |
| Passagem de cabos (metro) | 15.00 | Instalação de infraestrutura |
| Configuração de Access Point | 120.00 | Setup de AP Wi-Fi |
| Diagnóstico de rede | 100.00 | Análise de problemas de conectividade |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Cabo UTP Cat5e (metro) | 3.50 |
| Cabo UTP Cat6 (metro) | 5.00 |
| Conector RJ45 (pacote 100) | 45.00 |
| Switch 8 portas | 150.00 |
| Switch 16 portas | 280.00 |
| Roteador Wi-Fi 6 | 350.00 |
| Access Point | 280.00 |
| Patch panel 24 portas | 180.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| Switch SG1008D | TP-Link | Switch |
| Roteador Archer AX23 | TP-Link | Roteador |
| Access Point EAP225 | TP-Link | Access Point |

---

### 4.4 Servidores (servers)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de servidor | 500.00 | Setup completo de servidor |
| Configuração de RAID | 250.00 | Configuração de array de discos |
| Instalação de Windows Server | 300.00 | Instalação e configuração de SO |
| Instalação de Linux Server | 250.00 | Instalação e configuração de SO |
| Configuração de backup | 200.00 | Setup de rotina de backup |
| Manutenção preventiva | 350.00 | Limpeza e verificação de hardware |
| Expansão de storage | 200.00 | Instalação de discos adicionais |
| Virtualização (por VM) | 150.00 | Configuração de máquina virtual |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| HD Enterprise 1TB | 450.00 |
| HD Enterprise 4TB | 850.00 |
| SSD Enterprise 480GB | 550.00 |
| Memória ECC 16GB | 450.00 |
| Controladora RAID | 800.00 |
| Fonte redundante | 650.00 |
| Nobreak 1500VA | 950.00 |
| Cabo de rede Cat6 (patch cord) | 25.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| PowerEdge T140 | Dell | Servidor Torre |
| ProLiant ML30 | HPE | Servidor Torre |
| Storage NAS 4 baias | Synology | Storage |

---

#### Cliente de Exemplo (Computers)

Para todas as subcategorias do segmento Informática, usar:

| Campo | Valor |
|-------|-------|
| Nome | Ana Costa (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Av. Exemplo, 321 |

---

## 5. Appliances (appliances)

> Sem subcategorias

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Diagnóstico | 80.00 | Avaliação técnica do problema |
| Troca de resistência | 150.00 | Substituição de resistência |
| Troca de termostato | 120.00 | Substituição de termostato |
| Troca de timer | 180.00 | Substituição do timer mecânico |
| Troca de motor | 250.00 | Substituição do motor |
| Reparo de placa | 200.00 | Conserto de placa eletrônica |
| Recarga de gás (geladeira) | 300.00 | Recarga de gás refrigerante |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Resistência para chuveiro | 35.00 |
| Termostato universal | 65.00 |
| Timer mecânico | 120.00 |
| Capacitor para motor | 45.00 |
| Borracha de geladeira (metro) | 50.00 |
| Gás R134a (kg) | 100.00 |
| Mangueira de entrada | 30.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| Geladeira Frost Free 400L | Brastemp | Refrigerador |
| Máquina de Lavar 12kg | Electrolux | Lavadora |
| Micro-ondas 30L | Panasonic | Micro-ondas |

#### Cliente de Exemplo

| Campo | Valor |
|-------|-------|
| Nome | Carlos Ferreira (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Rua Exemplo, 654 |

---

## 6. Security (security)

O segmento Segurança Eletrônica possui **4 subcategorias** com dados de bootstrap distintos:

### 6.1 CFTV (cctv)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de câmera | 150.00 | Instalação de câmera com passagem de cabo |
| Instalação de DVR/NVR | 200.00 | Configuração de gravador digital |
| Configuração de acesso remoto | 100.00 | Setup de visualização pelo celular |
| Manutenção preventiva | 180.00 | Limpeza e verificação do sistema |
| Troca de HD do DVR | 150.00 | Substituição de disco de gravação |
| Instalação de cabo (metro) | 12.00 | Passagem de cabo coaxial/rede |
| Configuração de detecção | 80.00 | Setup de detecção de movimento |
| Reparo de câmera | 120.00 | Diagnóstico e reparo de câmera |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Câmera Bullet HD | 180.00 |
| Câmera Dome HD | 200.00 |
| Câmera IP 2MP | 280.00 |
| DVR 8 canais | 450.00 |
| NVR 8 canais | 550.00 |
| HD 1TB Surveillance | 350.00 |
| HD 2TB Surveillance | 480.00 |
| Cabo coaxial (rolo 100m) | 180.00 |
| Fonte 12V 5A | 45.00 |
| Conector BNC (pacote 10) | 25.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| DVR 8CH MHDX 1108 | Intelbras | DVR | canais: 8, armazenamento: 1TB |
| Câmera VHD 1120 B | Intelbras | Câmera | resolução: 720p, tipo: Bullet |

---

### 6.2 Alarmes (alarms)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de central | 250.00 | Instalação de central de alarme |
| Instalação de sensor | 80.00 | Instalação de sensor magnético/infra |
| Configuração de monitoramento | 150.00 | Setup com central de monitoramento |
| Manutenção preventiva | 120.00 | Teste e verificação do sistema |
| Troca de bateria | 100.00 | Substituição de bateria da central |
| Instalação de sirene | 80.00 | Instalação de sirene interna/externa |
| Configuração de app | 80.00 | Setup de controle pelo celular |
| Expansão de zonas | 150.00 | Adição de zonas na central |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Central de alarme 8 zonas | 350.00 |
| Central de alarme monitorada | 480.00 |
| Sensor infravermelho | 65.00 |
| Sensor magnético | 35.00 |
| Sensor de presença PET | 95.00 |
| Sirene 120dB | 85.00 |
| Controle remoto | 45.00 |
| Bateria 12V 7Ah | 90.00 |
| Teclado para central | 120.00 |
| Cabo de alarme 4 vias (100m) | 85.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Central AMT 2018 E | Intelbras | Central de Alarme | zonas: 18, monitorada: Sim |
| Sensor IVP 3000 | Intelbras | Sensor | tipo: Infravermelho, PET: Não |

---

### 6.3 Controle de Acesso (access)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de controle de acesso | 300.00 | Instalação completa de equipamento |
| Configuração de biometria | 150.00 | Cadastro de digitais |
| Instalação de fechadura | 200.00 | Instalação de fechadura eletrônica |
| Configuração de software | 180.00 | Setup de software de gestão |
| Instalação de catraca | 450.00 | Instalação de catraca de acesso |
| Manutenção preventiva | 150.00 | Verificação e ajustes do sistema |
| Cadastro de usuários | 80.00 | Cadastro em massa de usuários |
| Integração com CFTV | 200.00 | Integração com sistema de câmeras |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Controlador de acesso biométrico | 650.00 |
| Controlador de acesso facial | 1200.00 |
| Fechadura eletroímã | 280.00 |
| Fechadura elétrica | 150.00 |
| Leitor de cartão RFID | 180.00 |
| Cartão RFID (pacote 100) | 120.00 |
| Botão de saída | 35.00 |
| Fonte 12V 3A | 55.00 |
| Botoeira antipânico | 85.00 |
| Nobreak para controle de acesso | 350.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| SS 3430 BIO | Intelbras | Controle de Acesso | biometria: Sim, facial: Não |
| XPE 1001 FACE | Intelbras | Controle de Acesso | biometria: Sim, facial: Sim |

---

### 6.4 Cerca Elétrica (fence)

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Instalação de cerca (metro) | 45.00 | Instalação de fios e hastes |
| Instalação de central | 250.00 | Instalação de central de choque |
| Manutenção preventiva | 150.00 | Verificação de voltagem e isoladores |
| Reparo de cerca | 120.00 | Conserto de fios rompidos |
| Instalação de haste | 25.00 | Instalação de haste isoladora |
| Configuração de alarme | 100.00 | Integração com sistema de alarme |
| Troca de central | 200.00 | Substituição de central de choque |
| Regulagem de voltagem | 80.00 | Ajuste de tensão da cerca |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Central de cerca elétrica | 380.00 |
| Central com alarme integrado | 520.00 |
| Haste M 75cm (4 isoladores) | 35.00 |
| Haste M 100cm (6 isoladores) | 45.00 |
| Fio de aço inox (100m) | 65.00 |
| Fio de aço galvanizado (250m) | 85.00 |
| Isolador castanha (pacote 100) | 55.00 |
| Bateria 12V 7Ah | 90.00 |
| Sirene para cerca | 75.00 |
| Placa de advertência | 15.00 |

#### Equipamentos

| Nome | Fabricante | Categoria | Campos Personalizados |
|------|------------|-----------|----------------------|
| Central ELC 5002 | JFL | Cerca Elétrica | zonas: 2, alarme: Integrado |
| Central Shock Control | Genno | Cerca Elétrica | zonas: 1, alarme: Sim |

---

#### Cliente de Exemplo (Security)

Para todas as subcategorias do segmento Segurança, usar:

| Campo | Valor |
|-------|-------|
| Nome | Roberto Lima (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Rua Exemplo, 999 |

---

## 7. Other (other)

> Sem subcategorias - dados genéricos

#### Serviços

| Nome | Valor (R$) | Descrição |
|------|------------|-----------|
| Serviço básico | 100.00 | Serviço padrão |
| Serviço intermediário | 200.00 | Serviço de complexidade média |
| Serviço avançado | 350.00 | Serviço de alta complexidade |
| Diagnóstico | 80.00 | Avaliação técnica |
| Manutenção preventiva | 150.00 | Manutenção programada |

#### Produtos

| Nome | Valor (R$) |
|------|------------|
| Peça genérica A | 50.00 |
| Peça genérica B | 80.00 |
| Consumível padrão | 30.00 |
| Kit de reparo | 120.00 |

#### Equipamentos

| Nome | Fabricante | Categoria |
|------|------------|-----------|
| Equipamento Exemplo | Genérico | Geral |

#### Cliente de Exemplo

| Campo | Valor |
|-------|-------|
| Nome | Cliente Exemplo |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Endereço de Exemplo, 123 |

---

## Cliente de Exemplo (Automotivo)

Para todas as subcategorias do segmento automotivo, usar:

| Campo | Valor |
|-------|-------|
| Nome | João da Silva (Exemplo) |
| Telefone | (11) 99999-0000 |
| Email | exemplo@praticos.app |
| Endereço | Rua Exemplo, 123 |

---

## Estrutura JSON para Implementação

### Formato dos Dados

```typescript
interface BootstrapData {
  segment: string;
  subspecialty?: string;  // identificador da subcategoria
  services: ServiceSeed[];
  products: ProductSeed[];
  devices: DeviceSeed[];
  customer: CustomerSeed;
}

interface ServiceSeed {
  name: string;
  value: number;
  description?: string;
}

interface ProductSeed {
  name: string;
  value: number;
}

interface DeviceSeed {
  name: string;
  manufacturer: string;
  category: string;
  customFields?: Record<string, any>;
}

interface CustomerSeed {
  name: string;
  phone: string;
  email: string;
  address: string;
}
```

### Lógica de Bootstrap com Múltiplas Subcategorias

```typescript
function getBootstrapKeys(segment: string, subspecialties?: string[]): string[] {
  if (subspecialties && subspecialties.length > 0) {
    // Retorna uma chave para cada subcategoria selecionada
    return subspecialties.map(sub => `${segment}_${sub}`);
    // ex: ['automotive_mechanical', 'automotive_carwash']
  }
  return [segment];  // ex: ['hvac']
}

function mergeBootstrapData(keys: string[]): BootstrapData {
  const merged: BootstrapData = {
    segment: '',
    services: [],
    products: [],
    devices: [],
    customer: null,
  };

  const seenServices = new Set<string>();
  const seenProducts = new Set<string>();

  for (const key of keys) {
    const data = BOOTSTRAP_DATA[key];
    if (!data) continue;

    merged.segment = data.segment;

    // Merge services (evita duplicatas por nome)
    for (const service of data.services) {
      if (!seenServices.has(service.name)) {
        seenServices.add(service.name);
        merged.services.push(service);
      }
    }

    // Merge products (evita duplicatas por nome)
    for (const product of data.products) {
      if (!seenProducts.has(product.name)) {
        seenProducts.add(product.name);
        merged.products.push(product);
      }
    }

    // Merge devices (inclui todos)
    merged.devices.push(...data.devices);

    // Cliente: usa o primeiro encontrado
    if (!merged.customer && data.customer) {
      merged.customer = data.customer;
    }
  }

  return merged;
}
```

### Lógica de Prevenção de Duplicação

O bootstrap deve verificar se os dados já existem antes de criar, evitando duplicação em caso de re-execução:

```typescript
interface BootstrapResult {
  created: {
    services: string[];   // IDs criados
    products: string[];
    devices: string[];
    customers: string[];
  };
  skipped: {
    services: string[];   // Nomes pulados (já existiam)
    products: string[];
    devices: string[];
    customers: string[];
  };
}

async function executeBootstrap(
  companyId: string,
  data: BootstrapData
): Promise<BootstrapResult> {
  const result: BootstrapResult = {
    created: { services: [], products: [], devices: [], customers: [] },
    skipped: { services: [], products: [], devices: [], customers: [] },
  };

  // 1. Buscar itens existentes na empresa
  const existingServices = await getExistingNames(companyId, 'services');
  const existingProducts = await getExistingNames(companyId, 'products');
  const existingDevices = await getExistingNames(companyId, 'devices');
  const existingCustomers = await getExistingNames(companyId, 'customers');

  // 2. Criar apenas itens que não existem
  for (const service of data.services) {
    if (existingServices.has(service.name)) {
      result.skipped.services.push(service.name);
      continue;
    }
    const id = await createService(companyId, service);
    result.created.services.push(id);
  }

  for (const product of data.products) {
    if (existingProducts.has(product.name)) {
      result.skipped.products.push(product.name);
      continue;
    }
    const id = await createProduct(companyId, product);
    result.created.products.push(id);
  }

  for (const device of data.devices) {
    if (existingDevices.has(device.name)) {
      result.skipped.devices.push(device.name);
      continue;
    }
    const id = await createDevice(companyId, device);
    result.created.devices.push(id);
  }

  // Cliente: criar apenas se não existir nenhum com "(Exemplo)" no nome
  if (data.customer) {
    const hasExampleCustomer = [...existingCustomers].some(name =>
      name.includes('(Exemplo)')
    );
    if (!hasExampleCustomer) {
      const id = await createCustomer(companyId, data.customer);
      result.created.customers.push(id);
    } else {
      result.skipped.customers.push(data.customer.name);
    }
  }

  // 3. Salvar metadata do bootstrap
  await saveBootstrapMetadata(companyId, result);

  return result;
}

async function getExistingNames(
  companyId: string,
  collection: string
): Promise<Set<string>> {
  const snapshot = await db
    .collection('companies')
    .doc(companyId)
    .collection(collection)
    .get();

  return new Set(snapshot.docs.map(doc => doc.data().name));
}
```

### Mapeamento de Dados

```typescript
const BOOTSTRAP_DATA: Record<string, BootstrapData> = {
  // Automotivo com subcategorias
  'automotive_mechanical': { /* dados da oficina mecânica */ },
  'automotive_carwash': { /* dados do lava car */ },
  'automotive_painting': { /* dados de funilaria e pintura */ },
  'automotive_bodywork': { /* dados de lanternagem */ },

  // HVAC com subcategorias
  'hvac_residential': { /* dados HVAC residencial */ },
  'hvac_commercial': { /* dados HVAC comercial/industrial */ },
  'hvac_automotive_ac': { /* dados ar automotivo */ },

  // Informática com subcategorias
  'computers_desktop': { /* dados desktop/PC */ },
  'computers_notebook': { /* dados notebooks */ },
  'computers_networks': { /* dados redes */ },
  'computers_servers': { /* dados servidores */ },

  // Segurança com subcategorias
  'security_cctv': { /* dados CFTV */ },
  'security_alarms': { /* dados alarmes */ },
  'security_access': { /* dados controle de acesso */ },
  'security_fence': { /* dados cerca elétrica */ },

  // Segmentos sem subcategorias
  'smartphones': { /* dados de smartphones */ },
  'appliances': { /* dados de eletrodomésticos */ },
  'electrical': { /* dados de elétrica */ },
  'plumbing': { /* dados de hidráulica */ },
  'solar': { /* dados de energia solar */ },
  'printers': { /* dados de impressoras */ },
  'other': { /* dados genéricos */ },
};
```

### Exemplo de Bootstrap Combinado

Se empresa selecionar `mechanical` + `carwash`:

```typescript
// Entrada
segment: 'automotive'
subspecialties: ['mechanical', 'carwash']

// Resultado do merge
{
  services: [
    // Da mecânica
    { name: 'Troca de óleo', value: 80.00 },
    { name: 'Alinhamento', value: 120.00 },
    // ...
    // Do lava car
    { name: 'Lavagem simples', value: 40.00 },
    { name: 'Lavagem completa', value: 70.00 },
    // ...
  ],
  products: [
    // Da mecânica
    { name: 'Óleo 5W30 Sintético (1L)', value: 45.00 },
    // ...
    // Do lava car
    { name: 'Shampoo automotivo (5L)', value: 35.00 },
    // ...
  ],
  devices: [
    // Da mecânica
    { name: 'Onix 1.0', manufacturer: 'Chevrolet', ... },
    // Do lava car
    { name: 'Corolla XEi', manufacturer: 'Toyota', ... },
  ],
  customer: { name: 'João da Silva (Exemplo)', ... }
}
```

---

## Fluxo de Implementação

### Momento de Execução

O bootstrap é **opcional** e executado apenas se o usuário optar por criar dados de exemplo:

```
1. Usuário preenche dados da empresa (company_info_screen)
2. Usuário seleciona segmento (select_segment_screen)
3. [Se tem subspecialties] → Tela de seleção de subcategorias (múltipla escolha)
4. Tela de confirmação: "Deseja criar dados de exemplo?"
5. Empresa é criada no Firestore com segment + subspecialties[]
6. [Se optou por exemplos] → Bootstrap é executado
7. Usuário é direcionado ao dashboard
```

### Fluxo Detalhado com Decisão do Usuário

```
                    ┌─────────────────────┐
                    │ Criar dados de      │
                    │ exemplo?            │
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │ Sim                             │ Não
              ▼                                 ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│ 1. Criar empresa            │   │ 1. Criar empresa            │
│ 2. Executar bootstrap       │   │ 2. Redirecionar ao          │
│    - Verificar duplicatas   │   │    dashboard vazio          │
│    - Criar serviços         │   └─────────────────────────────┘
│    - Criar produtos         │
│    - Criar equipamentos     │
│    - Criar cliente exemplo  │
│ 3. Salvar metadata          │
│ 4. Redirecionar ao          │
│    dashboard                │
└─────────────────────────────┘
```

### Opções de Implementação

#### Opção A: Cloud Function (Recomendado)

```
Trigger: onCreate em /companies/{companyId}
Ação:
  1. Ler segment e subspecialty da company
  2. Buscar dados de bootstrap correspondentes
  3. Criar dados nas subcollections
```

**Vantagens:**
- Execução garantida e atômica
- Sem dependência do cliente
- Facilita auditoria e debugging

#### Opção B: Client-side (Fallback)

```
Local: CompanyStore.createCompany() ou onboarding flow
Ação: Após criar empresa, chamar método de bootstrap
```

**Vantagens:**
- Mais simples de implementar inicialmente
- Não requer deploy de Cloud Function

---

## Armazenamento dos Dados de Bootstrap

### Estrutura no Firestore

Os dados de exemplo ficam armazenados no Firestore, organizados por segmento e subcategoria:

```
/segments/{segmentId}/
├── (documento do segmento com subspecialties[])
└── bootstrap/
    ├── {subspecialtyId}/     # ex: mechanical, carwash
    │   ├── services: [...]
    │   ├── products: [...]
    │   ├── devices: [...]
    │   └── customer: {...}
    └── _default/             # Para segmentos sem subcategorias
        ├── services: [...]
        ├── products: [...]
        ├── devices: [...]
        └── customer: {...}
```

### Exemplo de Documento Bootstrap

**Path:** `/segments/automotive/bootstrap/mechanical`

```json
{
  "services": [
    { "name": "Troca de óleo", "value": 80.00, "description": "Troca de óleo do motor com filtro" },
    { "name": "Alinhamento", "value": 120.00, "description": "Alinhamento de direção computadorizado" },
    { "name": "Balanceamento", "value": 60.00, "description": "Balanceamento das 4 rodas" }
  ],
  "products": [
    { "name": "Óleo 5W30 Sintético (1L)", "value": 45.00 },
    { "name": "Filtro de óleo", "value": 35.00 },
    { "name": "Filtro de ar", "value": 55.00 }
  ],
  "devices": [
    { "name": "Onix 1.0", "manufacturer": "Chevrolet", "category": "Hatch", "customFields": { "year": 2022, "mileage": 45000, "color": "Prata" } },
    { "name": "HB20 1.6", "manufacturer": "Hyundai", "category": "Hatch", "customFields": { "year": 2021, "mileage": 38000, "color": "Branco" } }
  ],
  "customer": {
    "name": "João da Silva (Exemplo)",
    "phone": "(11) 99999-0000",
    "email": "exemplo@praticos.app",
    "address": "Rua Exemplo, 123"
  }
}
```

### Scripts de Seed

```
firebase/scripts/
├── seed_segments.js           # Segmentos + subspecialties + customFields
├── seed_bootstrap_data.js     # Dados de exemplo por segment/subspecialty
└── firebase-init.js           # Inicialização do Firebase Admin
```

---

## Alterações Necessárias no Código

### 1. Model Company (lib/models/company.dart)

```dart
@JsonSerializable(explicitToJson: true)
class Company extends BaseAudit {
  String? name;
  String? email;
  String? address;
  String? logo;
  String? phone;
  String? site;
  String? segment;             // ID do segmento: 'automotive', 'hvac', etc.
  List<String>? subspecialties; // IDs das subcategorias: ['mechanical', 'carwash']
  UserAggr? owner;
  List<UserRoleAggr>? users;
}
```

### 2. Atualizar seed_segments.js

Adicionar `subspecialties` aos segmentos que possuem subcategorias:

```javascript
// Segmentos COM subcategorias
{
  id: 'automotive',
  name: 'Automotivo',
  icon: '🚗',
  active: true,
  subspecialties: [
    { id: 'mechanical', name: 'Oficina Mecânica', icon: '🔧', description: 'Manutenção e reparo mecânico' },
    { id: 'carwash', name: 'Lava Car', icon: '🚿', description: 'Lavagem e limpeza de veículos' },
    { id: 'painting', name: 'Funilaria e Pintura', icon: '🎨', description: 'Pintura e reparos estéticos' },
    { id: 'bodywork', name: 'Lanternagem / Reparos', icon: '🛠️', description: 'Reparos de lataria e PDR' },
  ],
  customFields: [...]
},
{
  id: 'hvac',
  name: 'Ar Condicionado / Refrigeração',
  icon: '❄️',
  active: true,
  subspecialties: [
    { id: 'residential', name: 'Residencial', icon: '🏠', description: 'Split, janela, residências' },
    { id: 'commercial', name: 'Comercial/Industrial', icon: '🏢', description: 'VRF, chiller, câmaras frias' },
    { id: 'automotive_ac', name: 'Ar Automotivo', icon: '🚗', description: 'Ar condicionado veicular' },
  ],
  customFields: [...]
},
{
  id: 'computers',
  name: 'Informática',
  icon: '💻',
  active: true,
  subspecialties: [
    { id: 'desktop', name: 'Desktop/PC', icon: '🖥️', description: 'Montagem, upgrade, formatação' },
    { id: 'notebook', name: 'Notebooks', icon: '💻', description: 'Reparo de tela, teclado, bateria' },
    { id: 'networks', name: 'Redes', icon: '🌐', description: 'Cabeamento, switches, Wi-Fi' },
    { id: 'servers', name: 'Servidores', icon: '🖧', description: 'RAID, backup, virtualização' },
  ],
  customFields: [...]
},
{
  id: 'security',
  name: 'Segurança Eletrônica',
  icon: '📹',
  active: true,
  subspecialties: [
    { id: 'cctv', name: 'CFTV', icon: '📹', description: 'Câmeras, DVR/NVR, monitoramento' },
    { id: 'alarms', name: 'Alarmes', icon: '🚨', description: 'Sensores, centrais, monitoramento 24h' },
    { id: 'access', name: 'Controle de Acesso', icon: '🔐', description: 'Biometria, catracas, RFID' },
    { id: 'fence', name: 'Cerca Elétrica', icon: '⚡', description: 'Central de choque, hastes' },
  ],
  customFields: [...]
},

// Segmentos SEM subcategorias (usam _default no bootstrap)
{
  id: 'smartphones',
  name: 'Assistência Técnica - Celulares',
  icon: '📱',
  active: true,
  subspecialties: null,  // ou omitir o campo
  customFields: [...]
}
```

### 3. Criar seed_bootstrap_data.js (novo)

Script que popula `/segments/{segmentId}/bootstrap/{subspecialtyId}`:

```javascript
const BOOTSTRAP_DATA = {
  // AUTOMOTIVO
  automotive: {
    mechanical: {
      services: [...],
      products: [...],
      devices: [...],
      customer: {...}
    },
    carwash: { ... },
    painting: { ... },
    bodywork: { ... },
  },

  // HVAC
  hvac: {
    residential: { ... },
    commercial: { ... },
    automotive_ac: { ... },
  },

  // INFORMÁTICA
  computers: {
    desktop: { ... },
    notebook: { ... },
    networks: { ... },
    servers: { ... },
  },

  // SEGURANÇA
  security: {
    cctv: { ... },
    alarms: { ... },
    access: { ... },
    fence: { ... },
  },

  // SEGMENTOS SEM SUBCATEGORIAS (usam _default)
  smartphones: {
    _default: { ... }
  },
  appliances: {
    _default: { ... }
  },
  // ... outros
};

async function seedBootstrapData() {
  for (const [segmentId, subspecialties] of Object.entries(BOOTSTRAP_DATA)) {
    for (const [subspecialtyId, data] of Object.entries(subspecialties)) {
      const ref = db
        .collection('segments')
        .doc(segmentId)
        .collection('bootstrap')
        .doc(subspecialtyId);

      await ref.set(data);
      console.log(`✓ ${segmentId}/${subspecialtyId}`);
    }
  }
}
```

### 4. Tela de Seleção de Subcategorias (nova)

Criar `lib/screens/onboarding/select_subspecialties_screen.dart` que:
- Recebe o segmento selecionado
- Mostra lista de subspecialties com **checkboxes** (múltipla escolha)
- Requer pelo menos uma seleção
- Passa array de seleções para a próxima etapa

```dart
// Exemplo de estado
List<String> selectedSubspecialties = [];

// UI com CupertinoListTile + trailing checkbox
CupertinoListTile(
  title: Text(subspecialty['name']),
  leading: Text(subspecialty['icon']),
  trailing: selectedSubspecialties.contains(subspecialty['id'])
    ? Icon(CupertinoIcons.checkmark_circle_fill, color: CupertinoColors.activeBlue)
    : Icon(CupertinoIcons.circle),
  onTap: () => toggleSelection(subspecialty['id']),
)
```

### 5. Serviço de Bootstrap (novo)

Criar `lib/services/bootstrap_service.dart` que:
- Busca dados de bootstrap do Firestore
- Faz merge de múltiplas subcategorias
- Cria os dados na empresa (com verificação de duplicatas)

```dart
class BootstrapService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca dados de bootstrap para um segmento/subcategoria
  Future<Map<String, dynamic>?> getBootstrapData(
    String segmentId,
    String subspecialtyId,
  ) async {
    final doc = await _db
        .collection('segments')
        .doc(segmentId)
        .collection('bootstrap')
        .doc(subspecialtyId)
        .get();

    return doc.data();
  }

  /// Executa bootstrap para uma empresa
  Future<BootstrapResult> executeBootstrap({
    required String companyId,
    required String segmentId,
    required List<String> subspecialties,
  }) async {
    // 1. Buscar e fazer merge dos dados
    final mergedData = await _mergeBootstrapData(segmentId, subspecialties);

    // 2. Criar dados na empresa (com verificação de duplicatas)
    final result = await _createBootstrapEntities(companyId, mergedData);

    // 3. Salvar metadata
    await _saveMetadata(companyId, segmentId, subspecialties, result);

    return result;
  }
}
```

---

## Identificação de Dados de Exemplo

### Estratégia

1. **Sufixo no nome do cliente**: `"João da Silva (Exemplo)"`
2. **Documento de metadata**: `/companies/{companyId}/metadata/bootstrap`

```json
{
  "executedAt": "2025-01-11T10:00:00Z",
  "userOptedIn": true,
  "segment": "automotive",
  "subspecialties": ["mechanical", "carwash"],
  "created": {
    "services": ["id1", "id2", "id3"],
    "products": ["id4", "id5", "id6"],
    "devices": ["id7", "id8"],
    "customers": ["id9"]
  },
  "skipped": {
    "services": [],
    "products": ["Óleo 5W30 Sintético (1L)"],
    "devices": [],
    "customers": []
  }
}
```

### Campos do Metadata

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `executedAt` | DateTime | Data/hora da execução do bootstrap |
| `userOptedIn` | boolean | Se o usuário optou por criar dados de exemplo |
| `segment` | string | Segmento selecionado |
| `subspecialties` | string[] | Subcategorias selecionadas |
| `created.services` | string[] | IDs dos serviços criados |
| `created.products` | string[] | IDs dos produtos criados |
| `created.devices` | string[] | IDs dos equipamentos criados |
| `created.customers` | string[] | IDs dos clientes criados |
| `skipped.*` | string[] | Nomes dos itens pulados (já existiam) |

### Verificação de Duplicação

A duplicação é verificada **por nome** antes de criar cada item:

```dart
// Pseudocódigo Dart
Future<bool> shouldCreate(String companyId, String collection, String name) async {
  final existing = await FirebaseFirestore.instance
    .collection('companies')
    .doc(companyId)
    .collection(collection)
    .where('name', isEqualTo: name)
    .limit(1)
    .get();

  return existing.docs.isEmpty;
}
```

### Cenários de Re-execução

| Cenário | Comportamento |
|---------|---------------|
| Primeiro bootstrap | Cria todos os itens |
| Bootstrap após excluir alguns itens | Recria apenas os excluídos |
| Bootstrap com itens renomeados pelo usuário | Cria novos (nome diferente) |
| Bootstrap duplicado (sem alterações) | Não cria nada (todos pulados) |

### UI de Gestão

Banner no primeiro acesso:

```
┌────────────────────────────────────────────────────────┐
│ ℹ️  Criamos alguns dados de exemplo para você começar. │
│     Você pode editá-los ou excluí-los a qualquer       │
│     momento.                                           │
│                                                        │
│     [Manter exemplos]  [Excluir todos]                 │
└────────────────────────────────────────────────────────┘
```

---

## Próximos Passos

### Fase 1: Estrutura de Dados
1. [ ] Adicionar campo `subspecialties: List<String>?` ao model Company
2. [ ] Atualizar `seed_segments.js` com subspecialties para automotive, hvac, computers, security
3. [ ] Criar `seed_bootstrap_data.js` com dados de exemplo de todos os segmentos/subcategorias
4. [ ] Executar seeds no ambiente de desenvolvimento

### Fase 2: Fluxo de Onboarding
5. [ ] Criar tela de seleção de subcategorias (`select_subspecialties_screen.dart`)
6. [ ] Criar tela de confirmação de dados de exemplo (`confirm_bootstrap_screen.dart`)
7. [ ] Atualizar fluxo de onboarding para incluir novas telas

### Fase 3: Serviço de Bootstrap
8. [ ] Criar `BootstrapService` para buscar dados do Firestore e criar entidades
9. [ ] Implementar lógica de merge de múltiplas subcategorias
10. [ ] Implementar verificação de duplicatas por nome
11. [ ] Salvar metadata do bootstrap na empresa

### Fase 4: Finalização
12. [ ] Testar fluxo completo de onboarding
13. [ ] Implementar UI de gestão de dados de exemplo (opcional)
14. [ ] Documentar para usuários finais

---

## Histórico de Revisões

| Data | Versão | Descrição |
|------|--------|-----------|
| 2025-01-11 | 1.0 | Documento inicial |
| 2025-01-11 | 2.0 | Adicionado conceito de subspecialties para segmento automotivo |
| 2025-01-11 | 2.1 | Alterado subspecialty para subspecialties[] (array) - empresa pode ter múltiplas subcategorias |
| 2025-01-11 | 3.0 | Adicionadas subcategorias para HVAC (residential, commercial, automotive_ac), Computers (desktop, notebook, networks, servers) e Security (cctv, alarms, access, fence) |
| 2025-01-11 | 3.1 | Bootstrap opcional: usuário escolhe se deseja criar dados de exemplo. Adicionada lógica de prevenção de duplicação por nome |
| 2025-01-11 | 4.0 | Definida estrutura de armazenamento: dados de bootstrap no Firestore em `/segments/{id}/bootstrap/{subspecialtyId}`. Scripts separados: seed_segments.js + seed_bootstrap_data.js |
