# Parcerias: Asaas, ERPs e meios de pagamento

**Data:** 2026-10-04
**Contexto:** canais e parceiros para monetização. Aposta A do [`DISCOVERY_AUTONOMIA.md`](DISCOVERY_AUTONOMIA.md): receber o pagamento da OS pelo link (Pix, boleto e cartão) e emitir NFS-e, com receita para o PraticOS.

---

## 0. Flapp Store do Asaas (achado mais importante — 2026-10-04)

Fontes: [materiais.asaas.com/flappstore](https://materiais.asaas.com/flappstore), [docs.asaas.com/docs/flappstore](https://docs.asaas.com/docs/flappstore), [lançamento](https://blog.asaas.com/release/flapp-store/).

**O que é:** loja de aplicativos dentro da conta Asaas. A empresa descobre, contrata e gerencia "Flapps" (apps parceiros homologados) sem sair do Asaas. Base: **~270 mil empresas**.

**Como funciona para o cliente:**
- Contrata o plano dentro da conta Asaas; **o valor é debitado do saldo da conta Asaas**, com recorrência.
- Na contratação, autoriza **permissões** para o app usar a conta: consultar clientes, consultar/criar cobranças, consultar pagamentos, consultar dados da conta.
- Upgrade, downgrade, trial e cancelamento ficam em "Meus Flapps". Suporte de cobrança é do Asaas; suporte de uso é do parceiro.

**Requisitos para ser parceiro:** usar o Asaas no fluxo de pagamento, modelo self-service/PLG, integração via API do Asaas, **cobrança recorrente**, boa reputação pública e **aderência ao mobile**.

**Por que encaixa no PraticOS:**

| Problema nosso | Como a Flapp Store resolve |
|---|---|
| Poucos clientes ativos | Vitrine para 270 mil empresas, a maioria PME sem ERP — o mesmo perfil da nossa base |
| Não temos como cobrar (IAP bloqueado no iOS, nada no Android) | O Asaas cobra o plano do saldo do cliente e repassa |
| Técnico teria que colar chave de API do Asaas | As permissões da contratação dão acesso à conta do cliente, sem chave manual |
| Cobrança da OS e baixa automática | A permissão "criar cobranças/consultar pagamentos" é exatamente o que a #303 precisa |

Nos exemplos públicos (contratos, atendimento, vendas) **não aparece app de ordem de serviço** — a categoria parece livre. A confirmar.

**Pontos em aberto (perguntar ao Asaas):**
- Percentual que o Asaas retém do plano e prazo de repasse.
- Processo e prazo de homologação; como funciona a autorização técnica (OAuth/escopos) para o app.
- Se já existe ou está entrando algum app de OS.
- Regras de trial e de preço.

**Risco Apple:** se o plano comprado na Flapp Store libera recursos no app iOS, a Apple pode aplicar a mesma guideline 3.1.1 que causou as rejeições (recurso pago sem IAP). Avaliar antes de ligar recursos pagos no iOS; os recursos ligados à cobrança de serviço físico (cobrar o cliente da OS) tendem a estar fora do IAP.

**Nova recomendação:** a Flapp Store substitui os modelos 1–3 abaixo como caminho principal. Ela junta distribuição, cobrança do nosso plano e integração com a conta do técnico numa coisa só. A conversa com o Asaas passa a ser sobre entrar na Flapp Store.

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

---

## 7. Outros parceiros possíveis

Pesquisa de 2026-10-04. O ponto principal não é integração técnica, é **canal de distribuição**: estar na loja de apps de quem já atende a PME prestadora de serviço.

### 7.1 ERPs com loja de aplicativos

| Parceiro | O que oferecem | Como o parceiro ganha | Status | Encaixe com o PraticOS |
|----------|----------------|-----------------------|--------|------------------------|
| **Omie** ([Omie.Store](https://www.omie.com.br/funcionalidades/loja-de-aplicativos/)) | Loja com 90+ apps dentro do painel do cliente; parceiro certificado. API com endpoints de OS e NFS-e. | **A Omie cobra a mensalidade do app junto com a dela e repassa ao parceiro, retendo um percentual** ([termos](https://5257088.fs1.hubspotusercontent-na1.net/hubfs/5257088/arquivos-omie-store/Termos_e_Condicoes/Termos_de_uso_e_condicoes_gerais_OmieStore_Jan26.pdf)). | Aberto | **Alto.** Base forte de prestadores de serviço. Resolve a cobrança: o cliente paga pela fatura da Omie, sem IAP e sem nós montarmos billing. |
| **Bling** ([Central de Extensões](https://www.bling.com.br/api-e-aplicativos)) | App store exposta à base inteira do Bling; API REST v3 com OAuth. | Só apps **homologados** aparecem na loja, não têm limite de usuários e **podem ser monetizados e gerar comissão** ([homologação](https://ajuda.bling.com.br/hc/pt-br/articles/35518268781719-Como-realizar-a-homologa%C3%A7%C3%A3o-de-aplicativos-p%C3%BAblicos-no-Bling)). | Aberto | **Médio.** Base mais de comércio/e-commerce, mas grande. Homologação exige a integração pronta. |
| **Conta Azul** | Marketplace e canal "Conecta" para parceiros. | — | **Fechado por ora:** informam que não estão desenvolvendo parcerias com novas plataformas para aparecer no ERP ([fonte](https://contaazul.com/desenvolvedores/)). Contato: integracoes@contaazul.com. | Baixo agora. |
| Tiny (Olist), vhsys | APIs públicas. | — | — | Baixo: foco em e-commerce / API limitada. |

### 7.2 Meios de pagamento (alternativas ou complementos ao Asaas)

| Parceiro | Observação |
|----------|------------|
| **InfinitePay** (CloudWalk) | Checkout e link de pagamento via API com webhook ([docs](https://docs.infinitepay.io)). Muito usado por autônomos. **Atenção: lançou um gerador de Ordem de Serviço gratuito** ([fonte](https://www.infinitepay.io/blog/ordem-de-servico)) e agendamentos. É mais concorrente do que parceiro. |
| Mercado Pago, PagBank, Efí | Têm API de cobrança e split de marketplace. Úteis como alternativa se as condições do Asaas não forem boas. Não investigado a fundo. |

### 7.3 Canal de contadores
Contadores atendem MEIs e oficinas e indicam ferramentas. O próprio Asaas tem um modelo "Distribuição" para contadores. Possível canal depois que a cobrança + NFS-e existir (o contador ganha com a nota emitida certa).

### 7.4 Recomendação de ordem

1. **Asaas** — cobrança, split e NFS-e (seções 1–6). É a base de receita e o que dá valor fiscal/financeiro à OS.
2. **Omie.Store** — canal de distribuição **com billing pronto**. Integração mínima: sincronizar clientes e mandar a OS concluída para o financeiro/NFS-e da Omie. Primeiro passo: conversa com o time de parceiros para saber percentual retido e requisitos de certificação.
3. **Bling** — depois da Omie, reaproveitando a mesma camada de integração.
4. Contadores — quando houver cobrança + NFS-e funcionando.

**Cuidado:** cada integração com ERP é manutenção contínua (APIs mudam, homologação, suporte). Com a base atual, fazer **uma de cada vez** e medir quantos clientes cada canal traz antes da próxima.

Retomada da issue #198 (ERPs como canal de aquisição), fechada na triagem de 2026-10-04.
