# AWS Lambda (Container) API Deployment — Design

**Date:** 2026-07-04
**Scope:** Deploy `apps/api` (Bun + Elysia) to AWS Lambda as a container image, with MongoDB Atlas, fronted by API Gateway, provisioned by AWS CDK, deployed by GitHub Actions via OIDC.
**Status:** Approved (pending spec review)

## Goal

Give the API a public HTTPS URL backed by a hosted database, so the mobile app can point `API_BASE_URL` at a real deployment (unblocking a genuinely installable APK). Deploy automatically on push to `main`.

## Locked decisions

| Decision | Choice |
| --- | --- |
| Runtime bridge | AWS Lambda Web Adapter (LWA) — run existing Elysia HTTP server unchanged |
| Database | MongoDB Atlas, **provisioned via CDK** (`awscdk-resources-mongodbatlas`), M0 free tier |
| Front door | API Gateway HTTP API (v2), Lambda proxy integration |
| IaC | AWS CDK (TypeScript), standalone `infra/` dir on Node/npm toolchain |
| Secrets | AWS Secrets Manager, fetched by the app at cold start (no plaintext in env/template) |
| CI auth | GitHub OIDC → repo-scoped IAM deploy role |
| Region / Account | `us-east-1` / `318205107378` |
| Local creds | AWS profile `dsylvesteriii` (CI uses the OIDC role) |
| Deploy trigger | Push to `main` (paths `apps/api/**`, `infra/**`) + `workflow_dispatch` |

## Current state (verified)

- `apps/api` = `@bjj/api`, Elysia on Bun. `src/index.mts` builds the app and calls `.listen(env.port)`; Mongo client connects at module load with `await client.connect()` + `ensureIndexes()`.
- Config via `loadEnv(source = process.env)` in `src/config/env.mts` (TypeBox-validated): `PORT`, `MONGODB_URI`, `MONGODB_DB`, plus Auth0 + bypass values read elsewhere.
- Health at `/health`, readiness at `/ready` (pings Mongo). CORS enabled (`cors()`).
- Data persisted in Mongo collection `openMats` (DB `bjj_open_mat`); other collections: `users`, `gyms`, `rsvps`, `checkins`, `favorites`, `notifications`. Seeded via `bun run seed`.
- Local toolchain confirmed: AWS CLI 2.33, CDK 2.1124, Docker 29.5, profile `dsylvesteriii` → account `318205107378`.

## Architecture

```
Flutter APK ─► API Gateway (HTTP API v2) ─► Lambda (container image)
                                              │  LWA extension → Bun/Elysia on :3100
                                              ├─► MongoDB Atlas (SRV / TLS)
                                              └─► Secrets Manager (fetched at cold start)
```

Data flow: request → API Gateway → Lambda (LWA proxies to the Bun HTTP server on `localhost:3100`) → Elysia routes → Mongo Atlas over TLS. Secrets are fetched once per execution environment at cold start; the Mongo client and secrets are reused across warm invocations because LWA keeps the process alive.

## Components

### 1. App — secrets bootstrap (`apps/api/src/config/secrets.mts`)
- Exports `async function resolveEnv(): Promise<Record<string,string|undefined>>`.
- If `APP_SECRET_ARN` is set: fetch the secret JSON via `@aws-sdk/client-secrets-manager` (`GetSecretValue`), parse, return `{ ...process.env, ...secretJson }`. Else return `process.env` unchanged.
- Secret JSON keys: `MONGODB_URI`, `AUTH0_CLIENT_SECRET`, `AUTH_BYPASS_SECRET` (and any other sensitive values). Non-secret config (`MONGODB_DB`, `AUTH0_DOMAIN`, `AUTH0_AUDIENCE`, `PORT`) stays as plain Lambda env vars.
- `index.mts` change: `const env = loadEnv(await resolveEnv());` (was `loadEnv()`). Local dev (no `APP_SECRET_ARN`) behaves exactly as today.
- Add dependency `@aws-sdk/client-secrets-manager` to `apps/api`.

### 2. App — container image (`apps/api/Dockerfile`, `.dockerignore`)
```dockerfile
FROM oven/bun:1.3.12
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter
ENV PORT=3100 \
    AWS_LWA_PORT=3100 \
    AWS_LWA_READINESS_CHECK_PATH=/health
WORKDIR /app
COPY . .
RUN bun install --frozen-lockfile --production || bun install --production
CMD ["bun", "src/index.mts"]
```
- The image builds from the monorepo so workspace deps (`@bjj/contract`) resolve; the CDK `DockerImageAsset` build context + Dockerfile path are set accordingly (context = repo root or `apps/api` with build args — resolved in the plan).
- `.dockerignore` excludes `node_modules`, `.git`, `apps/mobile`, `build/`, `.env`, etc.

### 3. Infra — CDK (`infra/`, Node/npm, TypeScript)
Standalone directory (own `package.json`, `cdk.json`, `tsconfig.json`), NOT a Bun workspace, to avoid Bun/CDK toolchain friction. Deps: `aws-cdk-lib`, `constructs`, `awscdk-resources-mongodbatlas`. `cdk.json` app: `npx ts-node --prefer-ts-exts bin/infra.ts`.

Stacks:
- **`GithubOidcStack`** — `iam.OpenIdConnectProvider` for `token.actions.githubusercontent.com` + an `iam.Role` with a trust policy scoped to `repo:<owner>/<repo>:ref:refs/heads/main` (and the repo's environment), granting the permissions CDK deploy needs (CloudFormation, ECR, Lambda, apigatewayv2, IAM PassRole, Secrets Manager, S3 CDK assets, and the Atlas CFN types). Deployed once locally with profile `dsylvesteriii`. Outputs the role ARN.
- **`AtlasStack`** — `awscdk-resources-mongodbatlas` constructs: Project, Cluster (M0, region `US_EAST_1`), DatabaseUser (SCRAM), ProjectIpAccessList (`0.0.0.0/0` — Lambda without VPC has dynamic egress; access is gated by SCRAM creds + TLS). Reads the Atlas API key from the `cfn/atlas/profile/default` Secrets Manager secret (the extension's convention). Outputs the cluster's SRV connection string base.
- **`ApiStack`** — `secretsmanager.Secret` (app secret: `MONGODB_URI` assembled from Atlas output + DB user creds, `AUTH0_CLIENT_SECRET`, `AUTH_BYPASS_SECRET`); `lambda.DockerImageFunction` (`DockerImageCode.fromImageAsset(...)`, memory 512 MB, timeout 20 s, env: `MONGODB_DB`, `AUTH0_DOMAIN`, `AUTH0_AUDIENCE`, `APP_SECRET_ARN`, `AWS_LWA_*`); `secret.grantRead(fn)`; `apigatewayv2.HttpApi` with a default-route `HttpLambdaIntegration` → the function. Outputs the invoke URL.

### 4. CI — `.github/workflows/api-deploy.yml`
- Triggers: `push` to `main` with paths `apps/api/**`, `infra/**`; `workflow_dispatch`.
- `permissions: id-token: write, contents: read`.
- Steps: checkout → `aws-actions/configure-aws-credentials@v4` (`role-to-assume: <oidc role arn>`, `aws-region: us-east-1`) → setup Node 20 → `npm ci` in `infra/` → `npx cdk deploy ApiStack --require-approval never` (builds the image via Docker on the runner, pushes to CDK ECR, updates Lambda). `AtlasStack`/`GithubOidcStack` are deployed manually/rarely, not on every push (documented).

### 5. Mobile tie-in
- After first deploy, take the API Gateway invoke URL and:
  - set GitHub repo secret `API_BASE_URL` for the mobile Android workflow;
  - use it for local `bun run mobile:apk`.
- Documented in `docs/aws-deploy.md` and cross-referenced from `docs/mobile-cicd.md`.

### 6. Data seed
- One-time: `MONGODB_URI=<atlas-srv> MONGODB_DB=bjj_open_mat bun run seed` (from `apps/api`) to populate Atlas.

## One-time bootstrap prerequisites (manual, local; documented in `docs/aws-deploy.md`)
1. `cdk bootstrap aws://318205107378/us-east-1 --profile dsylvesteriii`.
2. Activate MongoDB Atlas CloudFormation public extensions (the `MongoDB::Atlas::*` resource types) in the account/region (via `awscdk-resources-mongodbatlas` `MongoAtlasBootstrap` construct or CLI `cloudformation activate-type`).
3. Create an Atlas organization API key (Project Owner) and store `{ PublicKey, PrivateKey }` in Secrets Manager secret `cfn/atlas/profile/default`.
4. Deploy `GithubOidcStack` and `AtlasStack` locally with profile `dsylvesteriii`.

## Error handling
- Secrets fetch failure at cold start → log and throw; Lambda returns 5xx; error visible in CloudWatch. Fail fast, don't serve with missing config.
- Mongo connect uses the existing 10 s timeout; `/ready` reports `degraded` if Mongo ping fails.
- API Gateway integration timeout ≥ Lambda timeout to avoid premature 504s.

## Testing / verification
- `npx cdk synth` succeeds for all stacks.
- Local API unchanged: `bun run api:dev` still boots (secrets module no-ops without `APP_SECRET_ARN`).
- `apps/api` unit tests (`bun test`) still green.
- Post-deploy smoke: `curl <invoke-url>/health` → ok; `/ready` → `mongo: true`; `GET /open-mats` (or the real route) returns seeded data.
- Then rebuild the mobile APK with the new `API_BASE_URL` and confirm the app lists open mats.

## Out of scope
- Custom domain / TLS cert for the API (use the default API Gateway URL for now).
- VPC/PrivateLink to Atlas (using SCRAM + TLS + IP allowlist instead).
- Autoscaling/provisioned concurrency tuning beyond defaults.
- Fixing the Auth0 app-type misconfiguration (tracked separately; dev-bypass path remains available).

## Sequencing
1. App changes (secrets bootstrap + Dockerfile) — keeps local dev working.
2. `infra/` CDK scaffold + stacks (OIDC, Atlas, Api).
3. One-time bootstrap (cdk bootstrap, Atlas extension + API key, deploy OIDC + Atlas locally).
4. Deploy ApiStack locally once; seed Atlas; smoke-test the URL.
5. Add the GitHub Actions deploy workflow (OIDC).
6. Wire `API_BASE_URL` into the mobile build; rebuild + verify APK.
