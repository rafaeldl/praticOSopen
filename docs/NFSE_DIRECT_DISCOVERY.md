# Discovery: NFS-e direto no Emissor Nacional (sem intermediário)

> Status: **discovery e spike concluídos em 2026-11-05.** Próximo passo: desenhar e planejar a solução.
> Base atual: [`NFSE_ASAAS.md`](NFSE_ASAAS.md) (emissão pelo Asaas, pronta e desligada).
> Versão completa, com os dados do cliente piloto, fica fora do repositório (`~/Backups/praticos-insights/nfse-direta/DISCOVERY.md`), junto com o código do spike (`spike/`).

## Pergunta

O PraticOS consegue emitir a NFS-e dos próprios usuários com o certificado digital deles, falando direto com o Sistema Nacional NFS-e (Sefin Nacional e ADN), sem Asaas ou outro emissor no meio?

## Resposta curta

**Sim. Provado em produção:** uma nota real foi emitida e cancelada a partir de um script Node (a mesma base das Functions), com o certificado A1 de uma empresa do Simples.

- **Cobertura**: desde 01/11/2026, MEI e Simples (ME/EPP) emitem obrigatoriamente pelo Emissor Nacional, mesmo em cidade com sistema próprio (Res. CGSN 191/2026). É quase todo o nosso público. Uma integração só cobre o país.
- **Custo do governo**: zero por nota.
- **A condição**: o governo só aceita o certificado **do próprio prestador**, na conexão (mTLS) e na assinatura. Não existe procuração nem certificado de software house (FAQ oficial v1.2, item 17.7; o PAA está previsto, mas indisponível). O PraticOS teria de **guardar o A1 (.pfx) e a senha de cada emitente**.
- **O Asaas já faz isso**: as notas que o Asaas emite saem pela mesma API nacional, com o A1 do cliente guardado no Asaas. Ir direto é tirar o intermediário de um caminho que já funciona.

## Regras confirmadas

| Ponto | O que vale | Fonte |
|---|---|---|
| Certificado | ICP-Brasil (e-CNPJ/e-CPF) do prestador, na DPS e no mTLS; CNPJ diferente → E0718 | FAQ 17.7 |
| Procuração / integrador | Não existe hoje (PAA "em desenvolvimento") | FAQ 17.7, 28.1 |
| A1 × A3 | Os dois valem; num servidor, só A1 | FAQ 17.1 |
| Sem certificado | Só emissão manual no portal/app do governo; API sempre com certificado | FAQ 17.7 |
| MEI | Sempre no Emissor Nacional | FAQ 19.6 |
| Simples ME/EPP | Emissor Nacional desde 01/11/2026; IBS/CBS na nota a partir de 01/01/2027 | CGSN 191/2026, FAQ 20.x |
| Lucro Presumido/Real | API nacional só se a cidade aderiu (`aderenteEmissorNacional = 1`) | FAQ 19.6 |
| PDF (DANFSe) | API do governo suspensa em 03/08/2026: o emissor gera o PDF a partir do XML | FAQ 17.8 |
| Documentação | Ainda "minuta" até o CGNFS ser instalado | gov.br/nfse |

## O que o spike provou

| Item | Resultado |
|---|---|
| Montar a DPS (Simples e MEI) | ✅ passa no XSD oficial dos dois ambientes |
| Assinar (XMLDSig enveloped, RSA-SHA1, C14N) | ✅ |
| mTLS com A1 real | ✅ testes e produção |
| PFX "legacy" (RC2/3DES), comum em A1 | ⚠️ Node 22 não abre direto: abrir com `node-forge` e passar chave + cadeia em PEM ao `https.Agent` |
| Emitir em produção | ✅ autorizada em ~435 ms (`cStat 100`) |
| Cancelar (evento e101101) | ✅ aceito na hora |
| Produção Restrita (testes) | ⛔ recusou com E0119: o cadastro de testes da cidade estava desatualizado (contribuinte "não habilitado" só lá). Não depende de nós. Validar em produção, com nota real cancelada |
| Notas já emitidas e recebidas | ✅ API de distribuição devolve o XML completo de tudo o que o CNPJ emitiu **e recebeu** |
| NF-e recebidas (peças, SEFAZ) | ✅ consulta funciona (só leitura, resumos sem manifestação; janela de ~90 dias) |

Achados técnicos:
- **Leiautes diferentes ao mesmo tempo**: produção usa o pacote 20260209 (sem `finNFSe` no `infDPS`); a Produção Restrita usa o 20261020 (NT 009). O motor precisa escolher o leiaute por ambiente.
- O XSD de produção usa `^...$` nos padrões; o `xmllint` lê ao pé da letra. Para validar localmente, tirar as âncoras.
- `dhEmi` no fuso de Brasília e alguns segundos no passado (E0008).
- O código de serviço é **por cidade e por data** (E0312): escolher da lista que a cidade administra, não de tabela fixa.
- Inscrição municipal: mandar só se o cadastro nacional tiver (E0116 × E0120).
- O número da NFS-e é do governo, sequencial por CNPJ, compartilhado com qualquer outro emissor do mesmo CNPJ. A série da DPS é nossa (usar uma série própria evita colidir com o Asaas ou o portal).

### APIs de apoio (exigem o certificado)

| API | Para quê |
|---|---|
| `POST {sefin}/nfse`, `GET /dps/{id}`, `GET /nfse/{chave}`, `POST /nfse/{chave}/eventos` | Emitir, conferir idempotência, consultar, cancelar |
| `GET {adn}/parametrizacao/{ibge}/convenio` | A cidade usa o Emissor Nacional? |
| `GET {adn}/cnc/consulta/cad?codMunicipio=&inscricaoFederal=` | Inscrição municipal e se está habilitado a emitir |
| `GET {adn}/parametrizacao/{ibge}/{NN.NN.NN.NNN}/historicoaliquotas` | Alíquota de ISS do serviço na cidade |
| `GET {adn}/contribuintes/DFe/{NSU}?cnpjConsulta=&lote=true` | Notas emitidas e recebidas (50 por página, por NSU) |
| SEFAZ `NFeDistribuicaoDFe` (SOAP) | NF-e recebidas (peças) |

Bases: `sefin.nfse.gov.br/SefinNacional`, `adn.nfse.gov.br` (testes: `*.producaorestrita.nfse.gov.br`).

## Cliente piloto (dados agregados)

Uma oficina de funilaria/pintura do Simples, que usa muito o PraticOS, emite as notas hoje à mão. Com o certificado dela (cedido pelo dono, só leitura), as notas no governo mostraram:

- **Volume**: ~30 notas por mês e subindo; **100% à mão no portal do governo**; ~7% canceladas (erro de digitação).
- **Clientes**: poucas empresas (revendas) recebem quase todas as notas, sempre com endereço.
- **Código de serviço**: sempre o mesmo, e não o que o ramo sugeriria.
- **Uma nota por OS** (o dono antes agrupava por cliente).
- **Só nota de serviço**, nunca de produto.

Comparando as notas com as OS no PraticOS:
- **Valor**: igual à regra atual (soma dos serviços menos a parte do desconto).
- **Descrição**: os mesmos serviços da OS, reescritos no estilo do dono (maiúsculas, separados por " - ").
- **Status**: as OS ficam em "aprovada"; emissão automática "ao concluir" nunca dispararia.
- **Cliente**: nenhum cliente no PraticOS tem CNPJ; o nome na OS é o da loja, a nota vai para a razão social, e lojas diferentes podem ser faturadas no mesmo CNPJ.
- **Vários CNPJs**: o dono emite por **uma empresa do Simples e vários MEIs**, cada um com o seu certificado.

## Direção para o desenho

1. **Emitentes fiscais dentro da empresa.** A empresa continua uma só (clientes, OS, equipe) e ganha uma lista de emitentes: CNPJ, razão social, regime (Simples/MEI), cidade, inscrição municipal, certificado próprio, código de serviço e alíquota padrão, série/numeração, vencimento do certificado e, no MEI, faturamento do ano contra o teto. A folha da nota tem "Emitir por" com o padrão marcado.
2. **O certificado configura tudo.** Ao subir o A1, ler as notas antigas e preencher: dados do emitente, serviços usados (o mais usado vira padrão), clientes com CNPJ/razão social/endereço (criando ou completando os que existem), modelo de descrição, numeração e histórico. Mostrar o que foi importado e permitir desfazer; não duplicar clientes.
3. **Nota a partir da OS com um toque**: valor pela regra atual; descrição gerada dos serviços e editável; botão "Emitir nota" na OS, além da emissão automática por cliente.
4. **Dados fiscais no cliente**: digitar o CNPJ e puxar o resto; permitir que quem recebe a nota seja diferente da "loja" da OS.
5. **Notas recebidas → despesas** no Financeiro (NFS-e pelo ADN; NF-e pela SEFAZ numa segunda etapa).
6. **Reaproveitar** o que existe do Asaas: `invoices`, folha de emissão, lista de notas, regra do valor, recusas em frase simples.

Diferenças por regime que o motor trata:

| | Simples | MEI |
|---|---|---|
| `opSimpNac` | 3 + `regApTribSN` | 2, sem `regApTribSN` (E0162) |
| Tributos federais | `tribFed` (PIS/COFINS) | sem `tribFed` (E0676) |
| Valor aproximado dos tributos | `pTotTribSN` | `indTotTrib=0` |

## Guarda do certificado e da senha (proposta para o desenho)

Hoje as chaves do Asaas usam AES-256-GCM com uma chave mestra no Secret Manager (`ASAAS_CREDENTIALS_KEY`, `services/asaas/crypto.ts`). Um e-CNPJ vale muito mais que uma chave de API, então a proposta sobe o nível:

1. **Não guardar a senha.** No envio, o servidor abre o `.pfx` só na memória, confere se o CNPJ do certificado é o do emitente e lê a validade. Depois guarda só a chave privada e o certificado já abertos (PEM), cifrados, e descarta a senha e o `.pfx`. A senha nunca é gravada e nunca aparece em log. A troca de certificado repete o envio.
2. **Cifra em envelope com Cloud KMS, uma chave por certificado.** Cada certificado é cifrado com uma chave de dados própria (DEK, AES-256-GCM). A DEK é cifrada por uma chave do Cloud KMS (KEK) **exclusiva daquele emitente** (`nfse-certs/emitter-{emitterId}`), que nunca sai do KMS. Um vazamento do banco ou de um backup não abre nada sem chamar o KMS. Decisão de 2026-11-05: uma KEK por emitente, não uma compartilhada, para que apagar um certificado não afete os outros (ver item 7).
3. **Um só serviço decifra.** Só a função que emite e importa notas, com uma conta de serviço própria, tem `cloudkms.cryptoKeyDecrypter` nessa chave. O app, o app web e as outras Functions não têm. O KMS registra cada decifração em log de auditoria.
4. **Fora do alcance do app.** O material cifrado fica numa coleção fechada nas regras do Firestore (`allow read, write: if false`), fora de `companies/{id}`. O documento do emitente mostra só o que é público: CNPJ, titular, validade e "certificado enviado em".
5. **Na memória pelo menor tempo possível.** Decifra na hora de emitir, usa no `https.Agent` e na assinatura e descarta. Sem cache em disco nem em variável global entre chamadas.
6. **Quem pode mexer.** Só o dono (ou admin) envia, troca ou apaga. Ninguém, nem o dono, baixa o certificado de volta. Cada ação fica registrada (quem, quando, de qual aparelho).
7. **Apagar de verdade (crypto-shredding por emitente).** Decisão de 2026-11-05. Quando o emitente é removido, a conta é excluída ou o certificado vencido passa do prazo de guarda:
   1. o servidor apaga do banco o certificado cifrado e a DEK cifrada, e agenda no KMS a destruição da versão da KEK daquele emitente;
   2. a destruição fica agendada por **24 horas** (`destroyScheduledDuration` = 1 dia, o mínimo do KMS). Nesse prazo, se o dono apagou por engano, o sistema pode restaurar a versão da chave e reenviar o material;
   3. depois de 24 horas a versão é destruída de forma irreversível, e todas as cópias que ficaram em backups do Firestore viram lixo ilegível;
   4. ficam registrados quem apagou e quando, além do log de auditoria do KMS.

   **Por que uma KEK por emitente:** com uma KEK compartilhada, apagar o documento não basta, porque os backups ainda guardam a DEK cifrada e a KEK comum continua abrindo essa cópia até o backup expirar. E destruir a KEK comum apagaria os certificados de todos. Com uma por emitente, um é apagado sem tocar nos outros.

   **Renovação:** o certificado novo ganha uma versão nova da KEK, e a versão antiga é destruída da mesma forma. Cada emitente fica sempre com uma versão ativa.

   **Custo:** cerca de US$ 0,06 por versão ativa por mês, mais US$ 0,03 por 10 mil operações. Uma empresa com 10 certificados custa cerca de US$ 0,60 por mês; mil emitentes, cerca de US$ 60. Versão destruída não é cobrada. O KMS não apaga o nome da chave, só o conteúdo: fica um registro vazio, sem custo e sem dado.

   **Alternativa descartada:** uma KEK por empresa custaria 10 vezes menos para quem tem muitos CNPJs, mas apagar um só certificado deixaria a cópia dele nos backups ainda abrível.
8. **Avisos e consentimento.** O dono aceita um termo dizendo para que o certificado é usado (emitir e ler notas) e que pode apagar quando quiser. O app avisa 30 e 7 dias antes de vencer. A política de privacidade e o tratamento de LGPD são atualizados.

Descartado: guardar a chave num HSM sem exportação (Cloud KMS com importação de chave RSA). A assinatura da nota funcionaria, mas a conexão mTLS do governo exige a chave no próprio handshake TLS do Node. Fica para depois, se o governo aceitar outro modo de autenticação (por exemplo o PAA).

Tudo isso é `risk:high`: regras do Firestore, IAM, KMS e Functions com escrita. Pede revisão de segurança antes de ligar para o primeiro cliente.

## Riscos

- **Guarda do certificado (o maior)**: um e-CNPJ dá acesso a muito mais que nota (e-CAC, assinaturas). Pede criptografia com KMS/Secret Manager, acesso só pelo servidor, revisão de segurança, LGPD e termos. Tudo `risk:high`.
- **Regra em movimento**: documentação em minuta, IBS/CBS em 2027, PAA pode mudar o modelo.
- **Ambiente de testes pouco confiável**: cadastro por cidade desatualizado; o piloto valida em produção.
- **Suporte fiscal**: recusas por parametrização da prefeitura chegam ao nosso suporte.
- **Vários MEIs no mesmo negócio**: o produto apoia emitir por vários CNPJs, mas não sugere qual usar para escapar de teto. O enquadramento é assunto do contador.

## Fontes

- FAQ oficial NFS-e v1.2 (27/10/2026): https://www.gov.br/nfse/pt-br/perguntas-frequentes/perguntas-frequentes-nfs-e-v1-2-20261027.pdf
- Documentação técnica (produção e Produção Restrita): https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica
- Res. CGSN 191/2026: https://fenacon.org.br/noticias/simples-nacional-nfs-e-nacional-sera-obrigatoria-para-me-e-epp-a-partir-de-1o-de-novembro-de-2026/
- Referência open source (Python, em produção): https://github.com/Gomes343/PyNFSeNacional
