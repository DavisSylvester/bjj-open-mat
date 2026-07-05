import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";

// When running in Lambda, sensitive config lives in an AWS Secrets Manager secret
// whose ARN is supplied via APP_SECRET_ARN. We fetch it once at cold start and overlay
// its JSON keys onto process.env before loadEnv() validates. Locally (no APP_SECRET_ARN)
// this is a no-op and the app behaves exactly as before.
export async function resolveEnv(): Promise<Record<string, string | undefined>> {
  const secretArn = process.env["APP_SECRET_ARN"];
  if (!secretArn) {
    return process.env;
  }

  const region = process.env["AWS_REGION"] ?? "us-east-1";
  const client = new SecretsManagerClient({ region });
  const response = await client.send(new GetSecretValueCommand({ SecretId: secretArn }));

  if (!response.SecretString) {
    throw new Error(`Secret ${secretArn} has no SecretString`);
  }

  const overrides = JSON.parse(response.SecretString) as Record<string, string>;
  return { ...process.env, ...overrides };
}
