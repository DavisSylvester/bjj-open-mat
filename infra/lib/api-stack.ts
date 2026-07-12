import * as path from "node:path";
import { CfnOutput, Duration, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as iam from "aws-cdk-lib/aws-iam";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as acm from "aws-cdk-lib/aws-certificatemanager";
import * as route53 from "aws-cdk-lib/aws-route53";
import * as route53Targets from "aws-cdk-lib/aws-route53-targets";
import * as sesv2 from "aws-cdk-lib/aws-ses";
import { DomainName, HttpApi } from "aws-cdk-lib/aws-apigatewayv2";
import { HttpLambdaIntegration } from "aws-cdk-lib/aws-apigatewayv2-integrations";

const DOMAIN_NAME = "api.bjj-open-mat.dsylvester.io";
const ZONE_NAME = "dsylvester.io";
const ZONE_ID = "Z00521283KLJPV4530BY5";

// dsylvester.ai hosted zone (same AWS account) — used for SES DKIM auto-records.
const AI_ZONE_ID = "Z084603532M2PA5E3QFC8";
const AI_ZONE_NAME = "dsylvester.ai";

const SES_FROM = "no-reply@dsylvester.ai";
const ADMIN_EMAIL = "davis.sylvester@davaco.com";
const WEBSITE_ORIGIN = "https://bjj-open-mat.dsylvester.ai";

// The Bun/Elysia API packaged as a Lambda container image (via the Lambda Web
// Adapter), fronted by an API Gateway HTTP API on a custom domain. Sensitive values
// live in a Secrets Manager secret the function reads at cold start (APP_SECRET_ARN).
export class ApiStack extends Stack {
  constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    // CDK is invoked from infra/, so the repo root (Docker build context) is one up.
    const repoRoot = path.resolve(process.cwd(), "..");

    // Runtime secrets JSON (MONGODB_URI, AUTH_BYPASS_SECRET, GITHUB_TOKEN). Created
    // empty here; the real value is written out-of-band (aws secretsmanager
    // put-secret-value) so it never enters the CloudFormation template.
    const appSecret = new secretsmanager.Secret(this, "AppSecret", {
      secretName: "bjj-open-mat/app",
      description: "BJJ Open Mat API runtime secrets (MONGODB_URI, AUTH_BYPASS_SECRET, GITHUB_TOKEN)",
    });

    // Public asset bucket for gym logos. Objects live under logos/* and are
    // served public-read via a bucket policy (ACLs disabled). The API presigns
    // PUT uploads; the app displays the stable object URL directly.
    // Explicitly named per the <app>-<resource_type> convention.
    const assetsBucket = new s3.Bucket(this, "AssetsBucket", {
      bucketName: "bjj-open-mat-assets",
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: true,
        ignorePublicAcls: true,
        blockPublicPolicy: false,
        restrictPublicBuckets: false,
      }),
      cors: [
        {
          allowedMethods: [s3.HttpMethods.PUT, s3.HttpMethods.GET, s3.HttpMethods.HEAD],
          allowedOrigins: ["*"],
          allowedHeaders: ["*"],
          maxAge: 3000,
        },
      ],
    });

    // Anyone may read logo objects (public gym logos); nothing else is public.
    assetsBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        actions: ["s3:GetObject"],
        resources: [assetsBucket.arnForObjects("logos/*")],
        principals: [new iam.AnyPrincipal()],
      }),
    );

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
        ASSETS_BUCKET: assetsBucket.bucketName,
        ASSETS_REGION: this.region,
        SES_FROM,
        ADMIN_EMAIL,
        WEBSITE_ORIGIN,
        SES_REGION: this.region,
      },
    });

    appSecret.grantRead(fn);
    // The API only ever writes logo objects; scope the grant to that prefix.
    assetsBucket.grantPut(fn, "logos/*");

    // SES send. SendEmail/SendRawEmail don't support tight resource ARNs in the
    // simple case, so `*` is standard here.
    fn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ses:SendEmail", "ses:SendRawEmail"],
        resources: ["*"],
      }),
    );

    // dsylvester.ai hosted zone lookup (static attributes -> offline synth).
    const aiZone = route53.PublicHostedZone.fromPublicHostedZoneAttributes(this, "AiZone", {
      hostedZoneId: AI_ZONE_ID,
      zoneName: AI_ZONE_NAME,
    });

    // Verifies dsylvester.ai for SES so no-reply@dsylvester.ai can send. Binding
    // the identity to the public hosted zone lets CDK auto-create the 3 Easy-DKIM
    // CNAME records in that zone using the raw DKIM token names — avoiding the
    // double zone-suffix bug you get by feeding an unresolved token as recordName.
    new sesv2.EmailIdentity(this, "SesDomainIdentity", {
      identity: sesv2.Identity.publicHostedZone(aiZone),
    });

    // Existing Route53 hosted zone for dsylvester.io (same AWS account).
    const zone = route53.HostedZone.fromHostedZoneAttributes(this, "Zone", {
      hostedZoneId: ZONE_ID,
      zoneName: ZONE_NAME,
    });

    // DNS-validated ACM cert. Regional (us-east-1) — required for a regional HTTP API.
    const certificate = new acm.Certificate(this, "ApiCert", {
      domainName: DOMAIN_NAME,
      validation: acm.CertificateValidation.fromDns(zone),
    });

    const apiDomain = new DomainName(this, "ApiDomain", {
      domainName: DOMAIN_NAME,
      certificate,
    });

    const api = new HttpApi(this, "HttpApi", {
      apiName: "bjj-open-mat-api",
      defaultIntegration: new HttpLambdaIntegration("ApiIntegration", fn),
      defaultDomainMapping: { domainName: apiDomain },
    });

    // api.bjj-open-mat.dsylvester.io -> API Gateway regional domain (alias).
    new route53.ARecord(this, "ApiAliasRecord", {
      zone,
      recordName: "api.bjj-open-mat",
      target: route53.RecordTarget.fromAlias(
        new route53Targets.ApiGatewayv2DomainProperties(
          apiDomain.regionalDomainName,
          apiDomain.regionalHostedZoneId,
        ),
      ),
    });

    new CfnOutput(this, "CustomUrl", { value: `https://${DOMAIN_NAME}` });
    new CfnOutput(this, "ApiUrl", { value: api.apiEndpoint });
    new CfnOutput(this, "AppSecretArn", { value: appSecret.secretArn });
    new CfnOutput(this, "AssetsBucketName", { value: assetsBucket.bucketName });
  }
}
