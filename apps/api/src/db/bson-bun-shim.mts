/**
 * Bun + bson@7 compatibility shim.
 *
 * mongodb@7 bundles bson@7, whose module-init code calls
 * `process.getBuiltinModule('v8').startupSnapshot.isBuildingSnapshot()`.
 * Bun (1.3.x) exposes that method as a throwing stub
 * (`ERR_NOT_IMPLEMENTED`), so importing mongodb crashes at load time.
 *
 * This shim replaces the throwing stub with a no-op that returns `false`.
 * It MUST run (for its side effect) BEFORE mongodb is loaded:
 *   - at runtime, `mongo.mts` imports this first and then loads the driver
 *     via a dynamic `import('mongodb')`;
 *   - in tests, it is imported at the top of `test/setup.mts`, which bunfig
 *     preloads before any test file (and its static mongodb imports) runs.
 * Static import ordering within a single module is not reliable under Bun's
 * CJS interop, hence the dynamic-import discipline at the call sites.
 *
 * In Node the shimmed method legitimately returns `false` at normal runtime,
 * so this is a no-op there. Remove once Bun implements the API.
 */

interface StartupSnapshot {
  isBuildingSnapshot?: () => boolean;
}

interface V8Module {
  startupSnapshot?: StartupSnapshot;
}

const getBuiltinModule: ((name: string) => unknown) | undefined = (
  globalThis as { process?: { getBuiltinModule?: (name: string) => unknown } }
).process?.getBuiltinModule;

if (typeof getBuiltinModule === "function") {
  try {
    const v8mod = getBuiltinModule("v8") as V8Module | undefined;
    if (v8mod) {
      const noop = (): boolean => false;
      if (!v8mod.startupSnapshot) {
        v8mod.startupSnapshot = { isBuildingSnapshot: noop };
      } else {
        v8mod.startupSnapshot.isBuildingSnapshot = noop;
      }
    }
  } catch {
    // Best-effort: if the object is frozen or the module is absent, there is
    // nothing more we can safely do here — the caller surfaces any error.
  }
}
