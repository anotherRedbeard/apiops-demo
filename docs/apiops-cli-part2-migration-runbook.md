# APIOps CLI Part 2: Toolkit Migration Demo Runbook

This is the complete operator sequence for migrating the existing APIOps
Toolkit repository to APIOps CLI.

## Demo resources

| Item | Value |
|---|---|
| Repository | `anotherRedbeard/apiops-demo` |
| Local path | `/Users/andrewredman/src/apiops/apiops-demo` |
| Legacy starting tag | `demo-part2-start` |
| Migration PR | `#79` |
| Source subscription | `0272c02b-5a38-4b6b-86e6-dcc4ff2ff0e8` |
| Source resource group | `red-scus-apiopsdemo-rg-dev` |
| Source APIM | `red-apim-dev` |
| Target subscription | `c32b355a-3c13-4bd7-8b52-4202f962418a` |
| Target resource group | `red-scus-apiopsdemo-rg-prd` |
| Target APIM | `red-apim-prd` |

## 1. Explain the migration goal

The APIOps operating model remains:

```text
extract -> Git review and pull request -> publish
```

The migration replaces the Toolkit executables and workflows with the unified
APIOps CLI while preserving:

- Existing APIM artifacts
- Environment-specific overrides
- GitHub environments
- Azure identities and RBAC
- Key Vault-backed values
- Developer-portal package dependencies

## 2. Start from the legacy baseline

For a rehearsal, create a disposable branch from the immutable Toolkit tag:

```bash
cd /Users/andrewredman/src/apiops/apiops-demo
git fetch origin --tags --prune
git switch main
git pull --ff-only origin main
git switch -c demo/migration-live-YYYYMMDD demo-part2-start
git status
```

The current migrated implementation remains on `main`. The new rehearsal
branch shows the original Toolkit state.

## 3. Inventory the Toolkit implementation

Show the legacy files:

```bash
find .github/workflows -maxdepth 1 -type f | sort
ls -1 configuration*.yaml
find apimartifacts -type f | wc -l
cat package.json
```

Explain:

- `apimartifacts/` is the existing source-controlled APIM configuration.
- Toolkit workflows use separate extractor and publisher executables.
- Environment overrides use the old `{#tokenName#}` syntax.
- The repository also contains developer-portal Node.js dependencies that must
  not be overwritten.

## 4. Preserve the legacy files

`apiops init` fails when configuration files already exist. Do not use
`--force` directly because it replaces meaningful files.

Rename the Toolkit configuration and package files:

```bash
mv configuration.extractor.yaml configuration.extractor.toolkit.yaml
mv configuration.dev.yaml configuration.dev.toolkit.yaml
mv configuration.prod.yaml configuration.prod.toolkit.yaml
cp package.json package.toolkit.json
cp package-lock.json package-lock.toolkit.json
```

Keep `apimartifacts/` unchanged.

## 5. Generate the CLI scaffold

```bash
npx -y @azure-tools/apiops-cli@latest init \
  --ci github-actions \
  --artifact-dir ./apimartifacts \
  --environments dev,prod \
  --non-interactive
```

Review the generated files:

```bash
find .github/prompts -type f | sort
ls -1 .github/workflows/run-apiops-*.yml
ls -1 configuration*.yaml
```

The new scaffold is now beside the preserved Toolkit files for comparison.

## 6. Translate the extraction filter

Toolkit field:

```yaml
subscriptionNames:
  - 66ce4b511f9b910053070002
```

CLI field:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/extractor-config.schema.json

subscriptions:
  - 66ce4b511f9b910053070002
```

The artifact format remains compatible; the configuration schema and field
names are what change.

## 7. Translate environment overrides

Compare each generated file with its Toolkit copy:

```bash
diff -u configuration.dev.toolkit.yaml configuration.dev.yaml || true
diff -u configuration.prod.toolkit.yaml configuration.prod.yaml || true
```

Apply these rules:

1. Remove `apimServiceName`; target service selection comes from
   `--service-name`.
2. Convert tokens:

   ```text
   {#tokenName#} -> {#[TOKEN_NAME]#}
   ```

3. Use GitHub environment names already present in the repository:

   ```text
   RESOURCE_GROUP_NAME
   APIM_INSTANCE_NAME
   AZURE_SUBSCRIPTION_ID
   ```

4. Add `properties: {}` to API overrides that only contain nested diagnostics.
   The current override schema requires an active `properties` object.

Examples:

```yaml
apis:
  - name: "testopenai"
    properties: {}
    diagnostics:
      - name: azuremonitor
```

Validate that no Toolkit tokens remain:

```bash
grep -RFn '{#' configuration.dev.yaml configuration.prod.yaml
```

Expected matches use only `{#[TOKEN_NAME]#}`.

## 8. Merge package dependencies

The generated package must not replace the developer-portal package.

Restore the baseline package files and add APIOps CLI:

```bash
git show HEAD:package.json > package.json
git show HEAD:package-lock.json > package-lock.json
npm install @azure-tools/apiops-cli@latest --save
npm pkg set 'dependencies.@azure-tools/apiops-cli=latest'
npm install
```

Verify:

```bash
cat package.json
```

The final package must retain:

- `@azure/storage-blob`
- `mime`
- `yargs`
- `@azure-tools/apiops-cli`

Add Node dependencies to `.gitignore`:

```text
node_modules/
```

Do not run `npm audit fix --force`.

## 9. Correct the generated publisher trigger

Change:

```yaml
- './apimartifacts/**'
```

to:

```yaml
- 'apimartifacts/**'
```

This ensures artifact-only pull requests trigger the publisher after merge.

## 10. Reuse GitHub environment variables

The repository's `dev` and `prod` environments already contain:

```text
RESOURCE_GROUP_NAME
APIM_INSTANCE_NAME
```

Extractor job mapping:

```yaml
env:
  APIM_RESOURCE_GROUP: ${{ vars.RESOURCE_GROUP_NAME }}
  APIM_SERVICE_NAME: ${{ vars.APIM_INSTANCE_NAME }}
```

Publisher job mapping:

```yaml
env:
  RESOURCE_GROUP_NAME: ${{ vars.RESOURCE_GROUP_NAME }}
  APIM_INSTANCE_NAME: ${{ vars.APIM_INSTANCE_NAME }}
  TEST_SECRET_VALUE: ${{ vars.RESOURCE_GROUP_NAME }}
```

Do not create duplicate APIM resource-group or service-name secrets.

## 11. Configure GitHub OIDC

Reuse the existing environment-specific Entra applications:

| Environment | App registration | Client ID |
|---|---|---|
| dev | `spAPIOpsDemoDev` | `733d9303-bfc0-4463-a6c6-519fa26ce397` |
| prod | `spAPIOpsDemoPrd` | `84c9ad8f-123c-4af8-8741-ab1ebce74dc7` |

Federated credential subjects:

```text
repo:anotherRedbeard@34103220/apiops-demo@601646614:environment:dev
repo:anotherRedbeard@34103220/apiops-demo@601646614:environment:prod
```

Issuer:

```text
https://token.actions.githubusercontent.com
```

Audience:

```text
api://AzureADTokenExchange
```

The generated workflows use:

```yaml
- uses: azure/login@v3
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

The new CLI workflows do not use `AZURE_CLIENT_SECRET`. Keep the secret only
while legacy workflows still need it.

## 12. Preserve Key Vault token replacement

The production override retains:

```yaml
subscriptions:
  - name: "66ce4b511f9b910053070002"
    properties:
      primaryKey: "{#[UNLIMITED_SUBSCRIPTION_PRIMARY_KEY]#}"
      secondaryKey: "{#[UNLIMITED_SUBSCRIPTION_SECONDARY_KEY]#}"
```

The publisher retrieves:

```text
APIM-Unlimited-Subscription-Primary-Key
APIM-Unlimited-Subscription-Secondary-Key
```

It masks and exports them as:

```text
UNLIMITED_SUBSCRIPTION_PRIMARY_KEY
UNLIMITED_SUBSCRIPTION_SECONDARY_KEY
```

Token validation checks GitHub environment secrets first, then values loaded
into the runtime environment.

## 13. Handle the CLI subscription limitation

APIOps CLI 1.0.4 skips product subscriptions whose resource names are
24-character hexadecimal IDs:

```text
SKIP subscriptions/66ce4b511f9b910053070002
     (auto-generated product subscription)
```

This subscription is explicitly managed, so the migrated publisher performs a
post-publish APIM REST update:

1. Read the existing subscription.
2. Preserve its display name, scope, owner, state, and tracing setting.
3. Replace only the primary and secondary keys with the masked Key Vault
   values.

During `DRY_RUN_ONLY=true`, the workflow verifies the subscription exists but
does not update it.

File an upstream issue against `Azure/apiops-cli` for the false-positive
classification when GitHub organization SAML authorization is available.

## 14. Add manual dry-run safety

The publisher workflow includes:

```yaml
DRY_RUN_ONLY:
  description: 'Validate the deployment without changing APIM'
  required: true
  type: boolean
  default: true
```

Manual runs skip real publish and key-update steps while this value is `true`.
Automatic publishing remains limited to the intended `main` branch trigger.

## 15. Validate the existing Toolkit artifacts

The local full-artifact dry-run against development completed with:

```text
135 creates/updates
0 patches
0 deletes
2 skipped subscriptions
```

The two subscription skips are handled as described above. Most importantly,
the CLI accepted the existing Toolkit artifact format without conversion.

Show the artifacts and result:

```bash
find apimartifacts -type f | wc -l
npx apiops --version
```

The validated CLI version was `1.0.4`.

## 16. Disable legacy Toolkit workflows

Disable only the old APIOps Toolkit workflows:

```bash
gh workflow disable run-extractor.yaml
gh workflow disable run-publisher.yaml
gh workflow disable run-publisher-with-env.yaml
```

Leave developer-portal workflows active.

Verify:

```bash
gh workflow list --all
```

Expected states:

```text
disabled_manually  Run - Extractor
disabled_manually  Run - Publisher
disabled_manually  Run Publisher with Environment
active             Run APIM Extractor
active             Run APIM Publisher
```

## 17. Show the completed migration PR

The validated migration was merged through PR #79:

```bash
gh pr view 79 --web
```

Use the PR to show:

- Preserved Toolkit reference files
- New CLI workflows and prompts
- Filter and override translations
- Package dependency merge
- OIDC changes
- Publisher dry-run safeguard
- Subscription-key compatibility workaround

## 18. First GitHub workflow execution

The first run of a newly introduced workflow may be stopped by GitHub's
malicious-workflow protection:

```text
GitHub detected that this workflow file may be malicious.
It will not run until someone with write access approves it.
```

Open the run in GitHub Actions, review the workflow, and select
**Approve and run**. This approval must be performed in the web UI.

For publisher validation, select:

```text
COMMIT_ID_CHOICE = publish-all-artifacts-in-repo
ENVIRONMENT = prod
DRY_RUN_ONLY = true
```

If approval is not completed during a presentation, show the workflow, PR #79,
and the successful local dry-run result instead.

## 19. Live-demo safety

- Keep `DRY_RUN_ONLY=true` until the target baseline is confirmed.
- Do not use `--delete-unmatched`.
- Do not run `npm audit fix --force`.
- Do not enable both legacy and CLI publishers at the same time.
- Key Vault network rules must permit the selected runner to retrieve secrets.
- Use PR #79 and the validated local result if live Azure operations are slow.

## 20. Reset the migration demo

Create a new rehearsal branch from the immutable Toolkit tag:

```bash
cd /Users/andrewredman/src/apiops/apiops-demo
git switch main
git switch -c demo/migration-live-YYYYMMDD-HHMM demo-part2-start
```

The tag restores the original repository content. Repository-level settings
remain shared prerequisites:

- GitHub environments and their variables/secrets
- Entra applications and federated credentials
- Azure RBAC
- Workflow enabled/disabled state

If demonstrating the migration from the tag, explain that the completed
implementation and PR remain available on `main` as the validated reference.
