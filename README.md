# apiops-demo

This repository demonstrates the
[Azure APIOps](https://azure.github.io/apiops/) process using APIOps CLI. It
also retains the developer portal migration pipelines so both APIM and portal
deployment examples can be demonstrated from one repository.

## APIOps CLI demo

The demonstration has two repeatable parts:

1. Build a greenfield APIOps CLI repository.
2. Migrate an existing APIOps Toolkit repository to APIOps CLI without
   rebuilding its APIM artifacts.

Use these runbooks:

- [Demo overview and safety controls](docs/apiops-cli-demo-runbook.md)
- [Part 1: Greenfield APIOps CLI](docs/apiops-cli-part1-runbook.md)
- [Part 2: Toolkit migration](docs/apiops-cli-part2-migration-runbook.md)

The migration repository pins `@azure-tools/apiops-cli` 1.0.5.

## APIOps CLI prerequisites

Create GitHub environments named `dev` and `prod`. Configure each environment
with:

| Type | Name | Purpose |
|---|---|---|
| Secret | `AZURE_CLIENT_ID` | Entra application client ID |
| Secret | `AZURE_TENANT_ID` | Entra tenant ID |
| Secret | `AZURE_SUBSCRIPTION_ID` | Target Azure subscription |
| Secret | `KEYVAULT_NAME` | Key Vault used for runtime secrets |
| Secret | `APP_INSIGHTS_LOGGER_KEY` | Application Insights logger value |
| Secret | `ALLOWED_IP_ADDRESS` | Policy-specific allowed IP value |
| Variable | `RESOURCE_GROUP_NAME` | APIM resource group |
| Variable | `APIM_INSTANCE_NAME` | APIM service name |

The APIOps CLI workflows use GitHub OIDC and do not require an Azure client
secret. Configure environment-scoped federated credentials:

```text
repo:<github-owner>/apiops-demo:environment:dev
repo:<github-owner>/apiops-demo:environment:prod
```

Grant the workflow identities the required APIM and Key Vault permissions.
Under **Settings > Actions > General > Workflow permissions**, allow GitHub
Actions to create pull requests.

## APIOps workflow

Portal-first changes:

1. Run `run-apiops-extractor.yml`.
2. Review and merge the generated artifact pull request.
3. Review the publisher dry-run.
4. Intentionally enable a real publish only after approval.

Code-first changes:

1. Create and review a pull request containing artifact or override changes.
2. Merge the approved pull request.
3. Review the publisher dry-run.
4. Intentionally enable a real publish only after approval.

Automatic real publishing is disabled unless the repository variable
`ENABLE_AUTOMATIC_PUBLISH` is explicitly set to `true`.

## APIM Developer Portal Deploy Steps

1. Update the *release.yaml* to reflect the stages you want to deploy to. 

2. By default the folder used to store the Developer Portal artifacts in this repo is `artifacts` as referenced in the [release-with-env.yaml file](.github/workflows/release-with-env.yaml#L22). If you would like to use a different folder name, you will need to update that file first.

3. Create url overwrite files for each environment in the format ***urls.{env}.json***. The contents of the file should be as

    ```json
    {
        uri: "https://uri1.com,https://uri2.com"
    }
    ```

    Update the existing uris in the snapshot in the file ***existingUrls.json***

    *Note*: This is an optional step and is only required if you want to overwrite the urls in the snapshot with the urls in the file.

4. Run the `capture.yaml` pipeline and provide a folder to store the artifacts in, the default is `artifacts`. That will pull in the Developer Portal artifacts that are in the current dev environment (this is set in the [capture.yaml](.github/workflows/capture.yaml#L15) file, so if you want to pull from a different environment update that). Once that is complete, you can see the PR that was created so you can merge it. Once that is merged the `release.yaml` pipeline will automatically trigger.
