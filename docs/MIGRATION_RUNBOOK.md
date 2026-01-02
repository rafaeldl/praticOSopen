# Roteiro de Execução da Migração Multi-Tenant

Este roteiro detalha os passos exatos para executar a migração da arquitetura antiga (Field-Based) para a nova (Subcollections) em produção, assumindo um cenário de **Cutover Direto** (sem período de convivência com versões antigas do App).

---

## ⚠️ Pré-Requisitos Críticos

1.  **Backup:** Certifique-se de ter um backup recente do Firestore.
    ```bash
    gcloud firestore export gs://praticos.appspot.com/backups/pre-migration-$(date +%Y%m%d)
    ```
2.  **Acesso:** Garanta acesso de administrador ao projeto Firebase e ao Google Cloud CLI.
3.  **Janela de Manutenção:** Recomenda-se executar durante um período de baixo uso, embora o sistema possa permanecer online.
4.  **Ambiente Node.js:** Tenha Node.js (v18+) instalado para rodar os scripts de migração.

---

## Passo 1: Deploy da Infraestrutura (Backend)

Primeiro, atualizamos o backend para suportar a nova estrutura e processar os claims de segurança.

1.  **Deploy das Cloud Functions:**
    Isso publica a nova função de numeração de OS (`firestoreUpdateTenantOSNumber`) e a função de controle de acesso (`updateUserClaims`).
    ```bash
    firebase deploy --only functions
    ```

2.  **Deploy dos Índices:**
    Cria os índices necessários para as queries nas subcollections.
    ```bash
    firebase deploy --only firestore:indexes
    ```

3.  **Deploy das Security Rules:**
    Atualiza as regras para permitir leitura/escrita nas novas subcollections baseadas nos Custom Claims.
    ```bash
    firebase deploy --only firestore:rules
    ```

---

## Passo 2: Atualização de Permissões (Claims)

Antes de migrar os dados, os usuários precisam ter permissão para acessá-los no novo local. Este passo atribui os "Custom Claims" (`companies`, `roles`) a todos os usuários existentes.

1.  **Executar Script de Atualização de Claims:**
    Este script "toca" em todos os usuários, forçando a Cloud Function a rodar e atualizar suas permissões.
    ```bash
    cd firebase/scripts
    npm install # Instala dependências na primeira vez
    npm run refresh-claims
    ```

2.  **Validação:**
    Verifique os logs da Cloud Function `updateUserClaims` no console do Firebase para confirmar que as atualizações estão ocorrendo com sucesso ("Claims updated successfully for...").

---

## Passo 3: Migração de Dados

Agora movemos os dados de negócio (Ordens, Clientes, Produtos, etc.) da estrutura raiz para dentro das subcollections das empresas.

1.  **Executar Script de Migração:**
    ```bash
    # Dentro de firebase/scripts
    npm run migrate
    ```

2.  **Acompanhamento:**
    O script exibirá no console o progresso da migração por coleção (`orders`, `customers`, etc.).
    *   Verifique se não há erros críticos no log.
    *   O script pula documentos que já foram migrados (idempotente).

3.  **Validação:**
    Acesse o console do Firestore e verifique em `/companies/{companyId}/orders` se os dados aparecem corretamente.

---

## Passo 4: Publicação do App (Frontend)

Com o backend pronto e os dados migrados, libere a nova versão do App para os usuários.

1.  **Gerar Build:**
    ```bash
    flutter build appbundle  # Android
    flutter build ipa        # iOS
    ```

2.  **Publicar nas Lojas:**
    Envie a atualização para Google Play Store e Apple App Store.

---

## Plano de Rollback (Emergência)

Caso algo crítico falhe e seja necessário voltar atrás:

1.  **Reverter Dados (Se necessário):**
    Se os dados novos estiverem corrompidos ou inacessíveis, use o script de rollback para tentar sincronizar de volta (note que em Cutover direto, a estrutura antiga parou de receber updates, então ela é um "backup" do estado pré-migração).
    ```bash
    # Dentro de firebase/scripts
    npm run rollback
    ```

2.  **Reverter Backend:**
    Volte o código para o commit anterior à migração e faça redeploy das Functions e Rules.

3.  **Reverter App:**
    Se possível, disponibilize uma versão anterior do App ou use Remote Config para desativar funcionalidades quebradas (embora neste caso a mudança foi estrutural no código nativo).

---

**Fim do Roteiro.**
