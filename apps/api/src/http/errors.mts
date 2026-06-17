export type AppErrorCode =
  | "not_found"
  | "forbidden"
  | "unauthorized"
  | "conflict"
  | "bad_request";

export class AppError extends Error {

  public constructor(
    public readonly code: AppErrorCode,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export function httpStatusFor(code: AppErrorCode): number {
  switch (code) {
    case "not_found":
      return 404;
    case "forbidden":
      return 403;
    case "unauthorized":
      return 401;
    case "conflict":
      return 409;
    case "bad_request":
      return 400;
  }
}
