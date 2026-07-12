import * as path from "node:path";
import { CfnOutput, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as s3deploy from "aws-cdk-lib/aws-s3-deployment";
import * as cloudfront from "aws-cdk-lib/aws-cloudfront";
import * as origins from "aws-cdk-lib/aws-cloudfront-origins";
import * as acm from "aws-cdk-lib/aws-certificatemanager";

const SITE_DOMAIN = "bjj-open-mat.dsylvester.ai";

// Static hosting for the Angular marketing site: a private S3 bucket fronted by
// CloudFront (OAC). The ACM cert is DNS-validated on Hostinger (dsylvester.ai is
// NOT in this account's Route53), so the validation CNAME is emitted as an output
// to add by hand before the deploy can complete. Must be us-east-1 (CloudFront cert).
export class WebsiteStack extends Stack {
  public constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    const repoRoot = path.resolve(process.cwd(), "..");

    const bucket = new s3.Bucket(this, "SiteBucket", {
      bucketName: "bjj-open-mat-website",
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: RemovalPolicy.RETAIN,
    });

    const certificate = new acm.Certificate(this, "SiteCert", {
      domainName: SITE_DOMAIN,
      validation: acm.CertificateValidation.fromDns(), // no hosted zone -> emits a CNAME to add on Hostinger
    });

    const distribution = new cloudfront.Distribution(this, "SiteDistribution", {
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(bucket),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      },
      domainNames: [SITE_DOMAIN],
      certificate,
      defaultRootObject: "index.html",
      errorResponses: [
        { httpStatus: 403, responseHttpStatus: 200, responsePagePath: "/index.html" },
        { httpStatus: 404, responseHttpStatus: 200, responsePagePath: "/index.html" },
      ],
    });

    new s3deploy.BucketDeployment(this, "DeploySite", {
      sources: [s3deploy.Source.asset(path.join(repoRoot, "website/dist/website/browser"))],
      destinationBucket: bucket,
      distribution,
      distributionPaths: ["/*"],
    });

    new CfnOutput(this, "DistributionDomainName", { value: distribution.distributionDomainName });
    new CfnOutput(this, "DistributionId", { value: distribution.distributionId });
    new CfnOutput(this, "SiteUrl", { value: `https://${SITE_DOMAIN}` });
    new CfnOutput(this, "SiteBucketName", { value: bucket.bucketName });
  }
}
