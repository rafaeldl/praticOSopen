# Parceria com o Asaas

**Data:** 2026-10-04
**Contexto:** aposta A do [`DISCOVERY_AUTONOMIA.md`](DISCOVERY_AUTONOMIA.md): receber o pagamento da OS pelo link (Pix, boleto e cartão) e emitir NFS-e, com receita para o PraticOS.

---

## 1. O que o Asaas oferece

### 1.1 Programa de parceiros (comercial)
Fonte: [asaas.com/parceiros](https://materiais.asaas.com/parceiros)

| Modelo | Para quem | O que dá |
|--------|-----------|----------|
| **Tecnologia e Integrações** | Software houses, ERPs, CRMs | Nova linha de receita, apoio do time de vendas nas conversões, co-marketing, onboarding exclusivo |
| Distribuição | Contadores, agências, consultores | Landing de indicação, negociação personalizada para clientes |
| Asaas for Startups | Aceleradoras, fundos | Benefício para a rede |

- Requisitos: **CNPJ ativo, base ativa de clientes, estrutura comercial.**
- Cadastro gratuito; a remuneração "varia conforme modelo e volume" e só é detalhada no onboarding. **Os números da comissão só saem conversando com eles.**

### 1.2 Recursos técnicos (API)
Fonte: [docs.asaas.com](https://docs.asaas.com)

| Recurso | Para que serve no PraticOS |
|---------|----------------------------|
| **Subcontas** (`POST /v3/accounts`) | Cada empresa do PraticOS tem sua conta Asaas, criada a partir do app. Retorna `apiKey` e `walletId`. |
| **Split de pagamento** | Parte de cada cobrança recebida vai automaticamente para a carteira do PraticOS (`fixedValue` ou `percentualValue`, calculado sobre o valor líquido). Estorno desfaz o split. |
| **Cobrança** Pix, boleto e cartão + link de pagamento | Botão "cobrar" na OS e no link `/q/{token}`. |
| **NFS-e** | Nota fiscal de serviço emitida a partir da OS, agendada junto da cobrança. |
| **BaaS** (antigo White Label) | Toda a experiência dentro do PraticOS, sem o cliente ver o painel do Asaas. **Precisa ser alinhado com o gerente de contas.** |
| Webhooks | Status da cobrança e do split → atualiza o pagamento da OS automaticamente. |

### 1.3 Restrições importantes
- **Conta-pai precisa ser CNPJ** (Resoluções Conjuntas 16/17 do BC).
- **Período de avaliação regulatória** ao criar a primeira subconta em produção: até **10 subcontas**, **R$ 2.000 em cobranças por subconta**, até **60 dias**. A homologação pode ser pedida logo no início.
- Criação de subconta pode ter taxa (ver contrato).
- Confirmação anual de dados cadastrais das subcontas.

### 1.4 Taxas públicas do Asaas para o lojista
Fonte: [asaas.com/precos-e-taxas](https://www.asaas.com/precos-e-taxas) e [blog do Asaas](https://blog.asaas.com/taxas-asaas/). Valores sujeitos a mudança.

| Meio | Taxa |
|------|------|
| Pix | R$ 0,99 nos 3 primeiros meses, depois R$ 1,99 (há faixa de entradas gratuitas por mês) |
| Boleto | Só quando pago |
| Cartão | A partir de 1,99% + R$ 0,49 |
| NFS-e | R$ 0,49 por nota |

---

## 2. Modelos de parceria possíveis

| | **1. Indicação** | **2. Subcontas + split** | **3. BaaS** |
|---|---|---|---|
| Como funciona | O técnico abre a conta no Asaas pelo nosso link e conecta a chave de API no PraticOS | O PraticOS cria a conta Asaas do técnico pelo app; o técnico ativa por e-mail | Tudo dentro do PraticOS, marca PraticOS na frente |
| Receita do PraticOS | Comissão paga pelo Asaas | Split por cobrança + comissão do Asaas | Split + comissão; maior margem |
| Esforço técnico | Baixo | Médio | Alto (telas de conta, KYC, suporte) |
| Regulatório | Nenhum para nós | Período de avaliação e depois homologação | Alinhamento formal com o Asaas |
| Atrito para o técnico | Alto (sair do app, colar chave) | Médio (e-mail de ativação + documentos) | Baixo |
| Quando | Já | Piloto | Se o piloto provar uso |

---

## 3. Conta honesta: quanto isso rende

Base real hoje (ver discovery): 12 empresas de uso regular, ≈ R$ 56 mil/mês em OS, mais a empresa-âncora (≈ R$ 237 mil/mês).

Suposição: 40% do valor das OS passa a ser cobrado pelo link.

| Cenário | Valor cobrado pelo link/mês | Split de 1% |
|---------|-----------------------------|-------------|
| Só as 12 | ≈ R$ 22 mil | ≈ R$ 220/mês |
| 12 + âncora | ≈ R$ 117 mil | ≈ R$ 1.170/mês |
| 100 empresas no perfil das 12 | ≈ R$ 190 mil | ≈ R$ 1.900/mês |

**Leitura:** com a base atual, o split sozinho não paga a conta. O que muda o jogo é:
1. **Distribuição:** como parceiro de tecnologia, o PraticOS pode entrar na vitrine de integrações e no time de vendas do Asaas, que fala com centenas de milhares de PMEs. Isso ataca o problema real, que é ter poucos clientes ativos.
2. **Retenção:** quem recebe pelo app volta ao app. Cobrar e emitir nota na OS são motivos para usar todo dia.
3. **Comissão do Asaas** sobre o volume das contas indicadas, que soma ao split.

---

## 4. Recomendação

1. **Agora (sem código):** Rafael se inscreve no programa **Tecnologia e Integrações** e marca a conversa. Pauta na seção 5.
2. **Em paralelo (código, risco alto):** spike no **sandbox** com subconta + cobrança Pix com split + NFS-e + webhook atualizando a OS. Nada em produção.
3. **Piloto (modelo 2):** dentro do período de avaliação, com até 10 das empresas de uso real. O limite de R$ 2 mil por subconta serve para validar o fluxo, não o volume, então pedir a homologação logo no início.
4. **BaaS** só se o piloto mostrar que os técnicos cobram pelo app de forma recorrente.

## 5. Pauta para a conversa com o Asaas

- Comissão para parceiro de tecnologia: percentual sobre o volume (TPV) ou sobre a receita de taxas? Por quanto tempo?
- Taxas especiais para os clientes do PraticOS (Pix e cartão mais baratos que o público).
- Split: há limite ou regra para a plataforma ficar com um percentual de cada cobrança?
- Subcontas: custo de criação, prazo da homologação, e se o período de avaliação pode ser ajustado para o piloto.
- BaaS: condições, volume mínimo, obrigações de exposição da marca Asaas.
- Distribuição: listagem na vitrine de integrações, co-marketing, indicação pelo time de vendas.
- NFS-e: cobertura de municípios e quem configura os dados fiscais da subconta.

## 6. O que precisa do Rafael

- [ ] CNPJ do PraticOS para a conta-pai (existe um? qual?)
- [ ] Conta PJ no Asaas (produção) e acesso ao sandbox
- [ ] Inscrição no programa de parceiros e a conversa comercial
