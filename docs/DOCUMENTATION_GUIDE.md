# Documentation Guide - PraticOS

Guia para documentar novas funcionalidades no projeto.

## Quando Documentar

| Tipo de Mudança | docs/ | public/docs/ |
|-----------------|-------|--------------|
| Nova feature completa | Obrigatório | Obrigatório |
| Mudança significativa | Atualizar | Atualizar |
| Bug fix | Não | Não |
| Refatoração interna | Se mudar arquitetura | Não |
| Nova API/Endpoint | Obrigatório | Geralmente não |

## 1. Documentação Técnica (`docs/`)

Criar arquivo `docs/FEATURE_NAME.md` (inglês, UPPER_SNAKE_CASE):

```markdown
# FEATURE_NAME.md

## Visão Geral
Breve descrição da funcionalidade.

## Arquitetura
- Models envolvidos
- Stores/Repositories
- Estrutura Firestore

## Fluxo de Dados
Diagrama ou descrição do fluxo.

## Regras de Negócio
Lista de regras implementadas.

## Exemplos de Uso
Código de exemplo quando aplicável.
```

## 2. Documentação Pública (`firebase/hosting/public/docs/`)

Para funcionalidades visíveis ao usuário final, criar documentação em 3 idiomas:

```
firebase/hosting/public/docs/
├── feature.html         # Português (principal)
├── feature-en.html      # Inglês
├── feature-es.html      # Espanhol
└── docs.css             # Estilos compartilhados
```

### Template HTML

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>Nome da Feature - PraticOS</title>
  <link rel="stylesheet" href="docs.css">
</head>
<body>
  <header>
    <h1>Nome da Feature</h1>
    <nav>
      <a href="feature.html" class="active">PT</a>
      <a href="feature-en.html">EN</a>
      <a href="feature-es.html">ES</a>
    </nav>
  </header>
  <main>
    <!-- Conteúdo -->
  </main>
</body>
</html>
```

## Checklist

Antes de finalizar uma feature:

- [ ] Arquivo `docs/FEATURE_NAME.md` criado/atualizado
- [ ] Documentação técnica completa
- [ ] Arquivo `firebase/hosting/public/docs/feature.html` (PT)
- [ ] Versões `-en.html` e `-es.html`
- [ ] Links no `index.html` atualizados (se aplicável)
