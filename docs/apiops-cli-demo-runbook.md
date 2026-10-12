# APIOps CLI Demo Runbook

This document is the operator index for the two-part APIOps demonstration. The
step-by-step procedures are maintained in separate runbooks so presentation
steps stay concise and troubleshooting history does not become part of the
demo.

## Authoritative procedures

| Demo | Runbook | Starting point |
|---|---|---|
| Part 1: Greenfield APIOps CLI | [apiops-cli-part1-runbook.md](apiops-cli-part1-runbook.md) | `demo-part1-start` |
| Part 2: Toolkit migration | [apiops-cli-part2-migration-runbook.md](apiops-cli-part2-migration-runbook.md) | `demo-part2-start` |

Use those runbooks during preparation and rehearsal. This document records
only the shared model, prerequisites, safety rules, and verified outcomes.

## Operating model

Both the legacy Toolkit and APIOps CLI use the same core APIOps flow:

```text
APIM source
    |
    v
Extract configuration
    |
    v
Git branch and pull request
    |
    v
Review and merge
    |
    v
Dry-run validation
    |
    v
Publish to target APIM
```

APIOps CLI modernizes the tooling and generated workflows. It does not replace
the Git-based review and promotion model.

## Shared prerequisites

- Node.js 22.
- Azure CLI for local validation.
- GitHub CLI for repeatable workflow and pull-request commands.
- GitHub environments named `dev` and `prod`.
- Environment-scoped Entra federated credentials.
- APIM and Key Vault permissions for the workflow identities.
- GitHub Actions permission to create pull requests.

APIOps CLI workflow secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
KEYVAULT_NAME
APP_INSIGHTS_LOGGER_KEY
ALLOWED_IP_ADDRESS
```

APIOps CLI workflow variables:

```text
RESOURCE_GROUP_NAME
APIM_INSTANCE_NAME
```

No Azure client secret is required by the APIOps CLI extractor or publisher.

## Workflow safety

The publisher always runs a dry-run before a real publish.

Manual workflow behavior:

| `DRY_RUN_ONLY` | Result |
|---|---|
| `true` | Validate only; real publish steps are skipped |
| `false` | Validate first, then publish |

Push-triggered behavior:

| `ENABLE_AUTOMATIC_PUBLISH` | Result |
|---|---|
| Missing or not `true` | Validate only |
| `true` | Validate, then publish |

Additional rules:

- Do not use `--delete-unmatched` during the demo.
- Use `publish-all-artifacts-in-repo` for full migration validation.
- Use the incremental option only when the last commit contains the intended
  artifact changes.
- Do not run `npm audit fix --force` as part of the demo.
- Never expose Key Vault values in logs or documentation.

## Verified migration outcome

The reference migration uses APIOps CLI 1.0.5.

The full-artifact dev dry-run produced:

```text
150 PUT
169 PATCH
0 DELETE
0 SKIP
```

Both 24-character hexadecimal product subscriptions were planned as native
`PUT` operations.

The controlled full-artifact dev publish then completed successfully. Both
subscriptions were published through the normal APIOps CLI operation; no
post-publish REST workaround was required.

## Presentation sequence

1. Explain the extract, Git, review, and publish operating model.
2. Run or summarize Part 1 from the greenfield baseline.
3. Run Part 2 from the Toolkit baseline.
4. Compare the preserved Toolkit files with the generated CLI files.
5. Highlight the schema and token translations.
6. Show OIDC, Key Vault token handling, and publisher safety controls.
7. Show the extractor-generated artifact pull request.
8. Show the successful full dry-run and controlled dev publish.
9. Reset by creating a new disposable branch from the appropriate baseline
   tag.

## Reset commands

Greenfield:

```bash
cd <path-to-apiops-cli-demo>
git switch main
git pull --ff-only
rm -rf node_modules
git switch -c demo/live-YYYYMMDD-HHMM demo-part1-start
```

Toolkit migration:

```bash
cd <path-to-apiops-demo>
git switch main
git pull --ff-only
rm -rf node_modules
git switch -c demo/migration-YYYYMMDD-HHMM demo-part2-start
```

Removing `node_modules/` prevents dependencies installed on `main` from
appearing as untracked files when switching to an older baseline. The tags
reset repository content only. Keep GitHub environments, Entra applications,
federated credentials, Key Vault secrets, and Azure RBAC assignments as
reusable prerequisites.
