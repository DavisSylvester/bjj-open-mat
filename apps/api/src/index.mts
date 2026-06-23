import { loadEnv } from "./config/env.mts";
import { logger } from "./config/logger.mts";
import { createMongoContext } from "./db/mongo.mts";
import { createContainer } from "./container.mts";
import { buildApp } from "./app.mts";

const env = loadEnv();
const { client, db } = createMongoContext(env);
await client.connect();

const container = createContainer(db, env);
await container.ensureIndexes();

buildApp(container).listen(env.port, (server) => {
  logger.info(`BJJ Open Mat API listening on http://localhost:${server.port}`);
});
