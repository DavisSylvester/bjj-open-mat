#!/usr/bin/env node
/**
 * One-time setup: creates an ACM certificate covering bjjopenmat.app,
 * www.bjjopenmat.app, and bjj-open-mat.dsylvester.ai (us-east-1, required
 * for CloudFront), then validates it via Cloudflare (for bjjopenmat.app) and
 * Route 53 (for dsylvester.ai), and finally wires bjjopenmat.app + www ->
 * the CloudFront distribution in Cloudflare.
 *
 * Required env vars:
 *   CLOUDFLARE_DNS_TOKEN  Cloudflare API token with DNS:Edit on bjjopenmat.app
 *   AWS_PROFILE           defaults to dsylvesteriii
 *
 * Optional env vars:
 *   CLOUDFRONT_DOMAIN     e.g. d1234abcd.cloudfront.net — when set, wires the
 *                         apex and www CNAME records in Cloudflare. Obtain from
 *                         CDK output BjjWebsiteStack.DistributionDomainName.
 *
 * After the script finishes, save the printed cert ARN as the GitHub secret
 * BJJOPENMAT_CERT_ARN so the website-deploy workflow can pass it to CDK.
 *
 * Usage:
 *   node scripts/cf-dns-setup.mjs
 *   CLOUDFRONT_DOMAIN=d123.cloudfront.net node scripts/cf-dns-setup.mjs
 */

import { execSync } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CF_TOKEN = process.env.CLOUDFLARE_DNS_TOKEN;
const CF_API = 'https://api.cloudflare.com/client/v4';
const APEX = 'bjjopenmat.app';
const WWW = `www.${APEX}`;
const SITE = 'bjj-open-mat.dsylvester.ai';
const R53_ZONE_ID = 'Z084603532M2PA5E3QFC8';
const AWS_PROFILE = process.env.AWS_PROFILE ?? 'dsylvesteriii';
const AWS_REGION = 'us-east-1';
const CLOUDFRONT_DOMAIN = process.env.CLOUDFRONT_DOMAIN;
// Set this to reuse an already-created cert (skips step 2) — useful after a failed run.
const EXISTING_CERT_ARN = process.env.EXISTING_CERT_ARN;

if (!CF_TOKEN) {
  console.error('Error: CLOUDFLARE_DNS_TOKEN is not set.');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Cloudflare helpers
// ---------------------------------------------------------------------------

async function cfRequest(method, path, body) {
  const res = await fetch(`${CF_API}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${CF_TOKEN}`,
      'Content-Type': 'application/json',
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const data = await res.json();
  if (!data.success) {
    throw new Error(`Cloudflare error on ${method} ${path}: ${JSON.stringify(data.errors)}`);
  }
  return data.result;
}

// ---------------------------------------------------------------------------
// AWS CLI helper (cross-platform via temp file for JSON payloads)
// ---------------------------------------------------------------------------

function aws(args, jsonPayload) {
  let tmpFile;
  let fullArgs = args;

  if (jsonPayload !== undefined) {
    tmpFile = join(tmpdir(), `cf-dns-setup-${Date.now()}.json`);
    writeFileSync(tmpFile, JSON.stringify(jsonPayload), 'utf8');
    fullArgs = `${args} --cli-input-json file://${tmpFile}`;
  }

  try {
    return execSync(
      `aws ${fullArgs} --profile ${AWS_PROFILE} --region ${AWS_REGION}`,
      { encoding: 'utf8', stdio: ['inherit', 'pipe', 'inherit'] },
    ).trim();
  } finally {
    if (tmpFile) {
      try { unlinkSync(tmpFile); } catch { /* ignore */ }
    }
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  // 1. Resolve Cloudflare zone for bjjopenmat.app
  console.log(`Resolving Cloudflare zone for ${APEX}...`);
  const zones = await cfRequest('GET', `/zones?name=${APEX}`);
  if (!zones.length) throw new Error(`No Cloudflare zone found for ${APEX} — is the domain added to your Cloudflare account?`);
  const cfZoneId = zones[0].id;
  console.log(`  Zone ID: ${cfZoneId}`);

  // 2. Request ACM certificate (us-east-1, required by CloudFront)
  let certArn;
  if (EXISTING_CERT_ARN) {
    certArn = EXISTING_CERT_ARN;
    console.log(`\nReusing existing ACM certificate: ${certArn}`);
  } else {
    console.log('\nRequesting ACM certificate...');
    certArn = aws(
      `acm request-certificate` +
      ` --domain-name ${APEX}` +
      ` --subject-alternative-names ${WWW} ${SITE}` +
      ` --validation-method DNS` +
      ` --query CertificateArn --output text`,
    );
    console.log(`  ARN: ${certArn}`);
  }

  // 3. Poll until ACM populates DomainValidationOptions (usually ~10 s)
  console.log('\nWaiting for validation options to populate...');
  let validationOptions = [];
  for (let i = 0; i < 18; i++) {
    await sleep(5000);
    const raw = aws(`acm describe-certificate --certificate-arn ${certArn} --output json`);
    const detail = JSON.parse(raw);
    validationOptions = (detail.Certificate.DomainValidationOptions ?? []).filter(o => o.ResourceRecord);
    if (validationOptions.length >= 2) break; // apex + www share one record; site is the third
    process.stdout.write('.');
  }
  console.log('');
  if (!validationOptions.length) throw new Error('Timed out waiting for DomainValidationOptions.');

  // 4. Add validation CNAMEs
  console.log('\nAdding DNS validation CNAMEs...');
  const r53Changes = [];
  const addedToCf = new Set(); // ACM reuses the same CNAME name for apex + www

  for (const opt of validationOptions) {
    const { Name, Value } = opt.ResourceRecord;
    const domain = opt.DomainName;
    console.log(`  [${domain}] ${Name} -> ${Value}`);

    if (domain.endsWith('.dsylvester.ai')) {
      r53Changes.push({
        Action: 'UPSERT',
        ResourceRecordSet: { Name, Type: 'CNAME', TTL: 300, ResourceRecords: [{ Value }] },
      });
    } else if (!addedToCf.has(Name)) {
      addedToCf.add(Name);
      // ACM returns FQDNs with trailing dots; Cloudflare uses relative names without them.
      const cfName = Name.replace(/\.$/, '');
      const cfValue = Value.replace(/\.$/, '');
      const existing = await cfRequest('GET', `/zones/${cfZoneId}/dns_records?type=CNAME&name=${encodeURIComponent(cfName)}`);
      if (existing.length) {
        console.log(`    -> already present in Cloudflare, skipping`);
      } else {
        await cfRequest('POST', `/zones/${cfZoneId}/dns_records`, {
          type: 'CNAME',
          name: cfName,
          content: cfValue,
          ttl: 300,
          proxied: false, // must be DNS-only for ACM validation
        });
        console.log(`    -> added to Cloudflare`);
      }
    }
  }

  if (r53Changes.length) {
    aws(
      `route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID}`,
      { ChangeBatch: { Changes: r53Changes } },
    );
    console.log(`  -> Route 53 updated for ${SITE}`);
  }

  // 5. Poll until certificate is ISSUED (up to 10 min)
  console.log('\nWaiting for certificate to be issued (up to 10 minutes)...');
  let issued = false;
  for (let i = 0; i < 60; i++) {
    await sleep(10000);
    const raw = aws(`acm describe-certificate --certificate-arn ${certArn} --output json`);
    const status = JSON.parse(raw).Certificate.Status;
    if (status === 'ISSUED') { issued = true; break; }
    if (status === 'FAILED') throw new Error('ACM certificate issuance failed — check the AWS console.');
    if (i % 3 === 0) process.stdout.write(`  ${status} (${i * 10}s)\n`);
  }
  if (!issued) throw new Error('Timed out waiting for certificate issuance.');
  console.log('  Certificate issued.');

  // 6. Wire bjjopenmat.app + www -> CloudFront in Cloudflare (optional)
  if (CLOUDFRONT_DOMAIN) {
    console.log(`\nWiring ${APEX} and ${WWW} -> ${CLOUDFRONT_DOMAIN} in Cloudflare...`);
    for (const name of [APEX, WWW]) {
      const existing = await cfRequest('GET', `/zones/${cfZoneId}/dns_records?type=CNAME&name=${encodeURIComponent(name)}`);
      const record = { type: 'CNAME', name, content: CLOUDFRONT_DOMAIN, ttl: 1, proxied: false };
      if (existing.length) {
        await cfRequest('PUT', `/zones/${cfZoneId}/dns_records/${existing[0].id}`, record);
        console.log(`  Updated  ${name}`);
      } else {
        await cfRequest('POST', `/zones/${cfZoneId}/dns_records`, record);
        console.log(`  Created  ${name}`);
      }
    }
  } else {
    console.log(`\nSkipping DNS wiring (CLOUDFRONT_DOMAIN not set).`);
    console.log(`Re-run with CLOUDFRONT_DOMAIN=<value> after the CDK deploy to wire DNS.`);
  }

  console.log('\n--- Done ---');
  console.log(`Cert ARN: ${certArn}`);
  console.log('Save this as the GitHub secret BJJOPENMAT_CERT_ARN, then deploy:');
  console.log('  gh secret set BJJOPENMAT_CERT_ARN --body "<arn>"');
}

main().catch(err => {
  console.error(`\nError: ${err.message}`);
  process.exit(1);
});
