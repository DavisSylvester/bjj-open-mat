/**
 * Bun + bson@7 compatibility shim.
 *
 * mongodb@7 bundles bson@7, whose module-init code calls
 * `process.getBuiltinModule('v8').startupSnapshot.isBuildingSnapshot()`.
 * Bun (1.3.x) exposes that method as a throwing stub
 * (`ERR_NOT_IMPLEMENTED`), so importing mongodb crashes at load time.
 *
 * This shim replaces the throwing stub with a no-op that returns `false`.
 * It MUST be imported (for its side effect) BEFORE mongodb is loaded, and
 * mongodb MUST then be brought in via a dynamic `import('mongodb')` so the
 * patch is guaranteed to run first (static import ordering is not reliable
 * under Bun's CJS interop). Remove this shim once Bun implements the API.
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

if (typeof getBuiltinModule === 'function') {
  try {
    const v8mod = getBuiltinModule('v8') as V8Module | undefined;
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
    // nothing more we can safely do here — the caller will surface any error.
  }
}
