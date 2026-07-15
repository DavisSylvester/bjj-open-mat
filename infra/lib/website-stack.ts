import * as fs from "node:fs";
import * as path from "node:path";
import { CfnOutput, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as s3deploy from "aws-cdk-lib/aws-s3-deployment";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";
import * as acm from "aws-cdk-lib/aws-certificatemanager";
import * as route53 from "aws-cdk-lib/aws-route53";
import * as targets from "aws-cdk-lib/aws-route53-targets";

const SITE_DOMAIN = "bjj-open-mat.dsylvester.ai";
const ZONE_ID = "Z084603532M2PA5E3QFC8";
const ZONE_NAME = "dsylvester.ai";
const BJJOPENMAT_DOMAINS = ["bjjopenmat.app", "www.bjjopenmat.app"];

// Static hosting for the Angular marketing site: a private S3 bucket fronted by
// CloudFront (OAC). The ACM cert is DNS-validated against the dsylvester.ai
// Route53 hosted zone (same AWS account), and an alias A/AAAA record points the
// site domain at the distribution — fully automated. Must be us-east-1 (CloudFront cert).
export class WebsiteStack extends Stack {
  public constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    const repoRoot = path.resolve(process.cwd(), "..");

    // When BJJOPENMAT_CERT_ARN is set, import the pre-validated combined cert covering
    // bjj-open-mat.dsylvester.ai + bjjopenmat.app + www.bjjopenmat.app. Run
    // scripts/cf-dns-setup.mjs once to create and validate the cert, then save the
    // ARN as the BJJOPENMAT_CERT_ARN GitHub secret.
    const certArn = process.env.BJJOPENMAT_CERT_ARN;

    const bucket = new s3.Bucket(this, "SiteBucket", {
      bucketName: "bjj-open-mat-website",
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    // dsylvester.ai hosted zone (same AWS account); static attributes -> offline synth.
    const zone = route53.HostedZone.fromHostedZoneAttributes(this, "Zone", {
      hostedZoneId: ZONE_ID,
      zoneName: ZONE_NAME,
    });

    const certificate = certArn
      ? acm.Certificate.fromCertificateArn(this, "SiteCert", certArn)
      : new acm.Certificate(this, "SiteCert", {
          domainName: SITE_DOMAIN,
          validation: acm.CertificateValidation.fromDns(zone),
        });

    const domainNames = certArn ? [SITE_DOMAIN, ...BJJOPENMAT_DOMAINS] : [SITE_DOMAIN];

    const distribution = new cloudfront.Distribution(this, "SiteDistribution", {
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(bucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      },
      domainNames,
      certificate,
      defaultRootObject: "index.html",
      errorResponses: [
        { httpStatus: 403, responseHttpStatus: 200, responsePagePath: "/index.html" },
        { httpStatus: 404, responseHttpStatus: 200, responsePagePath: "/index.html" },
      ],
    });

    // Only wire the content deployment when the built site is present. CDK
    // synthesizes every stack in the app before deploying any one, so an API
    // deploy (which never builds the website) would abort synth on a missing
    // Source.asset() dir. The website-deploy workflow builds first, so the
    // asset exists there and the site content still deploys.
    const siteAssetDir = path.join(repoRoot, "website/dist/website/browser");
    if (fs.existsSync(siteAssetDir)) {
      new s3deploy.BucketDeployment(this, "DeploySite", {
        sources: [s3deploy.Source.asset(siteAssetDir)],
        destinationBucket: bucket,
        distribution,
        distributionPaths: ["/*"],
      });
    }

    // bjj-open-mat.dsylvester.ai -> CloudFront distribution (alias A + AAAA for IPv6).
    const aliasTarget = route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(distribution));
    new route53.ARecord(this, "SiteAliasRecord", {
      zone,
      recordName: "bjj-open-mat",
      target: aliasTarget,
    });
    new route53.AaaaRecord(this, "SiteAliasRecordAaaa", {
      zone,
      recordName: "bjj-open-mat",
      target: aliasTarget,
    });

    new CfnOutput(this, "DistributionDomainName", { value: distribution.distributionDomainName });
    new CfnOutput(this, "DistributionId", { value: distribution.distributionId });
    new CfnOutput(this, "SiteUrl", { value: `https://${SITE_DOMAIN}` });
    new CfnOutput(this, "SiteBucketName", { value: bucket.bucketName });
  }
}
