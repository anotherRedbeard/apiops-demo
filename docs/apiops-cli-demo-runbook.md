# APIOps CLI Demo Runbook

This runbook documents the repeatable two-part APIOps demonstration:

1. Create a new APIOps CLI implementation from an empty repository.
2. Migrate an existing APIOps Toolkit implementation to APIOps CLI.

## Demo repositories

| Part | Repository | Local path |
|---|---|---|
| Greenfield APIOps CLI | `anotherRedbeard/apiops-cli-demo` | `/Users/andrewredman/src/apiops/apiops-cli-demo` |
| Toolkit migration | `anotherRedbeard/apiops-demo` | `/Users/andrewredman/src/apiops/apiops-demo` |

## Azure demo environments

| Environment | Subscription | Resource group | APIM service |
|---|---|---|---|
| Development/source | `ME-MngEnvMCAP811683-andrewredman-1` | `red-scus-apiopsdemo-rg-dev` | `red-apim-dev` |
| Production/target | `ME-MngEnvMCAP811683-andrewredman-2` | `red-scus-apiopsdemo-rg-prd` | `red-apim-prd` |

## Completed preparation

### 1. Create the greenfield repository

```bash
cd /Users/andrewredman/src/apiops
gh repo create anotherRedbeard/apiops-cli-demo \
  --public \
  --add-readme \
  --description "Repeatable APIOps CLI greenfield and migration demo" \
  --clone
```

### 2. Preserve the empty starting state

```bash
cd /Users/andrewredman/src/apiops/apiops-cli-demo
git tag demo-part1-start
git push origin demo-part1-start
git switch -c demo/rehearsal
```

The `demo-part1-start` tag provides a stable starting point for future
rehearsals. The `demo/rehearsal` branch contains disposable rehearsal work.

### 3. Inspect the initialization command

```bash
npx -y @azure-tools/apiops-cli@latest init --help
```

Important options:

- `--ci github-actions` generates GitHub Actions workflows.
- `--artifact-dir ./apim-artifacts` selects the artifact directory.
- `--environments dev,prod` creates configuration for both environments.
- `--non-interactive` uses the supplied options without prompting.

### 4. Initialize the repository

Interactive command used during the hands-on rehearsal:

```bash
cd /Users/andrewredman/src/apiops/apiops-cli-demo
npx -y @azure-tools/apiops-cli@latest init
```

Interactive selections:

- CI/CD provider: `GitHub Actions`
- Artifact directory: accepted `./apim-artifacts`
- Environments: `dev, prod`

The equivalent repeatable non-interactive command is:

```bash
npx -y @azure-tools/apiops-cli@latest init \
  --ci github-actions \
  --artifact-dir ./apim-artifacts \
  --environments dev,prod \
  --non-interactive
```

The command generated:

- `.github/workflows/run-apiops-extractor.yml`
- `.github/workflows/run-apiops-publisher.yml`
- `.github/prompts/` Copilot prompt files
- `APIOPS-WORKFLOW-IDENTITY-SETUP.md`
- `configuration.extractor.yaml`
- `configuration.dev.yaml`
- `configuration.prod.yaml`
- `package.json`
- `apim-artifacts/`

The generated `package.json` intentionally uses the latest APIOps CLI package.

### Understanding the generated Markdown files

The Markdown files do not run in GitHub Actions and are not required by the
`apiops` executable. They are checked-in guidance that makes configuration
repeatable for repository contributors.

#### `APIOPS-WORKFLOW-IDENTITY-SETUP.md`

This is the human-readable manual setup guide. It explains:

- Creating an Entra application and service principal.
- Assigning least-privilege Azure RBAC.
- Creating GitHub OIDC federated credentials.
- Creating GitHub environments.
- Adding repository and environment secrets.
- Verifying the extractor workflow and pull-request permissions.

#### `.github/prompts/apiops-setup-workflow-identity.prompt.md`

This is a Copilot prompt file for performing the same identity setup
interactively. Its front matter declares Agent mode, and its instructions force
the agent to proceed one step at a time, confirm values, stop on errors, and
avoid using a stored client secret.

#### `.github/prompts/apiops-configure-filter.prompt.md`

This prompt helps build `configuration.extractor.yaml` from the live APIM
resource inventory. It reinforces these important filter semantics:

- An omitted resource type means extract all resources of that type.
- An empty array means extract none of that type.
- A list means extract only matching names or patterns.
- Referenced dependencies can be included transitively.

#### `.github/prompts/apiops-configure-overrides.prompt.md`

This prompt helps build `configuration.{environment}.yaml` files. It guides the
user through:

- Discovering values that differ between environments.
- Choosing literals, pipeline tokens, or Key Vault references.
- Preserving the same artifact set across environments.
- Validating token names and override structure.

These prompt files can be opened in VS Code and invoked through GitHub Copilot
Agent mode. They can also serve as readable process documentation even when
Copilot is not used.

In VS Code, generated prompt files are exposed as reusable Copilot Chat prompt
commands, such as `/apiops-configure-filter` and
`/apiops-configure-overrides`. The assistant follows the checked-in prompt's
step-by-step rules, asks for confirmation, inspects the repository or live
Azure resources, and edits the actual YAML configuration. The APIOps CLI and
GitHub Actions workflows never execute the prompt files.

### 4a. Configure the greenfield extraction filter

The live source APIM inventory was queried rather than relying on old local
artifacts:

```bash
az apim api list \
  --subscription 0272c02b-5a38-4b6b-86e6-dcc4ff2ff0e8 \
  --resource-group red-scus-apiopsdemo-rg-dev \
  --service-name red-apim-dev \
  --query '[].{name:name,displayName:displayName,path:path}' \
  -o table
```

`echo-api` was selected for the focused demo. The active filter is:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/extractor-config.schema.json

apis:
  - echo-api
backends: []
namedValues: []
products: []
tags: []
versionSets: []
loggers: []
diagnostics: []
groups: []
policyFragments: []
gateways: []
schemas: []
subscriptions: []
policies: []
policyRestrictions: []
documentations: []
workspaces: []
```

Filter behavior to explain during the demo:

- Omitted key: include all resources of that type.
- Empty array: directly select none of that type.
- Named list: directly select matching resources.
- Transitive dependency resolution can still include a referenced resource even
  when its top-level type is an empty array.
- `--no-transitive` disables transitive dependency inclusion.

### 4b. Configure the production override

Artifact inspection found that the `echo-api` policy references the transitive
named value `environment`. The extracted development value is
`https://www.bing-dev.com`. The production value is a safe, non-secret literal,
so it is committed directly instead of using a pipeline token:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/override-config.schema.json

namedValues:
  - name: environment
    properties:
      displayName: environment
      value: "https://www.bing.com"
```

The API service URL is shared by both environments, so it does not require an
override. The generated development override template remains unchanged.

During rehearsal, the generated development template caused a publisher
failure because its commented example contained `{#[DB_Connection_String]#}`.
The generated workflow's token scanner matched the token inside the comment and
reported a missing secret. Because dev needs no overrides, the file was reduced
to:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/override-config.schema.json
```

### 4c. Generated workflow corrections

Two scaffold behaviors were found during rehearsal:

1. The publisher path filter used `'./apim-artifacts/**'`, which did not match
   the artifact paths in the extraction PR. It was corrected to:

   ```yaml
   paths:
     - 'apim-artifacts/**'
     - 'configuration.*.yaml'
   ```

2. The token validation step scans commented examples in override files. Remove
   unused example tokens from generated configuration files, or replace an
   unused override file with only its schema declaration.

After the artifact PR merged, the publisher was run manually for dev with:

- `COMMIT_ID_CHOICE=publish-all-artifacts-in-repo`
- `ENVIRONMENT=dev`

The workflow completed successfully after the unused example token was removed.

### 5. Configure secretless GitHub authentication

An Entra application named `apiops-cli-demo-github` was created with federated
credentials for these GitHub environments:

- `dev`
- `prod`

No Azure client secret was created or stored.

The service principal has:

- `Reader` on each demo resource group.
- `API Management Service Contributor` on `red-apim-dev`.
- `API Management Service Contributor` on `red-apim-prd`.

The GitHub repository contains:

- Repository secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`
- `dev` environment secrets:
  - `AZURE_SUBSCRIPTION_ID`
  - `APIM_RESOURCE_GROUP_DEV`
  - `APIM_SERVICE_NAME_DEV`
- `prod` environment secrets:
  - `AZURE_SUBSCRIPTION_ID`
  - `APIM_RESOURCE_GROUP_PROD`
  - `APIM_SERVICE_NAME_PROD`

## Current state

- `main` still represents the original empty repository.
- `demo-part1-start` identifies the reusable greenfield baseline.
- `demo/rehearsal` contains a committed, pushed reference copy of the generated
  APIOps CLI scaffold.
- `demo/hands-on` was created from `demo-part1-start`.
- The interactive `apiops init` command has been completed on `demo/hands-on`;
  its generated files are currently uncommitted.
- No APIM configuration has been extracted or published by the new repository.
- The legacy `apiops-demo` repository has not yet been modified.

## Planned greenfield walkthrough

1. Review every file produced by `apiops init`.
2. Configure a narrow extraction filter for one demo API.
3. Run `apiops extract` locally and inspect the artifact layout.
4. Commit the initialized repository and extracted artifacts.
5. exercise the generated extractor workflow and pull-request flow.
6. Run `apiops publish --dry-run` against the target APIM service.
7. Publish a controlled change and verify it in APIM.
8. Restore the target and repository to their baseline state.

## Toolkit migration walkthrough

### 1. Preserve the Toolkit baseline

The original Toolkit implementation remains on `main`. A tag and disposable
branch isolate each migration rehearsal:

```bash
git switch main
git tag demo-part2-start
git push origin demo-part2-start
git switch -c demo/migration-rehearsal
```

For another rehearsal, create a fresh branch from the same tag:

```bash
git switch main
git branch -D demo/migration-rehearsal
git switch -c demo/migration-rehearsal demo-part2-start
```

### 2. Generate the CLI scaffold beside the Toolkit files

`apiops init` fails when configuration files already exist. Do not use
`--force` directly against a Toolkit repository because it replaces meaningful
configuration and package files. Rename the Toolkit configuration files first,
then generate clean CLI files for comparison:

```bash
mv configuration.extractor.yaml configuration.extractor.toolkit.yaml
mv configuration.dev.yaml configuration.dev.toolkit.yaml
mv configuration.prod.yaml configuration.prod.toolkit.yaml
cp package.json package.toolkit.json
cp package-lock.json package-lock.toolkit.json

npx -y @azure-tools/apiops-cli@latest init \
  --ci github-actions \
  --artifact-dir ./apimartifacts \
  --environments dev,prod \
  --non-interactive
```

Keep the existing `apimartifacts/` directory. The APIOps CLI publisher is
designed to consume the existing Toolkit artifact format.

### 3. Translate the extraction filter

The Toolkit field `subscriptionNames` was renamed to `subscriptions`:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/extractor-config.schema.json

subscriptions:
  - 66ce4b511f9b910053070002
```

### 4. Translate environment overrides

Apply these changes while comparing each generated file with its `.toolkit`
copy:

- Remove `apimServiceName`; the CLI receives the service through
  `--service-name`.
- Change Toolkit tokens from `{#tokenName#}` to `{#[TOKEN_NAME]#}`.
- Add `properties: {}` to API entries that contain only nested diagnostics.
  The current CLI override schema requires an active `properties` object.
- Validate both files against the APIOps CLI override schema before publishing.

The migrated files use GitHub secret names directly, including
`AZURE_SUBSCRIPTION_ID`, `APIM_RESOURCE_GROUP_DEV`,
`APIM_RESOURCE_GROUP_PROD`, `APIM_SERVICE_NAME_DEV`, and
`APIM_SERVICE_NAME_PROD`.

### 5. Preserve Key Vault subscription-key replacement

The production subscription override retains tokens rather than storing keys:

```yaml
primaryKey: "{#[UNLIMITED_SUBSCRIPTION_PRIMARY_KEY]#}"
secondaryKey: "{#[UNLIMITED_SUBSCRIPTION_SECONDARY_KEY]#}"
```

After `azure/login`, the publisher retrieves
`APIM-Unlimited-Subscription-Primary-Key` and
`APIM-Unlimited-Subscription-Secondary-Key` from the environment's Key Vault.
The workflow masks the values and maps them to:

- `UNLIMITED_SUBSCRIPTION_PRIMARY_KEY`
- `UNLIMITED_SUBSCRIPTION_SECONDARY_KEY`

Token validation first checks GitHub environment secrets and then checks values
loaded into the runtime environment. Key Vault retrieval runs for both
environments so future environment-specific secrets do not require a workflow
structure change.

APIOps CLI 1.0.4 treats every product-scoped subscription with a 24-character
hexadecimal resource name as an APIM-generated subscription and skips it during
publish. The existing managed subscription
`66ce4b511f9b910053070002` matches that heuristic even though the repository
explicitly manages its primary and secondary keys.

Keep the original hexadecimal artifact and override names so extraction remains
stable. After a successful CLI publish, the workflow performs an explicit
`az rest` update against that existing subscription. It uses the already
masked Key Vault values, reads the existing target subscription, and preserves
its display name, scope, owner, state, and tracing setting while replacing only
the primary and secondary keys. A dry-run-only workflow execution verifies
that the target subscription exists but does not update its keys.

This is a compatibility workaround for the CLI's false-positive
auto-generated-subscription detection. File an upstream issue against
`Azure/apiops-cli` when GitHub organization SAML authorization is available.

### 6. Merge package dependencies

The generated package must not replace the existing developer-portal package.
Restore the baseline package files, then add the CLI:

```bash
git show HEAD:package.json > package.json
git show HEAD:package-lock.json > package-lock.json
npm install @azure-tools/apiops-cli@latest --save
npm pkg set 'dependencies.@azure-tools/apiops-cli=latest'
npm install
```

The final package retains `@azure/storage-blob`, `mime`, and `yargs`, and adds
`@azure-tools/apiops-cli` with the manifest value `latest`. The lock file pins
the resolved release used by the rehearsal. `npm audit --omit=dev` reported no
runtime dependency vulnerabilities; do not run `npm audit fix --force` during
the demo because it can make unrelated dependency changes.

Add `node_modules/` to `.gitignore`.

### 7. Correct the generated publisher trigger

As in the greenfield scaffold, remove the leading `./` from the artifact path:

```yaml
paths:
  - 'apimartifacts/**'
  - 'configuration.*.yaml'
```

### 8. Replace client-secret authentication with GitHub OIDC

Reuse the existing environment-specific registrations so their Azure RBAC
assignments remain unchanged:

| Environment | App registration | Client ID | Service-principal object ID |
|---|---|---|---|
| dev | `spAPIOpsDemoDev` | `733d9303-bfc0-4463-a6c6-519fa26ce397` | `72d8523b-27b1-4706-b3b9-5b9c2f36c63b` |
| prod | `spAPIOpsDemoPrd` | `84c9ad8f-123c-4af8-8741-ab1ebce74dc7` | `404b4201-2ae4-4637-995e-6f4fb72af2fe` |

Add one environment-scoped GitHub federated credential to each registration:

- Dev subject:
  `repo:anotherRedbeard@34103220/apiops-demo@601646614:environment:dev`
- Prod subject:
  `repo:anotherRedbeard@34103220/apiops-demo@601646614:environment:prod`
- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`

The generated CLI workflows use `azure/login@v3` with `AZURE_CLIENT_ID`,
`AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. They do not use
`AZURE_CLIENT_SECRET`. Keep that secret temporarily because the legacy
workflows still use it during the side-by-side migration.

### 9. Reuse existing GitHub environment variables

The `dev` and `prod` GitHub environments already define:

- `RESOURCE_GROUP_NAME`
- `APIM_INSTANCE_NAME`

Do not create duplicate resource-group or service-name secrets. The extractor
maps these variables to `APIM_RESOURCE_GROUP` and `APIM_SERVICE_NAME`. The
publisher exposes them as job environment values and also maps
`TEST_SECRET_VALUE` to `RESOURCE_GROUP_NAME`, preserving the legacy workflow's
replacement behavior.

The migrated override tokens use the reusable names:

- `{#[RESOURCE_GROUP_NAME]#}`
- `{#[APIM_INSTANCE_NAME]#}`
- `{#[TEST_SECRET_VALUE]#}`
- Existing GitHub secret names for Azure IDs, App Insights, and allowed IP
- Runtime values loaded from Key Vault for the subscription keys

### Remaining migration validation

1. Commit and push the publisher safety and subscription-key workaround.
2. Run the safeguarded GitHub Actions dry-run after the workflow is available
   on the default branch.
3. Perform a controlled publish and verify the managed subscription keys.
4. Test extraction with the translated `subscriptions` filter.
5. Recreate the branch from `demo-part2-start` to verify the reset procedure.

The local full-artifact CLI dry-run completed successfully against dev:

- 135 creates or updates
- 0 patches
- 0 deletes
- 2 skipped auto-generated product subscriptions

The skip result is expected until the upstream behavior changes; the explicit
post-publish REST step handles the one subscription whose keys are managed.

## Reset strategy

### Greenfield repository

The repository can be returned to the starting content by creating a new
rehearsal branch from `demo-part1-start`. Do not remove the OIDC identity or
GitHub environments between demonstrations; they contain no client secret and
are reusable prerequisites.

```bash
git switch main
git switch -c demo/rehearsal-YYYYMMDD demo-part1-start
```

### Migration repository

All migration work must remain on a dedicated branch. The `main` branch remains
the legacy Toolkit baseline, so a new migration branch can be created for every
rehearsal.

### Azure API Management

Before a real publish, capture or confirm the target baseline. Use dry-run
first. After the rehearsal, republish the baseline artifacts or reverse the
single controlled demo change. Do not use `--delete-unmatched` during the demo
unless its dry-run output has been explicitly reviewed.
