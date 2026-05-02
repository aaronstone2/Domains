# Domains monorepo

pnpm workspace. Two top-level dirs:

- `domains/<name>/` — research/knowledge domains (folders only for now; will be extended)
- `packages/<name>/` — TS packages, all named `@domains/<name>`

## Commands

Run from repo root:

- `pnpm domain add <name>` — create `domains/<name>/`
- `pnpm package add <name> [--preset=<node|node-cjs|ts|vite|react>]` — scaffold a new `@domains/<name>` package; prompts for tsconfig preset if `--preset` omitted
- `pnpm test` — run vitest across all packages
- `pnpm typecheck` — `tsc --noEmit` across all packages

Both `domain add` and `package add` prompt via `@clack/prompts` if `<name>` is omitted. After `pnpm package add`, run `pnpm install` to register the new workspace package.

## tsconfig: always extend cue

We install [`@mark1russell7/cue`](https://github.com/mark1russell7/cue) via git ref. **Never write a tsconfig from scratch** — always `extends` one of these presets and only override the bare minimum (e.g., extra `types`).

| preset | use for |
| --- | --- |
| `node.json` | Node.js library/CLI, ESM (NodeNext) |
| `node-cjs.json` | Node.js library, CJS |
| `ts.json` | generic TS library, ESM |
| `vite.json` | browser/bundler code |
| `react.json` | React + Vite |

Form: `"extends": "@mark1russell7/cue/ts/config/<preset>.json"`.

Cue's base enables `isolatedDeclarations`, so all exported values need explicit type annotations. If a package executes TS directly with `tsx` (like the CLI) and uses `.ts` import specifiers (NodeNext-correct ESM), add `"noEmit": true` and `"allowImportingTsExtensions": true` in its tsconfig.

## Conventions

- **Vite + Vitest** wherever applicable. Every package gets a `vitest.config.ts`; browser/UI packages use Vite.
- **TypeScript everywhere.** Source under `src/`, no separate build step in dev — root scripts use `tsx` to execute TS directly.
- **Package scope.** All packages are `@domains/<name>`, private, ESM (`"type": "module"`).
- **Naming.** `^[a-z0-9][a-z0-9-]*$` for both domains and packages.

## CLI internals

The CLI lives in `packages/cli/` (`@domains/cli`). Architecture:

```
packages/cli/src/
  index.ts              # arg router: pnpm <group> <sub> [args]
  paths.ts              # repo-root, domains/, packages/ paths
  commands/
    index.ts            # group registry
    domain/{index,add}.ts
    package/{index,add}.ts
```

To add a new subcommand: drop a file in `commands/<group>/<sub>.ts` exporting an `async (args: string[]) => void`, then register it in `commands/<group>/index.ts`. To add a new group, create the folder and register it in `commands/index.ts`.

Root scripts (`pnpm domain ...`, `pnpm package ...`) run `tsx packages/cli/src/index.ts <group>` and pnpm appends the remaining args.
