# SEGMENT_SOFTWARE_IT.md

## Visão Geral

Ramo **"Software e TI"** (`segments/software_it`): suporte técnico, desenvolvimento de sistemas e mensalidades de TI. Quem é desse ramo emite nota de serviço todo mês para os mesmos clientes. Piloto: a Rafsoft. Decidido em 2026-11-05.

O que o ramo muda:

- **Nomes na OS**: o "equipamento" vira o **sistema** do cliente (ERP, site, app). Nada de aparelho, defeito ou veículo.
- **Exemplos**: serviços, licenças e sistemas de exemplo de TI ao criar a empresa com exemplos.
- **Termos para o cliente**: texto padrão com escopo, acessos, backup, licenças e mensalidade.
- **Atendimento remoto** por padrão (`fieldService: false`).
- **Site**: página `segmentos/software-ti` com a mensagem "nota fiscal de serviço todo mês, sozinha", atrás da chave `site.flags.softwareItPage` (desligada, ver Regras).

## Arquitetura

| Peça | Arquivo |
|---|---|
| Documento do ramo (`customFields`, `fieldService`) | `firebase/scripts/seed_segments.js` (`id: 'software_it'`) |
| Exemplos (sem especialidades: tudo em `_default`) | `firebase/scripts/bootstrap/software_it.js` |
| Termos padrão (pt, en, es) | `firebase/scripts/terms_data.js` (`software_it`) |
| Exemplos dos campos no app e no web (`serviceNameHint`, `productNameHint`, `orderCustomerRequestPlaceholder`, `checklistQuestionPlaceholder`) | `lib/l10n/app_*.arb`, chave `software_it` do `select` |
| Ícone do sistema | `lib/providers/segment_config_provider.dart` (`deviceIcon`) |
| Página do site | `firebase/hosting/src/_data/segments/software-ti.json`, `src/segmentos/software-ti*.njk`, fotos em `src/assets/images/site/segments{,-hero}/software-ti.webp` (IA, com "Imagem ilustrativa") |
| Testes | `test/services/segment_software_it_test.dart`, `firebase/functions/src/__tests__/segment-software-it.test.ts` |

O app e o web leem tudo do Firestore (`segments/{id}` e `segments/{id}/bootstrap/{sub}`); nenhuma lista de ramos no código precisa mudar. A tela "Seu ramo" mostra os ramos ativos em ordem de `name`.

### Nomes (`customFields`, tipo `label`)

| Chave | pt-BR | en-US | es-ES | Por quê |
|---|---|---|---|---|
| `device._entity` / `_plural` | Sistema / Sistemas | System / Systems | Sistema / Sistemas | O que a OS atende é o sistema do cliente. "Projeto" confunde com a OS de desenvolvimento |
| `actions.create_device` | Adicionar Sistema | Add System | Agregar Sistema | |
| `device.category` | Tipo | Type | Tipo | Sistema web, Site, Aplicativo |
| `device.brand` | Plataforma | Platform | Plataforma | WordPress, Laravel, Flutter |
| `device.model` | Versão | Version | Versión | |
| `device.serial` | Endereço | Address | Dirección | O endereço do sistema; aparece como "Endereço erp.cliente.com.br" |
| `product._entity`, `actions.create_product` | Licença, Adicionar Licença | License, Add License | Licencia, Agregar Licencia | Microsoft 365, antivírus, SSL, domínio |

`service_order._entity` continua "Ordem de Serviço": a nota fiscal e o resto do app falam de OS.

### Exemplos (`bootstrap/software_it.js`)

Serviços: Suporte técnico mensal, Desenvolvimento de sistema (hora), Manutenção de sistema mensal, Hospedagem mensal, Consultoria em TI (hora), Treinamento de usuários. Licenças: Microsoft 365 (mês), antivírus (ano), certificado SSL (ano), registro de domínio (ano). Sistemas: ERP, site institucional, app de pedidos. Valores são só exemplo, como nos outros ramos.

## Fluxo de Dados

```
seed_segments.js --only=software_it  →  segments/software_it
seed_bootstrap_data.js --only=software_it  →  segments/software_it/bootstrap/_default
Onboarding (app ou web): Seu ramo → Seu negócio → empresa com segment = 'software_it'
  → SegmentConfigService carrega global + software_it → labels na OS, no web e no PDF
  → "Criar meu PraticOS" copia os exemplos de _default
```

## Regras de Negócio

- O ramo **não liga nada sozinho**: `useContracts`, emissão de nota e código de serviço ficam com a empresa.
- Sugestões para depois (não implementadas):
  - **Contrato mensal ligado** no ramo (`useContracts: true` no documento do ramo e a empresa nova herdando), para o suporte mensal nascer como contrato. Hoje a empresa liga em Contratos.
  - **Código de serviço da nota** sugerido pelo serviço: 01.07.01 (suporte técnico em informática) para suporte, manutenção e hospedagem; 01.01.01 (análise e desenvolvimento de sistemas) para desenvolvimento; consultoria e treinamento dependem da cidade. Encaixa no emitente da NFS-e direta (`docs/NFSE_DIRECT.md`) e na emissão automática (#571).
  - Textos fixos que ainda falam de peça na OS ("Serviços e peças", "Buscar serviço ou peça"): não seguem o `product._entity` do ramo.
  - Checklist do ramo (ex.: "O backup rodou?", "Acessos trocados no fim?") em `seed_forms.js`.
- **Página do site desligada** (`site.flags.softwareItPage: false`): ela diz que a nota sai sozinha, o que só é verdade com a emissão automática (#571) e a NFS-e direta aberta a todos. Com a chave desligada a página não é gerada e o link não aparece no menu, no rodapé nem nas faixas de ramos. Para publicar: `true` em `firebase/hosting/src/_data/site.json`.
- Links de ramo atrás de chave: `"flag"` no item de `segments.json` e o filtro `enabledLinks` (`.eleventy.js`).

## Criar o ramo em produção (passo manual)

Os scripts escrevem no Firestore do projeto `praticos` e não mexem em empresa nenhuma. `--only` grava só este ramo:

```bash
cd firebase/scripts
node seed_segments.js caminho/service-account.json --only=software_it
node seed_bootstrap_data.js caminho/service-account.json --only=software_it
```

Não rode o `seed_segments.js` sem `--only`: ele regrava todos os ramos e o `segments/global` com `active: true`, o que põe "Global" na lista de ramos (visto no emulador).

Depois disso, "Software e TI" aparece em "Seu ramo" para quem criar empresa. Trocar o ramo da Rafsoft é pelo app (Sua empresa) ou à mão, por decisão do Rafael.

Teste local, no emulador (nunca sem `FIRESTORE_EMULATOR_HOST`, ou o script vai para produção):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 GCLOUD_PROJECT=demo-praticos node seed_segments.js --only=software_it
```
