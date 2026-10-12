# APIOps CLI Part 1: Greenfield Demo Runbook

This is the complete operator sequence for the greenfield APIOps CLI demo.

## Demo resources

| Item | Value |
|---|---|
| Repository | `<github-owner>/apiops-cli-demo` |
| Local path | `<path-to-apiops-cli-demo>` |
| Starting tag | `demo-part1-start` |
| APIOps CLI | `1.0.5` |
| Source subscription | `<dev-subscription-id>` |
| Source resource group | `<dev-resource-group>` |
| Source APIM | `<dev-apim-service>` |
| Target subscription | `<prod-subscription-id>` |
| Target resource group | `<prod-resource-group>` |
| Target APIM | `<prod-apim-service>` |

## 1. Start from the empty baseline

Create a new disposable branch. Use a unique branch name for each rehearsal:

```bash
cd <path-to-apiops-cli-demo>
git fetch origin --tags --prune
git switch main
git pull --ff-only origin main
git switch -c demo/live-YYYYMMDD demo-part1-start
git status
```

Expected result: a clean branch containing the original repository baseline.
The existing GitHub environments, OIDC application, Azure RBAC, and completed
reference implementation remain available.

## 2. Show the CLI initialization command

```bash
npx -y @azure-tools/apiops-cli@1.0.5 init --help
```

Explain:

- One CLI now handles repository initialization, extraction, and publishing.
- `init` generates CI/CD workflows, configuration templates, documentation,
  and reusable Copilot prompt files.

## 3. Initialize the repository

```bash
npx -y @azure-tools/apiops-cli@1.0.5 init
```

Choose:

- CI/CD provider: `GitHub Actions`
- Artifact directory: `./apim-artifacts`
- Environments: `dev, prod`

Equivalent non-interactive command:

```bash
npx -y @azure-tools/apiops-cli@1.0.5 init \
  --ci github-actions \
  --artifact-dir ./apim-artifacts \
  --environments dev,prod \
  --non-interactive
```

## 4. Review the generated files

```bash
find . -maxdepth 3 -type f \
  -not -path './.git/*' \
  -not -path './node_modules/*' \
  | sort
```

Explain these files:

| File | Purpose |
|---|---|
| `.github/workflows/run-apiops-extractor.yml` | Extracts APIM configuration and creates a pull request |
| `.github/workflows/run-apiops-publisher.yml` | Validates and publishes approved artifacts |
| `.github/prompts/` | Reusable Copilot Agent-mode setup and configuration prompts |
| `APIOPS-WORKFLOW-IDENTITY-SETUP.md` | Human-readable OIDC and GitHub setup guide |
| `configuration.extractor.yaml` | Controls which APIM resources are extracted |
| `configuration.dev.yaml` | Development-specific overrides |
| `configuration.prod.yaml` | Production-specific overrides |
| `apim-artifacts/` | Git-managed APIM configuration |
| `package.json` | Pins the repository's APIOps CLI dependency policy |

The prompt files guide contributors but are not executed by APIOps CLI or
GitHub Actions.

## 5. Configure focused extraction

Replace `configuration.extractor.yaml` with:

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

Explain the filter semantics:

- Omitted key: extract all resources of that type.
- Empty array: directly select none.
- Named list: directly select matching resources.
- Referenced dependencies can still be extracted transitively.
- `--no-transitive` disables transitive dependency inclusion.

## 6. Run local extraction

Confirm the Azure CLI is using the development subscription:

```bash
az account set --subscription <dev-subscription-id>
az account show --query '{name:name,id:id}' -o table
```

Run the extractor:

```bash
npx apiops \
  --subscription-id <dev-subscription-id> \
  extract \
  --resource-group <dev-resource-group> \
  --service-name <dev-apim-service> \
  --output ./apim-artifacts \
  --filter configuration.extractor.yaml \
  --remove-stale
```

Inspect the result:

```bash
find apim-artifacts -type f | sort
```

Expected result:

- `echo-api` and its sub-resources are extracted.
- The `environment` named value is also extracted because an API policy
  references it transitively.

## 7. Configure environment overrides

Development needs no override. Reduce `configuration.dev.yaml` to:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/override-config.schema.json
```

This avoids the generated example token being detected inside a comment.

Set `configuration.prod.yaml` to:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/apiops-cli/main/schemas/v1/override-config.schema.json

namedValues:
  - name: environment
    properties:
      displayName: environment
      value: "https://www.bing.com"
```

Explain:

- The artifact contains the development value.
- The production override changes only the environment-specific value.
- The API and artifact structure remain identical across environments.

## 8. Correct the generated publisher trigger

In `.github/workflows/run-apiops-publisher.yml`, change:

```yaml
- './apim-artifacts/**'
```

to:

```yaml
- 'apim-artifacts/**'
```

The leading `./` does not match artifact-only extraction pull-request paths.

## 9. Explain GitHub OIDC

The reusable setup already exists:

- Entra application: `<greenfield-oidc-app>`
- Client ID: stored as the `AZURE_CLIENT_ID` GitHub environment secret
- GitHub environments: `dev`, `prod`
- Authentication: GitHub environment-scoped federated credentials
- No Azure client secret is stored

The workflows use:

```yaml
permissions:
  id-token: write
  contents: read
```

and:

```yaml
- uses: azure/login@v3
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## 10. Review the local demo result

```bash
git status --short
git diff -- configuration.extractor.yaml configuration.dev.yaml configuration.prod.yaml
```

Talking points:

- The implementation started from an empty repository.
- The CLI generated the repeatable structure.
- Extraction produced reviewable files rather than directly changing another
  APIM environment.
- Environment differences remain explicit and version controlled.

## 11. Demonstrate the GitHub pull-request flow

The completed reference implementation is on `main`. The live scratch branch
does not need to be merged during every presentation.

Show the extraction pull request and workflow history:

```bash
gh pr view 2 --repo <github-owner>/apiops-cli-demo --web
gh run list --repo <github-owner>/apiops-cli-demo --limit 10
```

Explain:

1. The extractor workflow authenticated through OIDC.
2. It extracted the configured resources.
3. It created PR #2 containing the APIM artifact changes.
4. Merging the reviewed artifacts triggered the publisher.
5. Publisher dry-runs were validated before real dev and prod publishing.

If running the existing extractor workflow live:

```bash
gh workflow run run-apiops-extractor.yml \
  --repo <github-owner>/apiops-cli-demo \
  --ref main \
  -f ENVIRONMENT=dev \
  -f CONFIGURATION_YAML_PATH=configuration.extractor.yaml
```

Watch the run:

```bash
gh run list \
  --repo <github-owner>/apiops-cli-demo \
  --workflow run-apiops-extractor.yml \
  --limit 5
```

Use the completed historical run if time or network conditions make a live
workflow impractical.

## 12. Demonstrate publishing safely

For a manual publisher run, use:

- `COMMIT_ID_CHOICE=publish-all-artifacts-in-repo`
- `ENVIRONMENT=dev` first
- Production only after confirming the target baseline

Show the workflow:

```bash
sed -n '1,240p' .github/workflows/run-apiops-publisher.yml
```

Explain that the workflow:

1. Authenticates with OIDC.
2. Resolves environment-specific secrets and variables.
3. Substitutes override tokens.
4. Runs `apiops publish --dry-run`.
5. Publishes only after validation succeeds.

The completed reference workflow was successfully validated against both
development and production.

## 13. Live-demo safety

- Do not use `--delete-unmatched`.
- Do not run `npm audit fix --force`.
- Use dry-run before real publishing.
- Show completed workflow history if there is insufficient time for Azure
  operations.
- Do not delete OIDC identities, GitHub environments, or RBAC assignments;
  they are reusable prerequisites.

## 14. Reset after the demo

The disposable branch can be abandoned. For another rehearsal:

```bash
cd <path-to-apiops-cli-demo>
git switch main
rm -rf node_modules
git switch -c demo/live-YYYYMMDD-HHMM demo-part1-start
```

The `demo-part1-start` tag remains the immutable empty baseline. The completed
implementation remains on `main`.
