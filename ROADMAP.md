# Roadmap PraticOS

> Fonte única de prioridade. Agentes e humanos trabalham a partir daqui.
> Contexto e racional: [`business/DISCOVERY_AUTONOMIA.md`](business/DISCOVERY_AUTONOMIA.md).
> Plano do trimestre: [`business/PLANO_CRESCIMENTO_2026Q4.md`](business/PLANO_CRESCIMENTO_2026Q4.md).
> Atualizado: 2026-11-07

**Métrica norte:** empresas ativas por semana (≥1 OS nos últimos 7 dias). Base em 2026-10-04: **27** (13 com uso recorrente/regular; 1 delas é a âncora da família).
**Direção do trimestre:** gerar a primeira receita recorrente.

> **Atenção:** as lojas estão na 1.56.0. Tudo do app feito depois dela (redesign, IA na OS, uso do plano, banner da cortesia, próxima manutenção, checklist novo) só existe nas RCs 1.88+. Converter a cortesia depende de lançar essa versão.

---

## Agora (máx. 3)

1. **Converter a cortesia do Pro (fim em 07/12)**
   - Lançar nas lojas a versão com o redesign (hoje só em RC).
   - Implementar os planos aprovados em 02/11: 10 OS no Free, OS e IA incluídas nos pagos, 2/5/20 pessoas, preços mantidos e anual pagando 10 meses. Depois, a página de preços no site.
   - #344 uso do plano e paywall: quase pronta, falta abrir o paywall já no plano sugerido.
   - #342 IA na OS: falta a leitura da etiqueta do ar-condicionado e o conjunto de casos de teste.
   - #96 plano anual nas lojas (manual).
   - Pronto: #343 avisos de 15 e 3 dias (push no ar, 1º envio em 22/11).
2. **NFS-e direta no governo** (épico #559). Servidor e app web prontos; Piloto 1 emitiu nota real em 06/11.
   - #570 pedir o certificado ao contador · #560 revisão de segurança por alguém de fora · #573 Piloto 2.
   - #574 nota fiscal por plano (Free sem, Starter 1 CNPJ, Pro 2, Business ilimitado).
   - #572 artigo público · #606 vários serviços na nota · #576 tirar a nota pelo Asaas · #470 mandar notas ao contador/cliente.
3. **Link do cliente seguro e útil**
   - #373 privacidade da API pública: PR #647 aguardando revisão.
   - Em seguida: #371 link vencido, #376 link vale enquanto a OS estiver aberta, #368 prévia no WhatsApp, #370 botão "Falar", #369 medição.

## Próximo

- **Climatização como segmento de entrada:** #347 pergunta sobre contrato/PMOC, #349 relatório em PDF, #352 páginas nas lojas. Parciais: #348 checklist (faltam medições e fotos antes/depois), #351 landing, #110 recorrência (job de contratos desligado).
- **Ativação e aquisição medidas:** #299 funil, #345 rodapé com origem do cadastro, #346 1ª OS (saiu por voz, falta foto e evento), #353 ads otimizando a 1ª OS.
- **Checklists mais práticos** (#382): #384 medir uso, #387 modelo por ramo, #388 sugestão na OS, #389 sincronizar sem sobrescrever (só no servidor), #390 falar as respostas, #646.
- **Asaas: ligar o piloto da cobrança** (#645). Código pronto; fora da tabela de planos por enquanto.
- **Decisões de produto do teste de usuário** (#492, itens 4 a 9).
- **QR no equipamento** (#109).
- **Experimento en-US/es-MX nas lojas** (#354), depois do lançamento.

## Depois

- Animações e háptico (#378–#381, #383).
- Link do cliente fase 2 (#372, #374, #375, #377).
- Afiliados pela Hotmart (#350), travado na Hotmart.
- Parceria com ERP sem app de OS (#198), conversa comercial.
- MCP fases 2–4 (OAuth, diretórios do ChatGPT/Claude, RBAC) — #267.
- Segurança fase 2 dos vínculos (#309).
- Relatórios exportáveis (#108), multi-empresa no Business (#104), fotos por aparelho (#180), endereço com GPS (#174), WhatsApp direto na OS (#200), importar vários contatos (#483).
- Oportunidades / marketplace de leads.
- Assistente no WhatsApp como add-on pago (só com ≥5 interessados).

## Feito

- 2026-11-07: tela Equipe do app web voltou a funcionar (#650).
- 2026-11-06: Piloto 1 da NFS-e direta emitiu nota real pelo app web.
- 2026-11-05: domínio praticos.app como principal; ramo Software e TI.
- 2026-11-04: app web (`praticos.app/web`) construído, acesso restrito por enquanto (substitui o portal #192).
- 2026-11-03: IA financeira na OS (fase 1, desligada por chave); próxima manutenção por aparelho (#505).
- 2026-11-02: site no tema Campo; tabela de planos nova aprovada (falta implementar).
- 2026-10-31: preparação de IA e cobrança para o lançamento (#469): uso do plano, avisos da cortesia; lista de notas fiscais (#471).
- 2026-10-17: IA ligada para todos em produção.
- 2026-10-05: cobrança da OS pelo Asaas, blocos A–F (#303).
- 2026-10-10: planos pagos no ar (Starter, Pro, Business via RevenueCat); plano de crescimento do 4º tri decidido.
- 2026-10-04: bot do WhatsApp desligado (VM e disco apagados; conversas em `gs://praticos-bot-archive`). Google Ads pausado.

## Fora (decidido não fazer agora)

- Bot do WhatsApp gratuito — custo de VM + LLM sem receita.
- Limite de fotos como gatilho de upgrade (planos novos: fotos sem limite).
- Landing de pré-venda (#300): a disposição a pagar é medida no paywall real.
- Programa de afiliados próprio: usar a Hotmart.
- Vender fora do Brasil antes do experimento nas lojas.
- Usuário extra pago e pacote de IA avulso, por enquanto.
