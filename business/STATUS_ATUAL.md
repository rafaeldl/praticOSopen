# 📊 Status Atual do PraticOS

**Data:** 2026-01-25  
**Análise:** Revisão do código fonte

---

## ✅ Funcionalidades PRONTAS

### Ordens de Serviço
- ✅ CRUD completo de OS
- ✅ Status workflow (Orçamento → Aprovado → Em Andamento → Concluído/Cancelado)
- ✅ Vínculo com cliente e equipamento
- ✅ Produtos e serviços na OS (com valores)
- ✅ Fotos na OS
- ✅ Data de vencimento
- ✅ Técnico atribuído (assignedTo)
- ✅ Numeração sequencial automática
- ✅ Link mágico para cliente (customerToken)
- ✅ Timeline/histórico de atividades
- ✅ Contador de não lidos por usuário
- ✅ PDF da OS com logo da empresa

### Cadastros
- ✅ Clientes (nome, telefone, email, endereço)
- ✅ Equipamentos (serial, nome, fabricante, categoria, foto)
- ✅ Produtos (catálogo com preços)
- ✅ Serviços (catálogo com preços)
- ✅ Colaboradores completo

### Financeiro
- ✅ Pagamentos parciais (transactions)
- ✅ Descontos com histórico
- ✅ Status: A Receber / Parcial / Pago
- ✅ Dashboard financeiro (financial_dashboard_simple.dart)
- ✅ Cálculo de saldo restante
- ✅ PDF com resumo financeiro

### Formulários Dinâmicos
- ✅ Templates por empresa
- ✅ Templates globais por segmento (seed)
- ✅ 6 tipos: text, number, select, checklist, boolean, photo_only
- ✅ Fotos por item do formulário
- ✅ i18n completo (pt, en, es)
- ✅ Campos obrigatórios
- ✅ Permissão allowPhotos por campo

### RBAC (Permissões)
- ✅ 5 perfis: Admin, Manager, Supervisor, Consultant, Technician
- ✅ 30+ permissões granulares
- ✅ Separação financeiro vs operacional
- ✅ Widgets de permissão (PermissionWidgets)

### Infraestrutura
- ✅ Multi-Tenancy completo
- ✅ Firebase Auth (Google, Apple, Email)
- ✅ Firebase Firestore
- ✅ Firebase Storage (fotos)
- ✅ Firebase Analytics
- ✅ Firebase Crashlytics
- ✅ Apps iOS e Android (Flutter)
- ✅ Modo claro e escuro
- ✅ i18n (pt, en, es)
- ✅ MobX para state management

### Onboarding
- ✅ Tela de boas-vindas
- ✅ Seleção de segmento
- ✅ Seleção de subespecialidades
- ✅ Cadastro de empresa
- ✅ Convites pendentes

---

## ❌ Funcionalidades FALTANDO

### Para Billing (Fase 1)
| Item | Status | Complexidade |
|------|--------|--------------|
| Controle de fotos/mês | ❌ Não existe | Média |
| Limite de formulários | ❌ Não existe | Baixa |
| Marca d'água no PDF | ❌ Não existe | Baixa |
| In-App Purchase (lojas) | ❌ Não existe | Média |
| Tela de planos/upgrade | ❌ Não existe | Média |
| Modelo de Company com plano | ❌ Não existe | Baixa |

**Cobrança:** Via App Store / Google Play (assinatura mensal)

### Para Features Críticas (Fase 2)
| Item | Status | Complexidade |
|------|--------|--------------|
| Push Notifications | ❌ Não tem firebase_messaging | Média |
| Dashboard melhorado | ⚠️ Existe básico | Média |
| Relatórios exportáveis | ⚠️ Só PDF de OS | Média |
| Pesquisa de satisfação | ❌ Não existe | Média |

### Nice-to-have (Futuro)
| Item | Status |
|------|--------|
| Rastreamento GPS | ❌ |
| Roteirização | ❌ |
| API pública | ❌ |
| Webhook | ❌ |
| QR Code funcional | ⚠️ Parcial |
| Agendamento recorrente | ❌ |

---

## 📦 Dependências Atuais

```yaml
# Firebase
firebase_core: ^3.14.0
firebase_crashlytics: ^4.3.7
firebase_analytics: ^11.5.0
firebase_auth: ^5.6.0
firebase_storage: ^12.4.4
cloud_firestore: (implícito)

# Faltando
firebase_messaging: ❌
stripe_sdk ou similar: ❌
```

---

## 🎯 Resumo Executivo

### O que TEM:
- App funcional completo para gestão de OS
- Formulários dinâmicos robustos
- Financeiro com pagamentos parciais
- RBAC bem implementado
- Multi-tenancy
- i18n (3 idiomas)
- PDF profissional

### O que FALTA para lançar:
1. **Billing** - Não tem como cobrar
2. **Limites por plano** - Não tem controle de fotos/formulários
3. **Push notifications** - Dependência não instalada
4. **Marca d'água** - Não diferencia plano Free

### Estimativa de Esforço

| Fase | Itens | Estimativa |
|------|-------|------------|
| Billing básico | Stripe + limites + upgrade | 2-3 semanas |
| Push notifications | Firebase Messaging | 3-5 dias |
| Marca d'água PDF | Modificar pdf_service | 1-2 dias |
| Controle fotos/mês | Contador no Firestore | 2-3 dias |
| Limite formulários | Validação no app | 1 dia |

**Total para MVP comercial: ~3-4 semanas**
