# Pesquisa: Segmento de Obras Publicas / Prefeituras no Brasil

> **Documento para criacao de Landing Page - PraticOS**
> Pesquisa realizada em Marco/2026

---

## 1. Visao Geral do Mercado

### Tamanho e Numeros

| Indicador | Dados |
|-----------|-------|
| **Municipios no Brasil** | ~5.570 municipios (IBGE 2024) |
| **Investimento municipal em obras/ano** | R$ 80-120 bilhoes/ano (infraestrutura, pavimentacao, edificacoes) |
| **Transferencias do FPM** | R$ 160+ bilhoes/ano (Fundo de Participacao dos Municipios) |
| **Emendas parlamentares** | R$ 30-50 bilhoes/ano destinados a obras e infraestrutura municipal |
| **Convenios federais (transferencias voluntarias)** | R$ 20-40 bilhoes/ano via plataforma Transferegov |
| **Crescimento da demanda por digitalizacao** | Acelerado pos-pandemia e com vigencia da Nova Lei de Licitacoes (14.133/2021) |

### Contexto do Setor

O Brasil possui uma das maiores malhas municipais do mundo. A grande maioria dos municipios depende de transferencias federais e estaduais para executar obras de infraestrutura (pavimentacao, saneamento, edificacoes publicas, iluminacao, drenagem). A fiscalizacao dessas obras e historicamente manual, baseada em planilhas e relatorios em papel, com baixa rastreabilidade.

A **Nova Lei de Licitacoes (Lei 14.133/2021)**, em plena vigencia desde 2024, exige maior controle documental, designacao formal de fiscal, e registros sistematizados de medicoes e recebimentos. Isso gera uma demanda crescente por ferramentas digitais acessiveis.

### Distribuicao Geografica

- **Nordeste:** Maior concentracao de municipios pequenos dependentes do FPM (~1.794 municipios)
- **Sudeste:** Maior volume financeiro de obras, municipios mais digitalizados (~1.668 municipios)
- **Sul:** Municipios medios com boa capacidade tecnica (~1.191 municipios)
- **Norte:** Municipios isolados, logistica dificil, alta dependencia de convenios (~450 municipios)
- **Centro-Oeste:** Expansao urbana rapida, muitas obras de infraestrutura (~467 municipios)

---

## 2. Perfil das Prefeituras

### Segmentacao por Porte

| Porte | Populacao | Qtd Municipios | Caracteristicas |
|-------|-----------|----------------|-----------------|
| **Pequeno** | < 50 mil hab. | ~4.950 (~89%) | Equipe tecnica minima (1-3 engenheiros), sem TI propria, usam Excel/papel, orcamento limitado, alta dependencia de convenios |
| **Medio** | 50 mil - 500 mil hab. | ~530 (~9,5%) | Secretaria de obras estruturada (5-20 tecnicos), alguma digitalizacao, sistemas contabeis basicos, orcamento proprio relevante |
| **Grande** | > 500 mil hab. | ~50 (~1%) | Departamentos especializados, sistemas proprios ou contratados, equipes de TI, orcamento robusto, processos mais maduros |

### Estrutura Tipica (Prefeitura Pequena/Media)

- **Secretario de Obras** — Responsavel politico/administrativo
- **Engenheiro(a) fiscal** — Acompanha execucao das obras (muitas vezes 1 engenheiro para dezenas de contratos)
- **Fiscal de campo** — Tecnico que visita as obras e verifica medicoes
- **Setor de licitacoes/contratos** — Gerencia processos licitatorios e contratos
- **Controladoria/contabilidade** — Prestacao de contas ao TCE e portais de transparencia
- **Empresas contratadas** — Executam as obras (empreiteiras, construtoras)

### Modelo de Contratacao

**Fluxo tipico:**
```
Licitacao (PNCP/ComprasNet)
    -> Contrato
    -> Ordem de Servico
    -> Execucao (empresa contratada)
    -> Medicoes parciais (fiscal da prefeitura)
    -> Pagamento por medicao
    -> Recebimento provisorio
    -> Recebimento definitivo
```

**Tipos de obra mais comuns em municipios pequenos/medios:**
- Pavimentacao e recapeamento
- Construcao/reforma de escolas e UBS
- Drenagem e saneamento
- Iluminacao publica
- Pracas e espacos publicos
- Pontes e bueiros
- Reforma de predios publicos

---

## 3. Principais Dores do Setor

### Dores de Fiscalizacao

1. **Fiscalizacao por planilha Excel, sem padrao**
   - Fiscal preenche planilha manualmente apos visita
   - Sem fotos vinculadas a itens especificos da medicao
   - Historico se perde quando fiscal muda ou sai
   - Impossivel auditar o que foi verificado em campo

2. **Medicoes sem evidencia fotografica**
   - Empresa contratada envia medicao, fiscal aprova sem registro visual
   - TCE questiona e nao ha como comprovar
   - Fotos existem mas estao espalhadas em celulares pessoais
   - Sem geolocalizacao para provar que a foto e daquela obra

3. **Falta de rastreabilidade de contratos**
   - Contrato assinado fica na gaveta ou em pasta de rede
   - Ninguem sabe facilmente quanto ja foi medido vs. valor total
   - Aditivos sao feitos sem visao consolidada do historico

4. **Aditivos contratuais sem controle**
   - Aditivos de prazo e valor sem registro centralizado
   - Saldo contratual desatualizado
   - Risco de ultrapassar 25% sem perceber (limite legal)
   - TCE aponta irregularidades retroativamente

### Dores de Gestao e Comunicacao

5. **Comunicacao informal com empresas contratadas**
   - Ordens e autorizacoes por WhatsApp
   - Sem registro formal de solicitacoes e respostas
   - Empresa alega que nao recebeu instrucao
   - Prefeitura nao tem como provar comunicacao

6. **Dificuldade de acompanhar prazos contratuais**
   - Dezenas de contratos simultaneos com prazos diferentes
   - Sem alertas de vencimento
   - Obras paradas sem notificacao formal
   - Atrasos so percebidos quando TCE ou populacao cobra

7. **Prestacao de contas manual para TCE**
   - Relatorios compilados manualmente a cada medicao
   - Horas gastas montando documentacao
   - Risco de inconsistencia nos dados
   - Multa ao gestor por informacoes incompletas

### Dores de Transparencia

8. **Portais de transparencia deficientes**
   - LAI exige publicacao, mas informacoes sao genericas
   - Cidadao nao consegue ver status real de uma obra
   - Imprensa local cobra e nao ha dados atualizados
   - Risco politico e reputacional para o prefeito

---

## 4. Concorrentes

### Softwares Especificos para Gestao Publica

| Software | Tipo | Foco | Observacao |
|----------|------|------|------------|
| **Betha Sistemas** | SaaS | Contabilidade, RH, tributos municipais | Maior player de gestao publica municipal. Foco contabil/financeiro, nao gestao de obras em campo |
| **Coplan** | SaaS | Gestao de obras publicas | Focado em planejamento e controle de obras. Mais robusto, preco elevado para municipios pequenos |
| **e-Obras** | SaaS | Monitoramento de obras | Controle de evolucao fisica e financeira. Interface mais tecnica |
| **Obra Prima** | SaaS | Gestao de obras (mais privado) | Foco em construtoras privadas, mas usado por algumas prefeituras |
| **SIAI/TCE** | Sistemas obrigatorios | Prestacao de contas | Nao e gestao, e obrigacao legal. Cada estado tem o seu |

### Plataformas Governamentais (Obrigatorias)

| Plataforma | Orgao | Funcao |
|------------|-------|--------|
| **Transferegov** (ex-SICONV) | Gov Federal | Gestao de convenios e transferencias voluntarias |
| **PNCP** | Gov Federal | Portal Nacional de Contratacoes Publicas |
| **ComprasNet** | Gov Federal | Licitacoes eletronicas (sendo migrado para PNCP) |
| **SIAFIC** | Gov Federal | Sistema contabil obrigatorio |
| **Sistemas TCE** | Estadual | Prestacao de contas (cada estado tem o seu) |

### Concorrente Real

| "Ferramenta" | Uso estimado | Problema |
|--------------|--------------|----------|
| **Excel/Google Sheets** | ~70% dos municipios pequenos | Sem fotos, sem historico, sem rastreabilidade |
| **WhatsApp** | ~90% para comunicacao de obra | Informal, sem registro auditavel |
| **Papel/caderno de obra** | ~50% dos fiscais | Perde-se, deteriora, nao e pesquisavel |
| **Word (relatorios)** | ~60% para medicoes | Manual, inconsistente, sem padrao |

### Gap de Mercado
- **Betha/IPM** focam em contabilidade e RH, nao em gestao de obra em campo
- **Coplan/e-Obras** sao robustos mas caros e complexos para municipios pequenos
- **Transferegov** e obrigatorio para convenios mas nao gerencia execucao em campo
- **Nenhum** oferece app simples de fiscalizacao com fotos + checklist + dashboard financeiro a preco acessivel
- **Oportunidade:** Sistema mobile-first para fiscal de campo, com evidencia fotografica e controle financeiro de contratos

---

## 5. Comportamento de Busca e Keywords SEO

### Termos de Busca (Keywords SEO)

**Alta intencao comercial:**
```
sistema gestao obras prefeitura
software fiscalizacao obras publicas
app medicao de obras
sistema controle contratos licitacao
programa acompanhamento obras municipais
software diario de obras prefeitura
```

**Informacional/Educacional:**
```
como fiscalizar obras publicas
modelo medicao de obras
checklist fiscalizacao obras
nova lei licitacoes fiscalizacao
art 117 lei 14133 fiscal designado
como fazer diario de obra
```

**Problemas especificos:**
```
planilha controle obras prefeitura
modelo relatorio medicao obras
como prestar contas TCE obras
controle aditivos contratos publicos
como acompanhar prazo contrato obra
```

**Long tail (especificas):**
```
app para fiscal de obras prefeitura
sistema gestao obras prefeitura pequena
software medicao obras com fotos
aplicativo fiscalizacao obras publicas celular
como digitalizar fiscalizacao obras municipais
sistema barato gestao obras prefeitura
```

### Onde Pesquisam
1. **Google** — Principal fonte de busca
2. **YouTube** — Tutoriais sobre fiscalizacao e lei de licitacoes
3. **Transferegov/PNCP** — Obrigatorios, mas geram duvidas de como gerenciar a execucao
4. **WhatsApp** — Grupos de engenheiros e gestores municipais
5. **LinkedIn** — Engenheiros, secretarios de obras
6. **Eventos presenciais** — Marcha dos Prefeitos, congressos CNM, encontros TCE
7. **Fornecedores de contabilidade** — Betha, IPM indicam complementos

---

## 6. Comunidades e Associacoes

### Associacoes e Entidades

| Entidade | Abrangencia | Foco |
|----------|-------------|------|
| **CNM** - Confederacao Nacional de Municipios | Nacional | Representacao de municipios, capacitacao de gestores |
| **ABM** - Associacao Brasileira de Municipios | Nacional | Defesa de interesses municipais |
| **FNP** - Frente Nacional de Prefeitos | Nacional | Articulacao politica de municipios grandes |
| **TCEs** - Tribunais de Contas Estaduais | Estadual | Fiscalizacao de contas publicas, auditoria de obras |
| **CREA/CAU** - Conselhos de Engenharia e Arquitetura | Estadual | Regulacao profissional, ART/RRT |
| **IBAM** - Instituto Brasileiro de Administracao Municipal | Nacional | Capacitacao e consultoria para gestao municipal |

### Eventos do Setor

- **Marcha a Brasilia em Defesa dos Municipios** (CNM) — Maior evento municipal do Brasil (~5.000 prefeitos/ano)
- **Encontros estaduais de municipios** — Cada estado tem associacao propria (ex: AMUPE/PE, AMM/MG, FAMURS/RS)
- **Congressos TCE** — Capacitacao sobre prestacao de contas
- **Seminarios de Licitacoes** — Frequentes pos-Lei 14.133 (transicao)
- **ENAOP** - Encontro Nacional de Auditoria de Obras Publicas

### Grupos Online
- Grupos de WhatsApp de secretarios de obras
- Grupos de WhatsApp de engenheiros fiscais municipais
- Facebook: "Gestao Publica Municipal", "Engenharia de Obras Publicas"
- LinkedIn: profissionais de gestao publica e engenharia
- Foruns do TCE e portais de capacitacao (Escola de Contas)

---

## 7. Regulamentacao

### Legislacao Principal

| Lei/Norma | Descricao |
|-----------|-----------|
| **Lei 14.133/2021** | Nova Lei de Licitacoes e Contratos Administrativos — vigencia plena desde 30/12/2023 |
| **Lei 8.666/1993** | Antiga Lei de Licitacoes — ainda vigente para contratos assinados antes de 30/12/2023 |
| **Lei 4.320/1964** | Normas de direito financeiro para orcamentos publicos |
| **LC 101/2000 (LRF)** | Lei de Responsabilidade Fiscal — limites de gastos e endividamento |
| **Lei 12.527/2011 (LAI)** | Lei de Acesso a Informacao — transparencia obrigatoria |
| **SIAFIC** | Sistema Integrado de Administracao Financeira e Controle (obrigatorio desde 2023) |

### Artigos-Chave da Lei 14.133/2021

| Artigo | Disposicao |
|--------|------------|
| **Art. 7** | Agente de contratacao e equipe de apoio |
| **Art. 8** | Comissao de contratacao |
| **Art. 117** | **Fiscal designado obrigatoriamente** — a Administracao deve designar agente publico para fiscalizar a execucao do contrato |
| **Art. 118** | Diario de obra para contratos de obras e servicos de engenharia |
| **Art. 119** | Medicoes devem ser registradas para pagamento |
| **Art. 125** | Aditivos limitados a 25% do valor inicial (50% para reforma) |
| **Art. 140** | **Recebimento provisorio e definitivo** — exige relatorio circunstanciado com fotos e verificacao |

### Exigencias do TCE

- Prestacao de contas periodica de convenios e obras
- Documentacao de medicoes com memorial descritivo
- Comprovacao de execucao fisica (fotos, relatorios)
- Registro de aditivos e justificativas
- Diario de obra atualizado
- **Penalidades:** Multa ao gestor, rejeicao de contas, inelegibilidade (Lei Ficha Limpa)

### Portais de Transparencia

- Obrigatoria publicacao de contratos, aditivos e pagamentos (LAI)
- Municipios > 10 mil hab: portal eletronico obrigatorio
- Informacoes devem ser atualizadas e acessiveis ao cidadao
- Ranking de transparencia (CGU) influencia reputacao do municipio

---

## 8. Proposta de Valor do PraticOS

### Publico-Alvo Principal

- **Prefeituras de pequeno porte** (<50 mil hab.) que usam Excel/papel para fiscalizar obras
- **Prefeituras de medio porte** que buscam digitalizar a fiscalizacao
- **Engenheiros e tecnicos fiscais** que precisam de ferramenta mobile em campo
- **Secretarios de obras** que precisam de visao consolidada de contratos
- **Empresas contratadas** que podem usar o sistema para reportar execucao

### Proposta de Valor Sugerida

> "Fiscalize obras publicas com evidencia digital: registre medicoes com fotos geolocalizadas, controle contratos e aditivos, e gere relatorios prontos para o TCE — tudo pelo celular."

### Funcionalidades que Resolvem Dores

| Dor | Funcionalidade PraticOS |
|-----|------------------------|
| Fiscalizacao por planilha | OS digital por contrato/obra com checklist de vistoria |
| Medicoes sem evidencia | Fotos geolocalizadas vinculadas a cada medicao |
| Sem rastreabilidade de contratos | Dashboard financeiro (valor contratado vs medido vs pago) |
| Aditivos sem controle | Registro de aditivos com saldo atualizado automaticamente |
| Comunicacao informal | Colaboradores externos (empresa contratada acessa apenas seus contratos) |
| Prazos sem controle | Alertas de vencimento de contrato e prazos |
| Prestacao de contas manual | Relatorios PDF automaticos com fotos e historico |
| Portal de transparencia deficiente | Link de acompanhamento compartilhavel por obra |

### Diferenciais a Destacar

1. **Mobile-first para fiscal de campo** — App no celular do fiscal, funciona offline
2. **Fotos geolocalizadas como evidencia** — Prova de execucao para TCE
3. **Formularios dinamicos** — Checklists personalizaveis por tipo de obra (pavimentacao, edificacao, saneamento)
4. **Multi-tenant nativo** — Prefeitura = tenant, cada secretaria ou contrato isolado
5. **Colaboradores externos** — Empresa contratada ve apenas seus contratos
6. **Dashboard financeiro** — Valor contratado vs liberado vs medido vs pago
7. **Custo acessivel** — Fracao do custo de Coplan/e-Obras, viavel para municipios pequenos
8. **Simples de usar** — Curva de aprendizado minima vs. sistemas complexos de gestao publica

### Mapeamento de Conceitos (PraticOS -> Obras Publicas)

| Conceito PraticOS | Equivalente em Obras Publicas |
|-------------------|-------------------------------|
| Cliente | Obra / Contrato |
| Ordem de Servico | Medicao / Vistoria / Diario de obra |
| Dispositivo | Tipo de obra (pavimentacao, edificacao, etc.) |
| Servicos | Itens da planilha orcamentaria |
| Formularios dinamicos | Checklist de fiscalizacao / Laudo de vistoria |
| Fotos | Evidencia fotografica de execucao |
| Colaborador externo | Empresa contratada / Empreiteira |
| Dashboard financeiro | Controle orcamentario do contrato |
| Link de acompanhamento | Transparencia publica da obra |

### Call-to-Actions Sugeridos

- "Digitalize a fiscalizacao de obras da sua prefeitura"
- "Teste gratis por 14 dias"
- "Saia da planilha, tenha evidencia no celular"
- "Agende uma demonstracao para sua secretaria de obras"
- "Pronto para o TCE — relatorios com fotos em 1 clique"

### Modelo de Precificacao Sugerido

| Faixa | Perfil | Justificativa |
|-------|--------|---------------|
| **Gratuito/Trial** | Prefeitura pequena testando | Baixa barreira de entrada |
| **Basico** | Ate 10 contratos ativos | Municipio pequeno com poucas obras |
| **Profissional** | Ate 50 contratos ativos | Municipio medio |
| **Enterprise** | Ilimitado + integracao | Municipio grande ou consorcio |

**Nota:** Prefeituras compram via licitacao (dispensa ate R$ 59.906,02 para servicos — Art. 75, IV da Lei 14.133). SaaS mensal pode se enquadrar em dispensa de licitacao.

---

## 9. Fontes da Pesquisa

- CNM - Confederacao Nacional de Municipios (cnm.org.br)
- ABM - Associacao Brasileira de Municipios (abm.org.br)
- FNP - Frente Nacional de Prefeitos (fnp.org.br)
- IBGE - Instituto Brasileiro de Geografia e Estatistica (ibge.gov.br)
- Transferegov - Plataforma de transferencias (transferegov.sistema.gov.br)
- PNCP - Portal Nacional de Contratacoes Publicas (pncp.gov.br)
- STN - Secretaria do Tesouro Nacional — dados de transferencias (tesouro.fazenda.gov.br)
- Betha Sistemas (betha.com.br)
- Coplan (coplan.com.br)
- e-Obras (e-obras.com)
- Lei 14.133/2021 — Nova Lei de Licitacoes e Contratos
- Lei 8.666/1993 — Antiga Lei de Licitacoes
- Lei 12.527/2011 — Lei de Acesso a Informacao
- LC 101/2000 — Lei de Responsabilidade Fiscal

---

*Documento preparado para criacao de landing page do PraticOS*
*Segmento: Obras Publicas / Prefeituras (Fiscalizacao, Medicoes e Controle de Contratos)*
