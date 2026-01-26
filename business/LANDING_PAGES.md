# 🎯 Landing Pages por Segmento - PraticOS

**Data:** 2026-01-25  
**Objetivo:** Converter técnicos de cada segmento com mensagem personalizada

---

## Estrutura das URLs

```
praticos.web.app/
├── / (home genérica)
├── /precos
├── /segmentos/
│   ├── /refrigeracao
│   ├── /ar-condicionado
│   ├── /assistencia-celular
│   ├── /informatica
│   ├── /eletrica
│   ├── /energia-solar
│   ├── /seguranca-cftv
│   ├── /automacao
│   ├── /elevadores
│   ├── /dedetizacao
│   └── /limpeza
└── /blog/
```

---

## Template da Landing Page

Cada página segue a mesma estrutura, com conteúdo personalizado:

```
┌─────────────────────────────────────────┐
│ HEADER                                  │
│ Logo | Segmentos | Preços | Download    │
├─────────────────────────────────────────┤
│ HERO                                    │
│ "OS Digital para [Segmento]"            │
│ Subtítulo com dor principal             │
│ [Baixar Grátis] [Ver Demo]              │
│ Screenshot do app                       │
├─────────────────────────────────────────┤
│ PROBLEMAS (3 dores do segmento)         │
│ 🔴 Dor 1                                │
│ 🔴 Dor 2                                │
│ 🔴 Dor 3                                │
├─────────────────────────────────────────┤
│ SOLUÇÃO (como PraticOS resolve)         │
│ ✅ Benefício 1                          │
│ ✅ Benefício 2                          │
│ ✅ Benefício 3                          │
├─────────────────────────────────────────┤
│ FORMULÁRIO DO SEGMENTO                  │
│ "Checklist de [tipo] incluso grátis"    │
│ Preview do formulário                   │
├─────────────────────────────────────────┤
│ FUNCIONALIDADES                         │
│ OS Digital | Fotos | PDF | Financeiro   │
├─────────────────────────────────────────┤
│ DEPOIMENTO                              │
│ Foto + nome + empresa do segmento       │
│ "Quote do cliente"                      │
├─────────────────────────────────────────┤
│ PLANOS                                  │
│ Free | Starter | Pro | Business         │
│ Destaque: "Comece grátis"               │
├─────────────────────────────────────────┤
│ CTA FINAL                               │
│ "Comece agora - é grátis"               │
│ [App Store] [Google Play]               │
├─────────────────────────────────────────┤
│ FOOTER                                  │
│ Links | Contato | Redes                 │
└─────────────────────────────────────────┘
```

---

## Segmentos Detalhados

### 1. Refrigeração e Climatização

**URL:** `/segmentos/refrigeracao`

**Keywords:**
- app técnico refrigeração
- PMOC digital
- ordem de serviço refrigeração
- gestão assistência técnica refrigeração

**Hero:**
- Título: "OS Digital para Técnicos de Refrigeração"
- Subtítulo: "Chega de PMOC no papel. Gerencie suas ordens de serviço e impressione seus clientes."

**Dores:**
1. 🔴 "PMOC em papel dá trabalho e cliente perde"
2. 🔴 "Não lembra qual equipamento atendeu no mês passado"
3. 🔴 "Cliente liga toda hora perguntando status"

**Soluções:**
1. ✅ "PMOC digital com checklist pronto - só preencher"
2. ✅ "Histórico completo por equipamento e cliente"
3. ✅ "Link mágico: cliente acompanha a OS sozinho"

**Formulário incluso:**
- Checklist PMOC (manutenção preventiva)
- Checklist de instalação de split
- Diagnóstico de defeitos

**Equipamentos típicos:**
- Split, Multi-split, VRF
- Câmara fria, Geladeira comercial
- Ar-condicionado de janela

---

### 2. Ar-Condicionado (similar a refrigeração, foco residencial)

**URL:** `/segmentos/ar-condicionado`

**Keywords:**
- app instalador ar condicionado
- ordem de serviço ar condicionado
- PMOC ar condicionado
- app técnico ar condicionado

**Hero:**
- Título: "Gestão de OS para Instaladores de Ar-Condicionado"
- Subtítulo: "Organize suas instalações, manutenções e PMOCs em um só lugar."

**Dores:**
1. 🔴 "Faz instalação mas esquece de cobrar a manutenção"
2. 🔴 "Perde tempo fazendo orçamento na hora"
3. 🔴 "Não consegue provar o serviço que fez"

**Soluções:**
1. ✅ "Histórico do cliente lembra você de vender PMOC"
2. ✅ "Catálogo de serviços com preços - orçamento em 1 minuto"
3. ✅ "Fotos antes/depois + assinatura digital"

**Formulário incluso:**
- Checklist de instalação
- PMOC residencial
- Diagnóstico de problemas

---

### 3. Assistência Técnica de Celular

**URL:** `/segmentos/assistencia-celular`

**Keywords:**
- app assistência técnica celular
- sistema para loja de celular
- ordem de serviço celular
- controle de OS celular

**Hero:**
- Título: "Controle sua Assistência Técnica de Celular"
- Subtítulo: "Pare de anotar em papel. Saiba exatamente o status de cada aparelho."

**Dores:**
1. 🔴 "Cliente liga 5x por dia perguntando se ficou pronto"
2. 🔴 "Aparelhos misturados na bancada, não sabe de quem é"
3. 🔴 "Esquece de cobrar peças que usou"

**Soluções:**
1. ✅ "Link mágico: cliente acompanha status em tempo real"
2. ✅ "Vincula OS ao equipamento com foto e IMEI"
3. ✅ "Adiciona peças na OS e calcula total automático"

**Formulário incluso:**
- Checklist de recebimento (estado do aparelho)
- Diagnóstico de defeitos
- Termo de garantia

**Campos específicos:**
- IMEI, Modelo, Cor
- Senha do aparelho (campo sensível)
- Acessórios entregues

---

### 4. Informática e TI

**URL:** `/segmentos/informatica`

**Keywords:**
- app assistência técnica informática
- ordem de serviço informática
- gestão de chamados TI
- app técnico de computador

**Hero:**
- Título: "OS Digital para Técnicos de Informática"
- Subtítulo: "Gerencie chamados, formatações e manutenções sem complicação."

**Dores:**
1. 🔴 "Atende vários clientes e perde o controle"
2. 🔴 "Não documenta o que fez, cliente questiona depois"
3. 🔴 "Cobra por hora mas não registra tempo"

**Soluções:**
1. ✅ "Dashboard mostra todas as OS abertas"
2. ✅ "Timeline registra tudo que foi feito"
3. ✅ "Registra tempo e calcula valor automático"

**Formulário incluso:**
- Checklist de diagnóstico
- Checklist de formatação
- Entrega de equipamento

---

### 5. Elétrica

**URL:** `/segmentos/eletrica`

**Keywords:**
- app para eletricista
- ordem de serviço elétrica
- gestão de serviços elétricos
- app eletricista autônomo

**Hero:**
- Título: "Gestão de Serviços para Eletricistas"
- Subtítulo: "Organize seus orçamentos, serviços e cobranças de forma profissional."

**Dores:**
1. 🔴 "Faz orçamento de cabeça e esquece o que combinou"
2. 🔴 "Não tem registro do material que usou"
3. 🔴 "Cliente pede desconto e você não sabe seu custo real"

**Soluções:**
1. ✅ "Orçamento salvo vira OS com um clique"
2. ✅ "Registra materiais usados com quantidade e valor"
3. ✅ "Relatório mostra seu lucro real por serviço"

**Formulário incluso:**
- Checklist de vistoria elétrica
- Laudo de instalação
- Lista de materiais

---

### 6. Energia Solar

**URL:** `/segmentos/energia-solar`

**Keywords:**
- app instalador energia solar
- ordem de serviço energia solar
- gestão de instalações fotovoltaicas
- app técnico solar

**Hero:**
- Título: "OS Digital para Instaladores de Energia Solar"
- Subtítulo: "Documente instalações, faça vistorias e impressione seus clientes."

**Dores:**
1. 🔴 "Instalação complexa, precisa documentar tudo"
2. 🔴 "Cliente quer fotos do antes/depois"
3. 🔴 "Manutenções preventivas ficam esquecidas"

**Soluções:**
1. ✅ "Checklist completo de instalação fotovoltaica"
2. ✅ "Fotos ilimitadas organizadas por etapa"
3. ✅ "Agenda de manutenções com lembrete"

**Formulário incluso:**
- Checklist de instalação fotovoltaica
- Vistoria técnica
- Comissionamento do sistema

---

### 7. Segurança Eletrônica / CFTV

**URL:** `/segmentos/seguranca-cftv`

**Keywords:**
- app instalador CFTV
- ordem de serviço segurança eletrônica
- gestão de instalações CFTV
- app técnico alarme

**Hero:**
- Título: "Gestão de OS para Técnicos de CFTV e Alarme"
- Subtítulo: "Controle instalações, manutenções e visitas técnicas com facilidade."

**Dores:**
1. 🔴 "Muitos clientes com contratos de manutenção"
2. 🔴 "Não lembra a senha do DVR de cada cliente"
3. 🔴 "Precisa documentar posição das câmeras"

**Soluções:**
1. ✅ "Histórico completo por cliente e equipamento"
2. ✅ "Campos personalizados: IP, senha, portas"
3. ✅ "Fotos organizadas por câmera/posição"

**Formulário incluso:**
- Checklist de instalação CFTV
- Manutenção preventiva
- Configuração de acesso remoto

---

### 8. Automação Residencial

**URL:** `/segmentos/automacao`

**Keywords:**
- app instalador automação
- ordem de serviço automação residencial
- gestão de projetos automação
- app técnico automação

**Hero:**
- Título: "OS Digital para Integradores de Automação"
- Subtítulo: "Documente projetos complexos e gerencie múltiplos clientes."

**Dores:**
1. 🔴 "Projetos complexos com muitos equipamentos"
2. 🔴 "Cliente não lembra como usar o sistema"
3. 🔴 "Suporte pós-venda consome muito tempo"

**Soluções:**
1. ✅ "Cadastro detalhado de cada equipamento"
2. ✅ "PDF da OS serve como manual do cliente"
3. ✅ "Histórico de atendimentos por cliente"

**Formulário incluso:**
- Checklist de instalação
- Configuração de cenas/rotinas
- Entrega e treinamento

---

### 9. Elevadores

**URL:** `/segmentos/elevadores`

**Keywords:**
- app manutenção elevador
- ordem de serviço elevadores
- gestão de manutenção de elevadores
- PMOC elevador

**Hero:**
- Título: "Gestão de Manutenção de Elevadores"
- Subtítulo: "Controle preventivas, corretivas e atenda às normas com facilidade."

**Dores:**
1. 🔴 "Normas exigem documentação rigorosa"
2. 🔴 "Muitos prédios para gerenciar"
3. 🔴 "Síndico cobra relatórios"

**Soluções:**
1. ✅ "Checklist conforme normas técnicas"
2. ✅ "Dashboard por cliente/prédio"
3. ✅ "PDF profissional para o síndico"

**Formulário incluso:**
- Manutenção preventiva mensal
- Inspeção de segurança
- Relatório de ocorrências

---

### 10. Dedetização / Controle de Pragas

**URL:** `/segmentos/dedetizacao`

**Keywords:**
- app dedetizadora
- ordem de serviço dedetização
- gestão de controle de pragas
- app dedetizador

**Hero:**
- Título: "OS Digital para Dedetizadoras"
- Subtítulo: "Controle aplicações, produtos usados e vencimentos de forma simples."

**Dores:**
1. 🔴 "Controle de validade dos serviços"
2. 🔴 "Precisa documentar produtos aplicados"
3. 🔴 "Certificados e laudos exigidos"

**Soluções:**
1. ✅ "Alerta de vencimento de garantia"
2. ✅ "Registra produtos, dosagem e lote"
3. ✅ "PDF serve como certificado de aplicação"

**Formulário incluso:**
- Relatório de aplicação
- Mapa de iscas
- Certificado de dedetização

---

### 11. Limpeza e Facilities

**URL:** `/segmentos/limpeza`

**Keywords:**
- app empresa de limpeza
- ordem de serviço limpeza
- gestão de equipes de limpeza
- app facilities

**Hero:**
- Título: "Gestão de Equipes de Limpeza"
- Subtítulo: "Controle serviços, checklists e equipes externas com facilidade."

**Dores:**
1. 🔴 "Equipes em vários locais ao mesmo tempo"
2. 🔴 "Cliente questiona se serviço foi feito"
3. 🔴 "Difícil padronizar qualidade"

**Soluções:**
1. ✅ "Dashboard mostra todas as equipes"
2. ✅ "Fotos com data/hora comprovam execução"
3. ✅ "Checklist garante padrão de qualidade"

**Formulário incluso:**
- Checklist de limpeza por ambiente
- Vistoria de qualidade
- Controle de materiais

---

## Priorização de Segmentos

| Prioridade | Segmento | Justificativa |
|------------|----------|---------------|
| 🥇 1 | Refrigeração/AC | Maior mercado, formulário já existe |
| 🥇 1 | Assistência Celular | Alto volume, dor clara |
| 🥈 2 | Informática | Mercado grande, fácil de alcançar |
| 🥈 2 | Elétrica | Muitos autônomos |
| 🥈 2 | Energia Solar | Mercado crescente |
| 🥉 3 | CFTV/Segurança | Nicho específico |
| 🥉 3 | Automação | Nicho premium |
| 🥉 3 | Elevadores | Nicho regulado |
| 🥉 3 | Dedetização | Nicho específico |
| 🥉 3 | Limpeza | Mais B2B |

---

## Cronograma de Criação

| Fase | Landing Pages | Prazo |
|------|---------------|-------|
| MVP | Home genérica + Preços | Semana 1 |
| Fase 1 | Refrigeração + Celular | Semana 2 |
| Fase 2 | Informática + Elétrica + Solar | Semana 3-4 |
| Fase 3 | CFTV + Automação + Elevadores | Mês 2 |
| Fase 4 | Dedetização + Limpeza + outros | Mês 3 |

---

## Checklist por Landing Page

- [ ] URL criada
- [ ] Meta title otimizado (keyword + marca)
- [ ] Meta description com CTA
- [ ] H1 com keyword principal
- [ ] Conteúdo das dores
- [ ] Conteúdo das soluções
- [ ] Screenshot/mockup do formulário
- [ ] Depoimento do segmento (pode ser fictício inicialmente, trocar por real depois)
- [ ] CTAs com UTM do segmento
- [ ] Schema markup (LocalBusiness ou SoftwareApplication)
- [ ] Teste mobile
- [ ] PageSpeed > 90

---

## Próximos Passos

1. [ ] Aprovar lista de segmentos
2. [ ] Definir tecnologia do site (Flutter Web? Next.js? HTML simples?)
3. [ ] Criar template base reutilizável
4. [ ] Produzir landing Refrigeração (piloto)
5. [ ] Validar conversão e replicar
