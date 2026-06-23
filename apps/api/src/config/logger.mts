import { createLogger, format, type Logger, transports } from "winston";

export const logger: Logger = createLogger({
  level: process.env["LOG_LEVEL"] ?? "info",
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.json(),
  ),
  transports: [new transports.Console()],
});
