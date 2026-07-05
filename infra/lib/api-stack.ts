import * as path from "node:path";
import { CfnOutput, Duration, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import { HttpApi } from "aws-cdk-lib/aws-apigatewayv2";
import { HttpLambdaIntegration } from "aws-cdk-lib/aws-apigatewayv2-integrations";

// The Bun/Elysia API packaged as a Lambda container image (via the Lambda Web
// Adapter), fronted by an API Gateway HTTP API. Sensitive values live in a Secrets
// Manager secret the function reads at cold start (APP_SECRET_ARN).
export class ApiStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    // CDK is invoked from infra/, so the repo root (Docker build context) is one up.
    const repoRoot = path.resolve(process.cwd(), "..");

    // MONGODB_URI + AUTH_BYPASS_SECRET. Created empty here; the real JSON value is
    // written out-of-band (aws secretsmanager put-secret-value) so it never enters
    // the CloudFormation template.
    const appSecret = new secretsmanager.Secret(this, "AppSecret", {
      secretName: "bjj-open-mat/app",
      description: "BJJ Open Mat API runtime secrets (MONGODB_URI, AUTH_BYPASS_SECRET)",
    });

    const fn = new lambda.DockerImageFunction(this, "ApiFunction", {
      functionName: "bjj-open-mat-api",
      code: lambda.DockerImageCode.fromImageAsset(repoRoot, {
        file: "apps/api/Dockerfile",
      }),
      memorySize: 512,
      timeout: Duration.seconds(20),
      environment: {
        MONGODB_DB: "bjj_open_mat",
        DEMO_USER_ID: "test-user@local.priv",
        DEMO_USER_ROLE: "gym_owner",
        DEMO_USER_EMAIL: "demo@bjj-open-mat.test",
        AUTH0_DOMAIN: "dev-vhvwupdn45hk7gct.us.auth0.com",
        AUTH0_AUDIENCE: "https://www.bjj-open-mat",
        APP_SECRET_ARN: appSecret.secretArn,
        AWS_LWA_READINESS_CHECK_PATH: "/health",
      },
    });

    appSecret.grantRead(fn);

    const api = new HttpApi(this, "HttpApi", {
      apiName: "bjj-open-mat-api",
      defaultIntegration: new HttpLambdaIntegration("ApiIntegration", fn),
    });

    new CfnOutput(this, "ApiUrl", { value: api.apiEndpoint });
    new CfnOutput(this, "AppSecretArn", { value: appSecret.secretArn });
  }
}
