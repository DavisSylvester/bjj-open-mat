# Bun/Elysia API packaged for AWS Lambda via the AWS Lambda Web Adapter (LWA).
# LWA runs as a Lambda extension and proxies API Gateway events to the HTTP server
# the app already starts on :3100 — so the Elysia app runs unchanged.
FROM oven/bun:1.3.12

# Lambda Web Adapter extension.
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.9.1 /lambda-adapter /opt/extensions/lambda-adapter

ENV PORT=3100 \
    AWS_LWA_PORT=3100 \
    AWS_LWA_READINESS_CHECK_PATH=/health \
    NODE_ENV=production

WORKDIR /app

# Install workspace deps against the committed lockfile. The build context is the
# repo root; .dockerignore keeps the Flutter app and build artifacts out.
COPY . .
RUN bun install --frozen-lockfile

WORKDIR /app/apps/api
CMD ["bun", "run", "start"]
