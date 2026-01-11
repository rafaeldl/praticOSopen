# Auto Versioning

## Overview

Automatic versioning system based on Conventional Commits that manages version bumps, tag creation, and artifact promotion for the PraticOS mobile app.

## Architecture

### Workflows

```
┌─────────────────────────────────────────────────────────────────┐
│                         auto-version.yml                         │
│  Trigger: push to master (only app/metadata changes)             │
│  Actions: Analyze commits → Bump version → Update pubspec.yaml   │
│           → Create v*-rc tag → Trigger releases                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│            android_release.yml + ios_release.yml                 │
│  Trigger: workflow_dispatch from auto-version                    │
│  Actions: Build → Upload to Internal/TestFlight (binary only)    │
│           → Save artifacts to GitHub Release                     │
│  Concurrency: Cancels previous release of same platform          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      promote-release.yml                         │
│  Trigger: workflow_dispatch (manual)                             │
│  Actions: Download artifacts → Upload to Production              │
│           → Upload metadata/changelogs → Create production tag   │
└─────────────────────────────────────────────────────────────────┘
```

### Files

| File | Purpose |
|------|---------|
| `.github/workflows/auto-version.yml` | Analyzes commits, bumps version, creates RC tag |
| `.github/workflows/android_release.yml` | Builds Android, uploads to Internal, saves AAB |
| `.github/workflows/ios_release.yml` | Builds iOS, uploads to TestFlight, saves IPA |
| `.github/workflows/promote-release.yml` | Promotes RC to production using saved artifacts |
| `.github/workflows/android_build_check.yml` | PR build check for Android |
| `.github/workflows/ios_build_check.yml` | PR build check for iOS |

## Path Filters

The auto-version workflow only triggers when relevant files change:

| Path | Description |
|------|-------------|
| `lib/**` | Flutter app code |
| `pubspec.yaml` / `pubspec.lock` | Dependencies |
| `android/**` | Android native code + metadata |
| `ios/**` | iOS native code + metadata |
| `assets/**` | App assets |
| `test/**` / `integration_test/**` | Tests |

**Ignored paths** (no version bump):
- `.github/**` - Workflow changes
- `docs/**` - Documentation
- `*.md` - Markdown files
- `firebase/**` - Hosting/Functions

## Concurrency

### Release Workflows

Only one release per platform runs at a time. New releases cancel previous ones:

```yaml
concurrency:
  group: android-release  # or ios-release
  cancel-in-progress: true
```

### Build Check Workflows

Each PR has its own queue. New pushes cancel previous builds for the same PR:

```yaml
concurrency:
  group: android-build-${{ github.head_ref }}
  cancel-in-progress: true
```

## RC vs Production: What Gets Uploaded

| Content | RC (Internal/TestFlight) | Production (Promote) |
|---------|--------------------------|----------------------|
| Binary (AAB/IPA) | ✅ | ✅ (reused from RC) |
| Metadata | ❌ | ✅ (if changed) |
| Screenshots | ❌ | ✅ (if changed) |
| Changelogs | ❌ | ✅ |

This ensures:
- Fast RC builds (binary only)
- No validation errors during RC phase
- Metadata/screenshots only uploaded when promoting to production

## Conventional Commits

The system analyzes commit messages to determine version bump type automatically.

### Commit Message Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Required format:**
- `type`: Required. One of the types listed below
- `scope`: Optional. Module/area affected (e.g., `auth`, `orders`, `ui`)
- `description`: Required. Short description in imperative mood
- `!` after type/scope: Indicates breaking change

### Commit Types and Version Bumps

| Type | Description | Version Bump | Example |
|------|-------------|--------------|---------|
| `feat` | New feature or functionality | **Minor** (1.0.0 → 1.1.0) | `feat: add dark mode toggle` |
| `feat!` | New feature with breaking change | **Major** (1.0.0 → 2.0.0) | `feat!: new auth system` |
| `fix` | Bug fix | **Patch** (1.0.0 → 1.0.1) | `fix: resolve login crash` |
| `perf` | Performance improvement | **Patch** | `perf: optimize image loading` |
| `refactor` | Code refactoring (no feature/fix) | **Patch** | `refactor: restructure auth module` |
| `docs` | Documentation only | **Patch** | `docs: update API guide` |
| `style` | Code style (formatting, semicolons) | **Patch** | `style: fix indentation` |
| `test` | Adding or updating tests | **Patch** | `test: add unit tests for Order` |
| `chore` | Maintenance tasks | **Patch** | `chore: update dependencies` |
| `ci` | CI/CD configuration | **Patch** | `ci: add caching to workflow` |
| `build` | Build system changes | **Patch** | `build: update gradle config` |

### Breaking Changes (Major Bump)

Two ways to indicate a breaking change:

**Option 1: Exclamation mark after type**
```bash
feat!: new authentication flow
fix!: change API response format
refactor!: rename public methods
```

**Option 2: BREAKING CHANGE footer**
```bash
feat: new API endpoints

BREAKING CHANGE: removed v1 endpoints, use v2 instead
```

### Scope (Optional)

The scope provides context about which module is affected:

```bash
feat(auth): add biometric login
fix(orders): resolve date picker crash
refactor(ui): reorganize widget structure
perf(storage): optimize image upload
```

Common scopes for PraticOS:
- `auth` - Authentication
- `orders` - Order management
- `customers` - Customer module
- `ui` - User interface
- `storage` - Firebase Storage
- `db` - Firestore database
- `ci` - CI/CD workflows

### Complete Examples

```bash
# Feature (Minor bump: 1.0.0 → 1.1.0)
git commit -m "feat: add customer export to PDF"
git commit -m "feat(orders): add bulk status update"

# Fix (Patch bump: 1.0.0 → 1.0.1)
git commit -m "fix: resolve crash when email is empty"
git commit -m "fix(auth): handle expired token gracefully"

# Performance (Patch bump)
git commit -m "perf: lazy load order images"
git commit -m "perf(storage): compress images before upload"

# Refactor (Patch bump)
git commit -m "refactor: extract validation logic to service"
git commit -m "refactor(models): simplify Order serialization"

# Breaking change (Major bump: 1.0.0 → 2.0.0)
git commit -m "feat!: new authentication system"

# Breaking change with body
git commit -m "feat: new order status flow

BREAKING CHANGE: removed 'pending_payment' status, use 'awaiting_payment' instead"

# Chore (Patch bump)
git commit -m "chore: update Flutter to 3.32"
git commit -m "chore(deps): bump firebase_core to 3.14"

# Docs (Patch bump)
git commit -m "docs: add API documentation"
git commit -m "docs(readme): update installation steps"

# CI (Patch bump)
git commit -m "ci: add iOS build caching"
git commit -m "ci(release): optimize artifact upload"
```

### What NOT to do

```bash
# ❌ Missing type
git commit -m "add dark mode"

# ❌ Wrong format (uppercase, no colon)
git commit -m "FEAT add dark mode"
git commit -m "feat - add dark mode"

# ❌ Past tense (use imperative)
git commit -m "feat: added dark mode"

# ❌ Type not recognized
git commit -m "feature: add dark mode"
git commit -m "bugfix: resolve crash"

# ✅ Correct
git commit -m "feat: add dark mode"
git commit -m "fix: resolve crash"
```

### Priority Rules

When multiple commits are analyzed, the highest priority bump wins:

1. **Major** - Any commit with `!` or `BREAKING CHANGE`
2. **Minor** - Any `feat` commit
3. **Patch** - All other recognized types

## Data Flow

### 1. Development Phase

```
Developer creates PR
         │
         ▼
PR merged to master
         │
         ▼
auto-version.yml triggers (if paths match)
         │
         ├─► Finds latest RC tag (v1.0.0-rc)
         │
         ├─► Analyzes commits since that tag
         │
         ├─► Determines bump type (major/minor/patch)
         │
         ├─► Updates pubspec.yaml (version + build number)
         │
         ├─► Commits: "chore(release): bump version to X.Y.Z [skip ci]"
         │
         ├─► Creates and pushes tag: vX.Y.Z-rc
         │
         └─► Triggers release workflows from master
```

### 2. Build Phase

```
Release workflows triggered
         │
         ├─► android_release.yml (from master, checkout tag)
         │        │
         │        ├─► Cancels any previous Android release
         │        ├─► Builds AAB
         │        ├─► Uploads to Google Play Internal (binary only)
         │        └─► Saves AAB to GitHub Release
         │
         └─► ios_release.yml (from master, checkout tag)
                  │
                  ├─► Cancels any previous iOS release
                  ├─► Builds IPA
                  ├─► Uploads to TestFlight (binary only)
                  └─► Saves IPA to GitHub Release
```

### 3. Testing Phase

```
QA tests the app from TestFlight/Internal
         │
         ▼
    [Tests OK?]
         │
    ┌────┴────┐
    │         │
   Yes        No
    │         │
    ▼         ▼
Promote    Fix bugs
    │      (new PR)
    ▼
promote-release.yml
```

### 4. Promotion Phase

```
Developer triggers promote-release.yml
         │
         ├─► Input: v1.0.3-rc (or auto-detect latest)
         │
         ├─► Downloads AAB from GitHub Release
         │
         ├─► Downloads IPA from GitHub Release
         │
         ├─► Uploads AAB to Google Play Production
         │        └─► Includes metadata/changelogs if changed
         │
         ├─► Uploads IPA to App Store
         │        └─► Includes metadata/screenshots if changed
         │
         ├─► Creates production tag: v1.0.3
         │
         └─► Updates GitHub Release (marks as production)
```

## Business Rules

1. **Version Source of Truth**: `pubspec.yaml` is always in sync with the latest tag
2. **Build Numbers**: Automatically incremented with each release
3. **RC Tags**: All automated releases are RC (`-rc` suffix)
4. **Production Tags**: Only created via manual promotion
5. **Same Binary**: Production uses the exact same binary that was tested
6. **No Rebuild**: Promotion downloads pre-built artifacts, never rebuilds
7. **Concurrency**: New releases cancel previous ones (same platform)
8. **Path Filtering**: Only app/metadata changes trigger version bumps

## Version Format

```
version: X.Y.Z+BUILD

Where:
- X = Major (breaking changes)
- Y = Minor (new features)
- Z = Patch (bug fixes)
- BUILD = Incremental build number
```

**Example:** `1.2.3+45` means version 1.2.3, build number 45.

## GitHub Releases

Each RC creates a GitHub Release with:
- Tag: `v1.0.3-rc`
- Title: "Release 1.0.3 (RC)"
- Prerelease: true
- Artifacts:
  - `app-release.aab` (Android)
  - `Runner.ipa` (iOS)

After promotion:
- Tag: `v1.0.3` (additional tag, same commit)
- Title: "Release 1.0.3"
- Prerelease: false

## Usage Examples

### Normal Development Flow

```bash
# Work on feature
git checkout -b feature/dark-mode
# ... make changes ...
git commit -m "feat: add dark mode toggle"
git push origin feature/dark-mode

# Create PR, get reviews, merge to master
# → auto-version.yml creates v1.1.0-rc
# → Builds go to TestFlight/Internal (binary only)

# After testing, promote via GitHub Actions UI
# → promote-release.yml (leave tag empty for latest RC)
# → Same binaries go to production with metadata
```

### Bug Fix Flow

```bash
git checkout -b fix/login-crash
git commit -m "fix: resolve crash when email is empty"
git push origin fix/login-crash

# Merge to master
# → auto-version.yml creates v1.1.1-rc (patch bump)
```

### Breaking Change

```bash
git commit -m "feat!: new authentication system

BREAKING CHANGE: removed password-only login"

# → auto-version.yml creates v2.0.0-rc (major bump)
```

### CI-Only Changes (No Version Bump)

```bash
git commit -m "ci: add build caching"
git commit -m "fix(ci): improve workflow concurrency"

# → auto-version.yml does NOT trigger (path filter)
# → No new version created
```

## Troubleshooting

### Version not bumping correctly

1. Check commit message format (must follow Conventional Commits)
2. Verify commits are since the last RC tag
3. Check workflow logs for commit analysis output
4. Ensure changes are in paths that trigger auto-version

### Promotion fails

1. Verify RC tag exists
2. Check GitHub Release has artifacts
3. Verify production tag doesn't already exist
4. Check store credentials are valid

### Build number conflicts

The Fastlane scripts automatically fetch the latest build number from stores and increment. If conflicts occur:
1. Check both Internal and Production tracks
2. Manually increment if needed via `--build-number` flag

### Release not cancelled

If a new release doesn't cancel the previous one:
1. Ensure both releases are using the latest workflow (from master)
2. Check that concurrency group is the same
3. Verify `cancel-in-progress: true` is set

### Metadata validation errors

Release notes must be ≤500 characters for Google Play. If you get validation errors:
1. Check `android/fastlane/metadata/android/*/changelogs/default.txt`
2. Reduce content to fit the limit
3. RC phase skips changelogs, so errors only appear on promotion

## Workflow Run Names

Release workflows show the tag in the GitHub Actions UI:
- "Release Android v1.3.1-rc"
- "Release iOS v1.3.1-rc"

This makes it easy to identify which version is building/running.
