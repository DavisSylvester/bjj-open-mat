/**
 * Test preload. Runs before any test file (registered in bunfig.toml).
 *
 * The repository tests connect to `process.env.MONGODB_URI` and create
 * throwaway databases (`bjj_test_*`). Bun gives an exported shell variable
 * precedence over `.env`, so whatever cluster a developer happens to have
 * exported — including a production one — would be written to and, since the
 * app user usually lacks `dropDatabase`, left littered with test data that
 * collides with the next run.
 *
 * Tests therefore get their own connection string, never the ambient one.
 * Point them somewhere else deliberately with TEST_MONGODB_URI.
 */

// Runs before any test file loads mongodb, so bson@7 can init under Bun.
// (This preload module imports no mongodb itself, so the shim wins the race.)
import "../src/db/bson-bun-shim.mjs";

const TEST_MONGODB_URI: string = process.env["TEST_MONGODB_URI"] ?? "mongodb://localhost:27017";

process.env["MONGODB_URI"] = TEST_MONGODB_URI;

// The app's own database name should never be reachable from a test run either.
process.env["MONGODB_DB"] = process.env["TEST_MONGODB_DB"] ?? "bjj_test";

if (!/localhost|127\.0\.0\.1/.test(TEST_MONGODB_URI)) {
  console.warn(
    `[test setup] TEST_MONGODB_URI points at a remote host. Tests create and drop ` +
      `databases — make sure this is not a production cluster.`,
  );
}
