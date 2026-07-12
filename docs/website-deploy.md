# Marketing Website — Deploy & DNS Runbook

The marketing site (`website/`, Angular) is hosted on AWS S3 + CloudFront and served at
**https://bjj-open-mat.dsylvester.ai**. The lead-capture API (waitlist + gym leads) runs on the
existing Lambda API at **https://api.bjj-open-mat.dsylvester.io** and sends email via Amazon SES.

All DNS for `dsylvester.ai` is automated through its Route 53 hosted zone
(`Z084603532M2PA5E3QFC8`, account `318205107378`) — there are **no manual DNS steps**.

## Prerequisites

- AWS profile **`dsylvesteriii`** (account `318205107378`), region **us-east-1**.
- Docker running (the API is a container-image Lambda; `cdk deploy` builds the image).
- Bun + Node installed for the Angular build.

## Stacks (CDK, in `infra/`)

| Stack | Contents |
|-------|----------|
| `BjjApiStack` | Lambda API (Elysia) + API Gateway + assets bucket + **SES domain identity for `dsylvester.ai` (auto DKIM CNAMEs in Route 53)** + `ses:SendEmail` grant + `SES_FROM`/`ADMIN_EMAIL`/`WEBSITE_ORIGIN`/`SES_REGION` env. |
| `BjjWebsiteStack` | Private S3 bucket `bjj-open-mat-website` + CloudFront (OAC, SPA 403/404→`/index.html`) + ACM cert (Route 53-validated) + A/AAAA alias `bjj-open-mat.dsylvester.ai` → CloudFront + `BucketDeployment` of the built site. |

## Deploy

```bash
# 1. Build the Angular site (output: website/dist/website/browser)
cd website && npx ng build

# 2. Deploy both stacks (Route 53 validation + alias records are automatic)
cd ../infra
AWS_PROFILE=dsylvesteriii npx cdk deploy BjjApiStack BjjWebsiteStack \
  --profile dsylvesteriii --require-approval never
```

Redeploy the site after front-end changes: rebuild (`ng build`) then
`cdk deploy BjjWebsiteStack`. The `BucketDeployment` re-uploads and invalidates CloudFront `/*`.

### Outputs

- `BjjWebsiteStack.SiteUrl` → `https://bjj-open-mat.dsylvester.ai`
- `BjjWebsiteStack.DistributionDomainName` / `DistributionId`
- `BjjApiStack.CustomUrl` → `https://api.bjj-open-mat.dsylvester.io`

## SES — production access (launch prerequisite)

SES starts in **sandbox** mode: it can only send to *verified* recipient addresses (~200/day).
For testing, verify each test inbox in the SES console (us-east-1). Before public launch,
request production access (SES console → Account dashboard → Request production access). This is
a config/console step — no code change. When the domain identity shows **Verified** + **DKIM:
Successful**, `no-reply@dsylvester.ai` can send.

## Smoke test

```bash
# Site loads over HTTPS
curl -sI https://bjj-open-mat.dsylvester.ai | head -1        # expect HTTP/2 200

# Waitlist (saves lead + sends confirmation to a VERIFIED address while in sandbox)
curl -s -X POST https://api.bjj-open-mat.dsylvester.io/api/v1/waitlist \
  -H 'content-type: application/json' -d '{"email":"you@verified.example"}'
# expect {"data":{"status":"confirmed"}}

# Gym lead (saves lead + owner confirmation + admin alert to davis.sylvester@davaco.com)
curl -s -X POST https://api.bjj-open-mat.dsylvester.io/api/v1/gym-leads \
  -H 'content-type: application/json' \
  -d '{"gymName":"Test BJJ","ownerEmail":"coach@verified.example"}'
# expect {"data":{"status":"new"}}
```

In the browser: submit the hero/join waitlist form and the `/register-gym` form; confirm the
success states and that the leads appear in MongoDB (`waitlist_leads` / `gym_leads`) and emails
arrive (verified recipients only, until SES production access is granted).

## Notes

- CORS on the API allows `https://bjj-open-mat.dsylvester.ai` and `http://localhost:4200` via the
  `WEBSITE_ORIGIN` env var (`BjjApiStack`).
- The site bucket uses `RemovalPolicy.RETAIN` — `cdk destroy` won't delete the hosting bucket.
- Follow-up (tracked): add API Gateway/WAF rate limiting to the public lead endpoints — the
  honeypot is the only spam guard today and `/gym-leads` is non-idempotent.
