import { buildApp } from "./app.mts";
import { logger } from "./config/logger.mts";

const port = Number(process.env["PORT"] ?? 3100);

buildApp().listen(port, (server) => {
  logger.info(`BJJ Open Mat API listening on http://localhost:${server.port}`);
});
