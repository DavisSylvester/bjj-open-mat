import { FormatRegistry } from "@sinclair/typebox";

// Register the string formats referenced by @bjj/contract schemas (email, uri)
// so TypeBox's Value.Parse — used for parse-on-read/write in repositories,
// outside Elysia's own format handling — recognizes them process-wide.
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const URI = /^\w+:\/\/.+/;

if (!FormatRegistry.Has("email")) {
  FormatRegistry.Set("email", (value: string): boolean => EMAIL.test(value));
}
if (!FormatRegistry.Has("uri")) {
  FormatRegistry.Set("uri", (value: string): boolean => URI.test(value));
}
