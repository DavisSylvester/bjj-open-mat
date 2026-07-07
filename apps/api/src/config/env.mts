import { type Static, Type as t } from "@sinclair/typebox";
import { Value } from "@sinclair/typebox/value";

const EnvSchema = t.Object({
  PORT: t.Optional(t.String()),
  MONGODB_URI: t.String({ minLength: 1 }),
  MONGODB_DB: t.String({ minLength: 1 }),
  AUTH0_DOMAIN: t.Optional(t.String()),
  AUTH0_AUDIENCE: t.Optional(t.String()),
  AUTH_BYPASS_SECRET: t.String({ minLength: 1 }),
  DEMO_USER_ID: t.String({ minLength: 1 }),
  DEMO_USER_ROLE: t.Union([t.Literal("practitioner"), t.Literal("gym_owner")]),
  DEMO_USER_EMAIL: t.String({ minLength: 1 }),
  // Optional: S3 bucket for gym logo uploads. Absent in local dev without AWS.
  ASSETS_BUCKET: t.Optional(t.String()),
  ASSETS_REGION: t.Optional(t.String()),
  // Optional: GitHub token used to file issues for in-app reports. Absent in
  // local dev without a token — reports then save to Mongo only.
  GITHUB_TOKEN: t.Optional(t.String()),
  GITHUB_REPO: t.Optional(t.String()),
  // Optional: OpenAI API key and audio storage configuration for voice-to-text.
  OPENAI_API_KEY: t.Optional(t.String()),
  AUDIO_BUCKET: t.Optional(t.String()),
  AUDIO_REGION: t.Optional(t.String()),
});

type RawEnv = Static<typeof EnvSchema>;

export interface AppEnv {
  readonly port: number;
  readonly mongoUri: string;
  readonly mongoDb: string;
  readonly auth0Domain: string | undefined;
  readonly auth0Audience: string | undefined;
  readonly bypassSecret: string;
  readonly demoUser: { readonly id: string; readonly role: "practitioner" | "gym_owner"; readonly email: string };
  readonly assetsBucket: string | undefined;
  readonly assetsRegion: string;
  readonly githubToken: string | undefined;
  readonly githubRepo: string;
  readonly openaiApiKey: string | undefined;
  readonly audioBucket: string | undefined;
  readonly audioRegion: string;
}

export function loadEnv(source: Record<string, string | undefined> = process.env): AppEnv {
  const raw: RawEnv = Value.Parse(EnvSchema, source);
  return {
    port: Number(raw.PORT ?? "3100"),
    mongoUri: raw.MONGODB_URI,
    mongoDb: raw.MONGODB_DB,
    auth0Domain: raw.AUTH0_DOMAIN,
    auth0Audience: raw.AUTH0_AUDIENCE,
    bypassSecret: raw.AUTH_BYPASS_SECRET,
    demoUser: { id: raw.DEMO_USER_ID, role: raw.DEMO_USER_ROLE, email: raw.DEMO_USER_EMAIL },
    assetsBucket: raw.ASSETS_BUCKET,
    assetsRegion: raw.ASSETS_REGION ?? "us-east-1",
    githubToken: raw.GITHUB_TOKEN,
    githubRepo: raw.GITHUB_REPO ?? "DavisSylvester/bjj-open-mat",
    openaiApiKey: raw.OPENAI_API_KEY,
    audioBucket: raw.AUDIO_BUCKET,
    audioRegion: raw.AUDIO_REGION ?? raw.ASSETS_REGION ?? "us-east-1",
  };
}
