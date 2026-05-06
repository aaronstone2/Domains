// Build script: bundles the bootstrap orchestrator into a single JS file.
// Output: dist/bootstrap.js — runs with plain `node`, no tsx/pnpm needed.
//
// duckdb-async is marked external because it's a native addon (.node file)
// that can't be bundled. The bootstrap handles this gracefully — corpus-migrate
// and verify-harness have subprocess fallbacks when the dynamic import fails.

import { build } from "esbuild";
import { rmSync, mkdirSync } from "fs";

const outdir = new URL("./dist/", import.meta.url).pathname;

// Clean
rmSync(outdir, { recursive: true, force: true });
mkdirSync(outdir, { recursive: true });

await build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node22",
  format: "esm",
  outfile: "dist/bootstrap.js",
  // Mark native addons as external — they can't be bundled.
  // The code handles missing duckdb-async gracefully with fallbacks.
  external: ["duckdb-async"],
  // Banner to make it a proper ESM module with createRequire for duckdb-async
  banner: {
    js: `import { createRequire as __createRequire } from 'module'; const require = __createRequire(import.meta.url);`,
  },
  // Minify identifiers but keep readable for debugging
  minifySyntax: true,
  treeShaking: true,
  sourcemap: false,
  // Log level
  logLevel: "info",
});

console.log("Built dist/bootstrap.js");
