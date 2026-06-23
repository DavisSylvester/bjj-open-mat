import type { Elysia } from "elysia";
import { AppError, httpStatusFor } from "./errors.mts";

export interface ErrorLogger {
  warn(message: string): void;
  error(message: string): void;
}

// Registers a global onError hook. Validation failures are logged with a
// "VALIDATION: " prefix so they are trivially greppable.
export function registerErrorHandler<T extends Elysia>(app: T, logger: ErrorLogger): T {
  // onError mutates the instance in place; return the original to preserve T.
  app.onError(({ code, error, set, request, path }) => {
    if (code === "VALIDATION") {
      const message = error instanceof Error ? error.message : String(error);
      logger.warn(`VALIDATION: ${request.method} ${path} — ${message.replace(/\s+/g, " ").trim()}`);
      set.status = 400;
      return { error: { code: "bad_request", message: "Request validation failed", details: message } };
    }

    if (error instanceof AppError) {
      set.status = httpStatusFor(error.code);
      return { error: { code: error.code, message: error.message, details: error.details } };
    }

    if (code === "NOT_FOUND") {
      set.status = 404;
      return { error: { code: "not_found", message: "Route not found" } };
    }

    logger.error(`${request.method} ${path} — ${error instanceof Error ? error.message : String(error)}`);
    set.status = 500;
    return { error: { code: "internal_error", message: "Internal server error" } };
  });
  return app;
}
