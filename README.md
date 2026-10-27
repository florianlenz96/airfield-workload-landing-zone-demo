# Meter Readings API

Smart meters send their readings here. A small .NET 10 minimal API, part of the talk **"Azure Landing Zones Without the Overwhelm"**.

This repository is what an application team writes: **code, the Azure resources it needs, and a ten-line workflow.** Network, identity, permissions, Terraform state and the deployment pipeline come from the [platform](https://github.com/florianlenz96/airfield-application-landing-zone-demo).

```
src/        the API
tests/      unit tests
infra/      the app's Azure resources (Terraform), deployed into its landing zone
.github/    calls the platform's pipeline template
```

## How it gets to Azure

1. The platform team merges `landing-zones/meter-readings.tfvars` in the platform repository.
2. This repository gets a GitHub environment `prod` with everything it needs: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `TFSTATE_*` and `LANDING_ZONE`.
3. A push to `main` runs the platform's pipeline: build and test → `terraform apply` in `infra/` → container image → App Service → smoke test.

No secrets, no connection strings, no tickets.

## What `infra/` creates

| Resource | Notes |
|---|---|
| Resource group | Tagged from the landing zone, as the platform's policy requires |
| Storage account + private endpoint | Public access disabled, no shared keys. The endpoint sits in the landing zone's `private-endpoints` subnet; its DNS record goes into the hub's zone. |
| Container registry (Basic) | The pipeline pushes, the app pulls with its managed identity |
| App Service (Linux, B1) | VNet integration into the landing zone's `apps` subnet, all outbound traffic through the landing zone's routes |
| Managed identity | Storage Blob Data Contributor on the storage account, AcrPull on the registry |

## Try the API

```bash
API=https://<webapp-name>.azurewebsites.net   # printed in the workflow summary

curl -s $API/health
curl -s -X POST $API/readings -H 'content-type: application/json' \
  -d '{"meterId":"meter-0001","timestamp":"2026-11-12T08:00:00Z","kwh":1.42}'
curl -s $API/readings/meter-0001
```

## Run locally

```bash
az login
dotnet run --project src/MeterReadings.Api \
  --Storage:BlobEndpoint=https://<a-storage-account-you-can-reach>.blob.core.windows.net/
```

## Reset

*Actions → deploy → Run workflow* with **destroy** checked removes the app's Azure resources. The landing zone stays.
