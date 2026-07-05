import { CfnOutput, Stack, type StackProps } from "aws-cdk-lib";
import type { Construct } from "constructs";
import * as iam from "aws-cdk-lib/aws-iam";

interface GithubOidcStackProps extends StackProps {
  readonly repo: string; // "owner/name"
}

// A repo-scoped role that GitHub Actions assumes (no long-lived keys). The account
// already has a GitHub OIDC provider, so we reference it by ARN rather than creating
// a duplicate. The role can assume the CDK bootstrap roles, which carry the actual
// deploy permissions — so CI runs `cdk deploy` without broad standing access.
export class GithubOidcStack extends Stack {
  constructor(scope: Construct, id: string, props: GithubOidcStackProps) {
    super(scope, id, props);

    const providerArn = `arn:aws:iam::${this.account}:oidc-provider/token.actions.githubusercontent.com`;

    const role = new iam.Role(this, "DeployRole", {
      roleName: "bjj-github-deploy",
      description: "Assumed by GitHub Actions to deploy the API via CDK",
      assumedBy: new iam.WebIdentityPrincipal(providerArn, {
        StringEquals: {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        },
        StringLike: {
          "token.actions.githubusercontent.com:sub": `repo:${props.repo}:*`,
        },
      }),
    });

    role.addToPolicy(
      new iam.PolicyStatement({
        actions: ["sts:AssumeRole"],
        resources: [`arn:aws:iam::${this.account}:role/cdk-*`],
      }),
    );

    new CfnOutput(this, "DeployRoleArn", { value: role.roleArn });
  }
}
