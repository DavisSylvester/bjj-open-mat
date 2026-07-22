# Cloudflare DNS — Knowledge Base

## Overview

`bjjopenmat.app` is registered and DNS-managed on Cloudflare. The domain points to the
same AWS CloudFront distribution as `bjj-open-mat.dsylvester.ai` (the `dsylvester.ai`
subdomain is managed via Route 53 in the same AWS account).

## Cloudflare Global Config

| Setting | Value |
|---------|-------|
| Domain | `bjjopenmat.app` |
| DNS management | Cloudflare (proxied DNS records must be set to **DNS-only** for CloudFront) |
| API token env var | `CLOUDFLARE_DNS_TOKEN` |
| Token permissions needed | Zone — DNS:Edit (scope: `bjjopenmat.app`) |

### Getting the API Token

1. Cloudflare dashboard → My Profile → API Tokens → Create Token
2. Use the **Edit zone DNS** template
3. Zone Resources: Include — Specific zone — `bjjopenmat.app`
4. Copy the token and store it as:
   - Local: `export CLOUDFLARE_DNS_TOKEN=<token>`
   - GitHub Actions secret: `BJJOPENMAT_CERT_ARN` (cert ARN) and `CLOUDFLARE_DNS_TOKEN` (if wiring step is added to CI)

### Getting the Zone ID

The setup script resolves the zone ID automatically via the Cloudflare Zones API. To find
it manually: Cloudflare dashboard → select `bjjopenmat.app` → Overview → right panel →
**Zone ID**.

## DNS Records

| Name | Type | Content | Proxied | Purpose |
|------|------|---------|---------|---------|
| `bjjopenmat.app` | CNAME | `<cloudfront-domain>.cloudfront.net` | No | Apex → CloudFront |
| `www.bjjopenmat.app` | CNAME | `<cloudfront-domain>.cloudfront.net` | No | www → CloudFront |
| `_<hash>.bjjopenmat.app` | CNAME | `_<hash>.acm-validations.aws.` | No | ACM cert validation |

> Records **must not** be Cloudflare-proxied (orange cloud) — CloudFront manages TLS and
> does its own health checks. Proxying would break TLS negotiation and CloudFront's
> origin validation.

## ACM Certificate

CloudFront requires an ACM certificate in **us-east-1**. The combined cert covers all
three names:

- `bjjopenmat.app`
- `www.bjjopenmat.app`
- `bjj-open-mat.dsylvester.ai`

The cert ARN is stored as the GitHub secret `BJJOPENMAT_CERT_ARN` and passed to CDK via
the `BJJOPENMAT_CERT_ARN` environment variable during the website-deploy workflow.

## One-Time Setup (run once per environment)

```bash
# Prerequisites: AWS_PROFILE set and Cloudflare token exported
export CLOUDFLARE_DNS_TOKEN=<token>
export AWS_PROFILE=dsylvesteriii

# Step 1 — create cert + validate (takes ~5–10 min for ACM issuance)
node scripts/cf-dns-setup.mjs

# Step 2 — after CDK outputs the CloudFront domain, wire DNS
CLOUDFRONT_DOMAIN=d1234abcd.cloudfront.net node scripts/cf-dns-setup.mjs
```

After step 1, save the printed cert ARN as a GitHub secret:

```bash
gh secret set BJJOPENMAT_CERT_ARN --body "arn:aws:acm:us-east-1:318205107378:certificate/..."
```

Then trigger the deploy workflow (it will include `bjjopenmat.app` in the CloudFront
distribution automatically).

## Ongoing Deploys

No Cloudflare interaction is needed on normal deploys. The workflow passes
`BJJOPENMAT_CERT_ARN` to CDK, which imports the cert and includes `bjjopenmat.app` in
the distribution's domain names. CloudFront and the cert are stable across deploys.

## Cloudflare API Reference

Base URL: `https://api.cloudflare.com/client/v4`

```bash
# List zones (get zone ID)
curl "https://api.cloudflare.com/client/v4/zones?name=bjjopenmat.app" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN"

# List DNS records
curl "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN"

# Create DNS record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"bjjopenmat.app","content":"dxxx.cloudfront.net","ttl":1,"proxied":false}'

# Update DNS record
curl -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"bjjopenmat.app","content":"dxxx.cloudfront.net","ttl":1,"proxied":false}'
```
