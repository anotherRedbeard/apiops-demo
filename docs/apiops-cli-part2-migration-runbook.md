# APIOps CLI Part 2: Toolkit Migration Runbook

This is the repeatable operator sequence for migrating the existing APIOps
Toolkit implementation to APIOps CLI without rebuilding the APIM artifacts.

## Outcome

The migration preserves:

- The existing `apimartifacts/` directory.
- Development and production override behavior.
- GitHub environments and environment-scoped configuration.
- Secretless GitHub OIDC authentication.
- Key Vault-managed subscription keys.
- Developer portal dependencies and workflows.

It replaces the legacy Toolkit extractor and publisher workflows with APIOps
CLI 1.0.5.

## Prerequisites

| Item | Required value |
|---|---|
| Starting tag | `demo-part2-start` |
| Node.js | 22 |
| APIOps CLI | 1.0.5 |
| GitHub environments | `dev`, `prod` |
| Artifact directory | `apimartifacts/` |

Each GitHub environment must contain:

| Type | Name |
|---|---|
| Secret | `AZURE_CLIENT_ID` |
| Secret | `AZURE_TENANT_ID` |
| Secret | `AZURE_SUBSCRIPTION_ID` |
| Secret | `KEYVAULT_NAME` |
| Secret | `APP_INSIGHTS_LOGGER_KEY` |
| Secret | `ALLOWED_IP_ADDRESS` |
| Variable | `RESOURCE_GROUP_NAME` |
| Variable | `APIM_INSTANCE_NAME` |

The Entra application for each environment must have a federated credential
whose subject uses the GitHub environment name:

```text
repo:<github-owner>/apiops-demo:environment:dev
repo:<github-owner>/apiops-demo:environment:prod
```

The identities need sufficient APIM permissions. The publisher identity also
needs permission to read the required Key Vault secrets.

## 1. Create a disposable migration branch

```bash
cd <path-to-apiops-demo>
git fetch origin --tags --prune
git switch main
git pull --ff-only
git switch -c demo/migration-YYYYMMDD demo-part2-start
git status
```

The branch should contain the original Toolkit implementation.

## 2. Inventory the Toolkit implementation

```bash
ls -1 configuration*.yaml
find .github/workflows -maxdepth 1 -type f | sort
find apimartifacts -type f | wc -l
cat package.json
```

Confirm that:

- `apimartifacts/` contains the existing APIM configuration.
- Toolkit extractor and publisher workflows are present.
- Environment overrides and developer portal dependencies are present.

## 3. Preserve the Toolkit files

```bash
mv configuration.extractor.yaml configuration.extractor.toolkit.yaml
mv configuration.dev.yaml configuration.dev.toolkit.yaml
mv configuration.prod.yaml configuration.prod.toolkit.yaml

cp package.json package.toolkit.json
cp package-lock.json package-lock.toolkit.json
```

These files provide a side-by-side migration reference and make the changes
reviewable.

## 4. Generate the APIOps CLI scaffold

```bash
npx -y @azure-tools/apiops-cli@1.0.5 init \
  --ci github-actions \
  --artifact-dir ./apimartifacts \
  --environments dev,prod \
  --non-interactive
```

Keep the existing `apimartifacts/` directory. The command generates the CLI
configuration, GitHub workflows, identity setup guide, and Copilot prompts.

## 5. Preserve the existing package dependencies

Restore the original package files, then add APIOps CLI:

```bash
cp package.toolkit.json package.json
cp package-lock.toolkit.json package-lock.json
npm install @azure-tools/apiops-cli@1.0.5 --save-exact
```

The resulting package must retain the developer portal dependencies:

```text
@azure/storage-blob
mime
yargs
```

Add `node_modules/` to `.gitignore` if it is not already present.

## 6. Translate the extractor configuration

Compare:

```text
configuration.extractor.toolkit.yaml
configuration.extractor.yaml
```

Translate Toolkit `subscriptionNames` to CLI `subscriptions`. Preserve the
managed subscription selection:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/extractor-config.schema.json
subscriptions:
  - <managed-subscription-resource-name>
```

APIOps CLI filter behavior:

- Omitted resource type: extract all resources of that type.
- Empty array: directly select no resources of that type.
- Named list: directly select the named resources.
- Referenced dependencies can be included transitively.

## 7. Translate the environment overrides

Compare each Toolkit override with its generated CLI counterpart:

```bash
code \
  configuration.dev.toolkit.yaml \
  configuration.dev.yaml \
  configuration.prod.toolkit.yaml \
  configuration.prod.yaml
```

Apply these translations:

| Toolkit convention | APIOps CLI convention |
|---|---|
| `apimServiceName` in the override | Remove it; the workflow supplies `--service-name` |
| `{#tokenName#}` | `{#[TOKEN_NAME]#}` |
| API entry containing only diagnostics | Add `properties: {}` |
| Environment-specific Azure resource IDs | Use existing GitHub secret and variable tokens |

Use these reusable token names where applicable:

```text
AZURE_SUBSCRIPTION_ID
RESOURCE_GROUP_NAME
APIM_INSTANCE_NAME
APP_INSIGHTS_LOGGER_KEY
ALLOWED_IP_ADDRESS
TEST_SECRET_VALUE
UNLIMITED_SUBSCRIPTION_PRIMARY_KEY
UNLIMITED_SUBSCRIPTION_SECONDARY_KEY
```

Keep the existing hexadecimal subscription artifact and override name.
APIOps CLI 1.0.5 publishes that subscription natively.

## 8. Configure the extractor workflow

Update `.github/workflows/run-apiops-extractor.yml` to:

1. Use Node.js 22.
2. Authenticate with `azure/login@v3` and GitHub OIDC.
3. Read `RESOURCE_GROUP_NAME` and `APIM_INSTANCE_NAME` from the selected GitHub
   environment.
4. Extract into `./apimartifacts`.
5. Use `--remove-stale`.
6. Remove the checked-out `apimartifacts/` directory before downloading the
   extracted artifact archive in the pull-request job.

Removing the checked-out directory is required because artifact
upload/download does not represent deleted files. Replacing the directory lets
stale-file deletions appear in the generated pull request.

## 9. Configure the publisher workflow

Update `.github/workflows/run-apiops-publisher.yml` to:

1. Use Node.js 22 and GitHub OIDC.
2. Select `dev` or `prod` through the GitHub environment.
3. Retrieve managed subscription keys from Key Vault.
4. Mask and map the keys to the override tokens.
5. Validate that every `{#[TOKEN_NAME]#}` has a runtime value.
6. Substitute tokens before running APIOps CLI.
7. Run a dry-run before every real publish.
8. Keep manual publishing behind `DRY_RUN_ONLY=false`.
9. Keep push-triggered real publishing behind
   `ENABLE_AUTOMATIC_PUBLISH=true`.

Use these push path filters without a leading `./`:

```yaml
paths:
  - 'apimartifacts/**'
  - 'configuration.*.yaml'
```

Do not add a separate subscription-key REST update. APIOps CLI 1.0.5 publishes
24-character hexadecimal product subscriptions and their keys through the
normal publish operation.

## 10. Validate the migration locally

```bash
npm install
npx apiops --version
git diff --check
git status --short
```

Expected CLI version:

```text
1.0.5
```

Review all generated and translated files before committing.

## 11. Commit and merge the migration

```bash
git add .
git commit -m "Migrate APIOps Toolkit workflows to APIOps CLI"
git push -u origin demo/migration-YYYYMMDD
gh pr create \
  --base main \
  --head demo/migration-YYYYMMDD \
  --title "Migrate APIOps Toolkit workflows to APIOps CLI" \
  --body "Preserves the existing APIM artifacts and environment behavior while replacing the Toolkit extractor and publisher with APIOps CLI 1.0.5."
```

Review the configuration translations, OIDC authentication, Key Vault token
handling, and publisher safety controls. Merge the pull request after review.

## 12. Disable the legacy Toolkit workflows

Disable the old Toolkit workflows only after the CLI workflows are merged:

```bash
gh workflow disable run-extractor.yaml
gh workflow disable run-publisher.yaml
gh workflow disable run-publisher-with-env.yaml
gh workflow list --all
```

Leave the developer portal workflows active.

## 13. Run extraction through GitHub Actions

```bash
gh workflow run run-apiops-extractor.yml \
  --ref main \
  -f ENVIRONMENT=dev \
  -f CONFIGURATION_YAML_PATH=configuration.extractor.yaml
```

The workflow should:

1. Authenticate through OIDC.
2. Extract the configured APIM resources.
3. Replace the artifact directory with the complete extraction output.
4. Create an `apim-extract-<run-id>` pull request.

Review additions, modifications, and stale-file deletions. Merge the generated
artifact pull request after approval.

## 14. Validate publishing without changing APIM

Run a full-artifact dev dry-run:

```bash
gh workflow run run-apiops-publisher.yml \
  --ref main \
  -f COMMIT_ID_CHOICE=publish-all-artifacts-in-repo \
  -f ENVIRONMENT=dev \
  -f DRY_RUN_ONLY=true
```

Confirm:

- Azure OIDC login succeeds.
- Key Vault secrets load successfully.
- All override tokens resolve.
- Both hexadecimal subscriptions are planned as `PUT` operations.
- There are no unexpected deletes or skipped resources.
- Both real publish steps are skipped.

The validated reference result was:

```text
150 PUT
169 PATCH
0 DELETE
0 SKIP
```

## 15. Perform the controlled dev publish

After reviewing the dry-run, intentionally publish the full artifact set:

```bash
gh workflow run run-apiops-publisher.yml \
  --ref main \
  -f COMMIT_ID_CHOICE=publish-all-artifacts-in-repo \
  -f ENVIRONMENT=dev \
  -f DRY_RUN_ONLY=false
```

Confirm that:

- `Dry-run validation (all artifacts)` succeeds.
- `Publish (all artifacts)` runs rather than being skipped.
- Both hexadecimal subscriptions are published as `PUT` operations.
- The run completes successfully.

Do not select the default incremental option for this migration validation.
The latest commit may contain only workflow or documentation changes and would
produce zero artifact operations.

## 16. Validate production safely

Before using `prod`:

1. Confirm the production federated credential subject.
2. Confirm production GitHub environment secrets and variables.
3. Run the full-artifact publisher with `DRY_RUN_ONLY=true`.
4. Review all planned operations.
5. Set `DRY_RUN_ONLY=false` only after explicit approval.

## 17. Reset for another rehearsal

The repository baseline is immutable at `demo-part2-start`. Create a new
disposable branch for each rehearsal.

First check the current branch:

```bash
git status --short
```

If the output is not clean, commit the work, preserve it with
`git stash push --include-untracked`, or remove only the confirmed disposable
generated files. Do not use a broad `git clean`.

Then reset:

```bash
cd <path-to-apiops-demo>
git switch main
git pull --ff-only
rm -rf node_modules
git switch -c demo/migration-YYYYMMDD-HHMM demo-part2-start
```

Removing `node_modules/` before switching prevents dependencies installed on
`main` from appearing as untracked files when the older baseline does not yet
contain the current `.gitignore` rule.

Do not delete the reusable GitHub environments, Entra applications, federated
credentials, Key Vault secrets, or Azure RBAC assignments.

## Completion checklist

- [ ] Toolkit files preserved for comparison.
- [ ] APIOps CLI 1.0.5 installed and locked.
- [ ] Extractor and override configurations translated.
- [ ] OIDC authentication configured for `dev` and `prod`.
- [ ] Key Vault subscription keys mapped to CLI override tokens.
- [ ] Publisher safety controls enabled.
- [ ] Legacy Toolkit workflows disabled.
- [ ] GitHub extraction completed and artifact PR reviewed.
- [ ] Full-artifact dev dry-run completed with no unexpected deletes or skips.
- [ ] Controlled full-artifact dev publish completed.
- [ ] Reset branch recreated successfully from `demo-part2-start`.
