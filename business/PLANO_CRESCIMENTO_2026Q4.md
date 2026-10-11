# Plano de crescimento — 4º tri de 2026

> Decidido em 2026-10-10. Prioridade operacional fica no [`ROADMAP.md`](../ROADMAP.md); aqui fica o porquê.
> O estudo completo cita uso de produção e fica fora do repositório. Aqui só entram números agregados.

## Restrições

- Até 3h/semana do fundador para vender e divulgar; até R$500/mês de mídia.
- Sem venda 1:1: tudo pelo app, pelas lojas e por canais self-service.
- Nenhuma empresa paga ainda. 749 estão no Pro de cortesia até 07/12/2026.

## O que os dados mostram

- **Ads de app (mar–jul):** ~R$0,55 por instalação, mas só ~6% das empresas daquela safra seguiram usando. Pausados desde julho.
- **Cadastros orgânicos (jul–set):** 226, e 40% criou OS. A origem é desconhecida.
- **Link público da OS:** ~194 enviados em 90 dias, sem chamada para o app nem medição.
- **Cobrança Asaas:** nenhuma empresa usando; sem split, não gera receita para o PraticOS.

### Uso por segmento (OS nos últimos 90 dias)

| Segmento | Ativação | Empresas com ≥5 OS/mês | Ticket mediano | Usa link da OS |
|---|---|---|---|---|
| Climatização | **49%** | **5** | R$250 | 16% |
| Automotivo | 31% | 3 | R$750 | 5% |
| Celular | 28% | 1 | R$290 | 69% |
| Informática | 43% | 1 | R$220 | 72% |

## Decisões

1. **Converter a cortesia em 07/12** é a maior alavanca: IA na OS no ar até 15/11, uso do plano visível, avisos 15 e 3 dias antes, plano anual de fundador. Se a IA atrasar, a cortesia é estendida junto.
2. **Segmento de entrada: técnico de climatização** (autônomo ou 1–5 técnicos). Melhor ativação sem marketing, leitura da etiqueta pela IA, manutenção recorrente (PMOC) que traz o usuário de volta todo mês e verão começando. O app continua aberto a todos; muda a mensagem, os canais e 3–4 funções. Automotivo é a 2ª frente em 2027.
   - O app **ajuda a registrar** a manutenção; não promete "emitir PMOC" (exige responsável técnico).
3. **Afiliados pela Hotmart**, não programa próprio: a Hotmart paga o afiliado em cada renovação e cobra 9,9% + R$2,49 (a loja cobra 15%). Teste de 60 dias com plano anual ao mesmo preço da loja. No iOS o app só reconhece o plano; não linka compra na web.
4. **ERPs com OS e sem app de OS:** GestãoClick é o melhor fit (mesmo público, API de OS). Começa por conversa comercial, sem dev.
5. **Exterior:** não vender fora agora. Depois da IA, 30 dias com páginas das lojas em en-US e es-MX e preço em dólar, só medindo.
6. **Fica para depois:** split da cobrança Asaas, Bling/Omie/Olist, contadores, distribuidores e fabricantes, diretórios de IA. Flapp Store segue só com follow-up.

## Plano de 8 semanas (12/10 → 07/12)

| Semana | Entrega | Issue |
|---|---|---|
| 1 | Rodapé no link/PDF da OS + origem do cadastro; funil de ativação | #345, #299 |
| 1–5 | IA na OS, com leitura da etiqueta (caminho crítico) | #342 |
| 1–2 | Pergunta no app para climatização (manutenção/PMOC) | #347 |
| 2–3 | Uso do plano visível + paywall no limite; plano anual nas lojas | #344, #96 |
| 3–4 | Onboarding pela 1ª OS com foto | #346 |
| 4–6 | Pacote climatização: checklist pronto, lembrete de manutenção, relatório em PDF | #348, #110, #349 |
| 5 | Landing e páginas das lojas de ar-condicionado; ads otimizando a 1ª OS | #351, #352, #353 |
| 5–8 | Hotmart com 5–10 afiliados (após resposta do suporte) | #350 |
| 6–7 | Avisos do fim da cortesia (15 e 3 dias) com oferta anual | #343 |
| 8 | Corte da cortesia e decisão | — |
| depois | QR no equipamento; experimento en-US/es-MX | #109, #354 |

## Metas e o que medir (toda segunda)

| Métrica | Hoje | Meta |
|---|---|---|
| Assinantes pagantes | 0 | 10 em 31/12 (5 de climatização) |
| MRR | R$0 | ≥R$600 em 31/12 |
| Ativação (1ª OS em 7 dias) | ~40% (sem prazo; medir no #299) | 60% em climatização |
| Cadastros de climatização/semana | ~3 (est.) | 10 |
| Custo por empresa ativa (ads) | — | ≤R$40 |

**Decisão em 07/12:** com menos de 5 pagantes entre as empresas mais ativas, o problema é preço ou valor e não se gasta mais em ads. Com 10+ pagantes e custo por ativa ≤R$40, escalar ads. No fim de janeiro (fim do verão), decidir se dobra a aposta em climatização ou abre o automotivo.
