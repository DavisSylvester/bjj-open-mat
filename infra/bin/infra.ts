import { App } from "aws-cdk-lib";
import { ApiStack } from "../lib/api-stack";
import { GithubOidcStack } from "../lib/github-oidc-stack";

const app = new App();
const env = { account: "318205107378", region: "us-east-1" };

new ApiStack(app, "BjjApiStack", { env });

new GithubOidcStack(app, "BjjGithubOidcStack", {
  env,
  repo: "DavisSylvester/bjj-open-mat",
});
