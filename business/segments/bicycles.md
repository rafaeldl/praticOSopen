# Segmento: Bicicletaria (bicycles)

## Visão Geral

O segmento de bicicletarias atende oficinas especializadas em manutenção, reparo e customização de bicicletas. O Brasil possui aproximadamente 70 milhões de bicicletas em circulação, e o mercado de serviços mecânicos representa mais de 27% da receita das lojas de bicicleta.

É um segmento **workshop-based** (cliente leva a bicicleta à oficina), similar ao `automotive` e `smartphones`.

- **ID**: `bicycles`
- **Nome**: Bicicletaria
- **Icon**: 🚲
- **fieldService**: `false`

## Subespecialidades

| ID | Nome (pt) | Descrição |
|----|-----------|-----------|
| `general` | Oficina Geral | Manutenção e reparo de bicicletas em geral |
| `mtb` | MTB | Mountain bike, trilha e enduro |
| `road` | Speed / Road | Bicicletas de estrada e ciclismo de velocidade |
| `ebike` | E-bike | Bicicletas elétricas e assistidas |

## Campos Customizados do Dispositivo (Bicicleta)

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `device._entity` | label | "Bicicleta" |
| `device.serial` | text | Nº de Série (sem máscara) |
| `device.bikeType` | select | MTB, Speed/Road, Gravel, Urbana, BMX, Infantil, E-bike, Dobrável, Fixa |
| `device.wheelSize` | select | 12" a 29", 700c |
| `device.frameSize` | select | PP/XS, P/S, M, G/L, GG/XL |
| `device.frameMaterial` | select | Alumínio, Carbono, Aço, Cromo-Molibdênio |
| `device.gearCount` | select | Single Speed, 7v a 27v |
| `device.brakeType` | select | V-Brake, Disco Mecânico, Disco Hidráulico, Cantilever, Contra-Pedal |
| `device.suspensionType` | select | Rígida, Hardtail, Full Suspension |
| `device.color` | text | Cor da bicicleta |
| `device.year` | number | Ano (1980-2030) |
| `device.groupset` | text | Grupo / Câmbio (ex: Shimano Deore, SRAM GX) |
| `device.isElectric` | select | Sim / Não |

## Labels de Status Customizados

- **Em Conserto** (in_progress) — bike está sendo reparada
- **Pronta para Retirada** (completed) — bike finalizada, aguardando cliente

## Serviços Típicos

### Oficina Geral
- Revisão básica (R$120)
- Revisão completa (R$250)
- Troca de câmara de ar (R$30)
- Regulagem de câmbio (R$50)
- Regulagem de freio (R$40)
- Troca de pneu (R$25)
- Troca de corrente (R$35)
- Centrar roda / desempenar (R$45)

### MTB
- Revisão de suspensão dianteira (R$180)
- Revisão de suspensão traseira (R$200)
- Sangria de freio hidráulico (R$60)
- Troca de cassete (R$40)
- Troca de movimento central (R$70)
- Tubeless setup (R$80)

### Speed / Road
- Bike fit básico (R$200)
- Troca de fita de guidão (R$30)
- Troca de grupo completo (R$350)
- Regulagem de STI (R$50)
- Centrar roda speed (R$55)
- Revisão de pedal clip (R$40)

### E-bike
- Diagnóstico elétrico (R$100)
- Revisão completa e-bike (R$350)
- Troca de bateria (R$80 mão de obra)
- Atualização de firmware (R$60)
- Reparo de fiação (R$90)
- Regulagem de assistência (R$50)

## Produtos Típicos

- Câmara de ar (R$20-25)
- Pneu MTB 29" (R$90-120)
- Corrente (R$60-85)
- Pastilha de freio a disco (R$35-40)
- Cabos de câmbio/freio (R$12-15)
- Selante tubeless (R$45)
- Lubrificante de corrente (R$28)
- Bateria 36V para e-bike (R$850)

## Marcas Populares no Brasil

### Bicicletas
- **Caloi** — maior marca brasileira, linha completa
- **Sense** — MTB e Road de alta performance
- **Oggi** — MTB custo-benefício
- **Rava** — MTB e Road acessíveis
- **GTS** — entrada e intermediário
- **Specialized**, **Trek**, **Cannondale** — importadas premium

### Componentes
- **Shimano** — maior fabricante mundial (Tourney, Altus, Deore, SLX, XT, XTR, 105, Ultegra, Dura-Ace)
- **SRAM** — concorrente direta (NX, GX, X01, XX1, Rival, Force, Red)
- **Maxxis** — pneus premium
- **Continental** — pneus road
- **Absolute** — componentes nacionais custo-benefício

## Landing Page

- **PT**: `/segmentos/bicicletaria.html`
- **EN**: `/segmentos/bicicletaria-en.html`
- **ES**: `/segmentos/bicicletaria-es.html`

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `firebase/scripts/seed_segments.js` | Definição do segmento (customFields, subspecialties) |
| `firebase/scripts/bootstrap/bicycles.js` | Dados de bootstrap (serviços, produtos, dispositivos) |
| `firebase/hosting/src/_data/segments/bicicletaria.json` | Dados da landing page (pt/en/es) |
| `firebase/hosting/src/segmentos/bicicletaria*.njk` | Templates da landing page |
