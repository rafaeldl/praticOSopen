# Git Workflow - PraticOS

Regras obrigatorias para todos os agentes que alteram o codebase.

## Principio Fundamental

Cada tarefa que modifica codigo DEVE:
1. Ter sua propria branch
2. Usar um worktree isolado (se outro agente esta usando o repo principal)
3. Ter TODOS os arquivos commitados antes de encerrar o heartbeat
4. Nunca deixar arquivos modificados ou untracked no working directory

## Fluxo de Trabalho

### 1. Antes de Comecar

```bash
# Verificar estado do repo
cd /Users/rafaeldl/Projetos/praticOSopen
git status

# Se ha arquivos nao commitados de OUTRA tarefa, NAO prosseguir
# Contactar o CTO para resolver
```

### 2. Criar Branch e Worktree

Para cada tarefa, usar um worktree dedicado:

```bash
# Buscar atualizacoes
git fetch origin

# Criar branch a partir de master (ou da branch pai, se subtarefa)
git branch feat/PRA-XXX origin/master

# Criar worktree isolado
git worktree add /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-XXX feat/PRA-XXX

# Trabalhar no worktree
cd /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-XXX
```

### 3. Nomenclatura de Branches

| Tipo | Formato | Exemplo |
|------|---------|---------|
| Feature | `feat/PRA-XXX-descricao` | `feat/PRA-43-git-workflow` |
| Bug fix | `fix/PRA-XXX-descricao` | `fix/PRA-30-login-crash` |
| Chore | `chore/PRA-XXX-descricao` | `chore/PRA-20-ci-keys` |
| Docs | `docs/PRA-XXX-descricao` | `docs/PRA-41-testing-guide` |

**Regras:**
- Sempre incluir o numero da issue (PRA-XXX)
- Descricao curta em kebab-case
- Nunca trabalhar diretamente na `master`

### 4. Durante o Desenvolvimento

```bash
# Commitar frequentemente (a cada mudanca logica)
git add <arquivos-especificos>
git commit -m "tipo(escopo): descricao (PRA-XXX)"

# Exemplos:
git commit -m "feat(billing): add plans screen (PRA-18)"
git commit -m "fix(pdf): correct watermark position (PRA-25)"
git commit -m "docs(qa): add visual testing guide (PRA-40)"
```

**NUNCA:**
- Usar `git add .` ou `git add -A` (risco de incluir arquivos indevidos)
- Deixar arquivos modified/untracked ao finalizar trabalho
- Trabalhar em branch de outra tarefa sem necessidade

### 5. Ao Finalizar

```bash
# Verificar que nao ha arquivos soltos
git status  # Deve mostrar "working tree clean"

# Push para remote
git push -u origin feat/PRA-XXX

# Criar PR (se aplicavel)
gh pr create --title "tipo(escopo): descricao (PRA-XXX)" --base master

# Remover worktree quando PR for mergeado
git worktree remove /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-XXX
```

### 6. Limpeza de Branches

Apos merge de um PR:

```bash
# Remover branch local
git branch -d feat/PRA-XXX

# Remover worktree se existir
git worktree remove /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-XXX 2>/dev/null
```

## Regras para Agentes

### Flutter Engineer
- SEMPRE criar worktree antes de comecar uma tarefa
- SEMPRE commitar TODOS os arquivos antes de finalizar
- Se a tarefa envolve gerar codigo (codegen, l10n), commitar os arquivos gerados tambem
- Executar `flutter analyze` antes do commit final

### CTO
- Revisar estado do repositorio a cada heartbeat
- Garantir que nao ha arquivos soltos no working directory principal
- Fazer code review verificando que PRs estao na branch correta
- Limpar branches mergeadas periodicamente

### QA Engineer
- Usar worktree para testes que geram arquivos (screenshots, logs)
- Commitar evidencias de teste na branch da tarefa

### DevOps
- Usar worktree para mudancas em CI/CD
- Nunca alterar master diretamente

## Estrutura de Diretorios

```
/Users/rafaeldl/Projetos/
  praticOSopen/                    # Repo principal (branch principal ativa)
  praticOSopen-light-theme/        # Worktree: feat/website-light-theme
  praticOSopen-worktrees/          # Pasta para worktrees de agentes
    PRA-XXX/                       # Um worktree por tarefa
    PRA-YYY/
```

## Checklist Pre-Commit

- [ ] Todos os arquivos relevantes estao staged (`git add`)
- [ ] Nenhum arquivo de segredo incluido (.env, credentials, keys)
- [ ] `flutter analyze` passa sem erros (para codigo Dart)
- [ ] Mensagem de commit segue o padrao `tipo(escopo): descricao (PRA-XXX)`
- [ ] Branch esta atualizada com a base (`git rebase origin/master` ou merge)

## Checklist Pre-Push

- [ ] `git status` mostra "working tree clean"
- [ ] Nenhum stash pendente relacionado a esta tarefa
- [ ] Branch aponta para o remote correto

## Manutencao

### Limpeza Mensal
1. Remover branches locais ja mergeadas: `git branch --merged master | grep -v master | xargs git branch -d`
2. Remover stashes antigos: revisar `git stash list` e dropar os desnecessarios
3. Remover worktrees orfaos: `git worktree prune`
4. Fazer prune de remotes: `git remote prune origin`
