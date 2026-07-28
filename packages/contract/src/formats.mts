import { FormatRegistry } from "@sinclair/typebox";

// Registers the string formats referenced by @bjj/contract schemas (email, uri)
// so TypeBox's Value.Check / Value.Parse recognize them wherever the contract is
// used framework-agnostically (its own tests, parse-on-read, etc.). Idempotent.
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const URI = /^\w+:\/\/.+/;

if (!FormatRegistry.Has("email")) {
  FormatRegistry.Set("email", (value: string): boolean => EMAIL.test(value));
}
if (!FormatRegistry.Has("uri")) {
  FormatRegistry.Set("uri", (value: string): boolean => URI.test(value));
}
