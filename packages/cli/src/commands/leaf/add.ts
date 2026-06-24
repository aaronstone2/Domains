import { copyFile, mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import * as p from "@clack/prompts";
import { domainsDir, repoRoot } from "../../paths.ts";

const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

interface ParsedTarget {
  domain: string;
  leaf: string;
}

function parseTarget(arg: string): ParsedTarget {
  const [domain, leaf, ...rest] = arg.split("/");
  if (!domain || !leaf || rest.length > 0) {
    throw new Error(`Invalid target "${arg}". Expected "<domain>/<leaf>", e.g. "methodology/use-red-method".`);
  }
  if (!NAME_RE.test(domain)) {
    throw new Error(`Invalid domain "${domain}". Allowed: ^[a-z0-9][a-z0-9-]*$`);
  }
  if (!NAME_RE.test(leaf)) {
    throw new Error(`Invalid leaf "${leaf}". Allowed: ^[a-z0-9][a-z0-9-]*$`);
  }
  return { domain, leaf };
}

export async function addLeaf(args: string[]): Promise<void> {
  let target = args[0];
  if (!target) {
    const answer = await p.text({
      message: 'Leaf target ("<domain>/<leaf>")?',
      validate: (v) => {
        try {
          parseTarget(v);
          return undefined;
        } catch (e) {
          return e instanceof Error ? e.message : String(e);
        }
      },
    });
    if (p.isCancel(answer)) {
      p.cancel("Cancelled.");
      process.exit(0);
    }
    target = answer;
  }
  const { domain, leaf } = parseTarget(target);

  const domainDir = resolve(domainsDir, domain);
  if (!existsSync(domainDir)) {
    throw new Error(`Domain folder does not exist: domains/${domain}/. Run \`pnpm domain add ${domain}\` first.`);
  }

  const leafDir = resolve(domainDir, leaf);
  await mkdir(leafDir, { recursive: true });

  // README.md (only if missing)
  const readmePath = resolve(leafDir, "README.md");
  if (!existsSync(readmePath)) {
    await writeFile(
      readmePath,
      `# \`${domain}/${leaf}\`\n\nLeaf of the \`${domain}\` domain. See \`PLAN.md\` for the per-leaf phase plan and \`PROGRESS.md\` for the running log.\n`,
    );
  }

  // PLAN.md (copy from template, only if missing)
  const planPath = resolve(leafDir, "PLAN.md");
  if (!existsSync(planPath)) {
    const templatePath = resolve(repoRoot, "domains", "_shared", "PLAN.template.md");
    if (!existsSync(templatePath)) {
      throw new Error(`Missing PLAN template: ${templatePath}`);
    }
    await copyFile(templatePath, planPath);
  }

  // PROGRESS.md (only if missing)
  const progressPath = resolve(leafDir, "PROGRESS.md");
  if (!existsSync(progressPath)) {
    await writeFile(
      progressPath,
      `# \`${domain}/${leaf}\` — PROGRESS log\n\nPer-leaf log; rolls up into \`domains/${domain}/PROGRESS.md\` and \`domains/_shared/PROGRESS.md\`.\n`,
    );
  }

  // STATUS.yaml — machine-readable phase manifest so a fresh session can resume a
  // partially-completed leaf deterministically (see _shared/sessions/extend-playbook.md).
  const statusPath = resolve(leafDir, "STATUS.yaml");
  if (!existsSync(statusPath)) {
    await writeFile(
      statusPath,
      [
        `# Phase manifest — read by a new session to resume where the last one left off.`,
        `# phase states: todo | partial | done`,
        `domain: ${domain}`,
        `leaf: ${leaf}`,
        `depth: standard          # scout | standard | exhaustive (see _shared/sessions/depth-profiles.md)`,
        `phases:`,
        `  meta_research: todo`,
        `  a_survey: todo         # -> sources`,
        `  b_ingest: todo         # -> documents + FTS`,
        `  c_extract: todo        # -> entity tables`,
        `  d_gold: todo           # -> verified facts (the irreducible layer)`,
        `  e_relationships: todo  # -> typed graph`,
        `updated: null`,
        ``,
      ].join("\n"),
    );
  }

  // extract/ and queries/ subdirs (with .gitkeep so they survive empty)
  for (const sub of ["extract", "queries"]) {
    const subDir = resolve(leafDir, sub);
    await mkdir(subDir, { recursive: true });
    const keep = resolve(subDir, ".gitkeep");
    if (!existsSync(keep)) await writeFile(keep, "");
  }

  p.log.success(
    `Scaffolded domains/${domain}/${leaf}/ (README.md, PLAN.md, PROGRESS.md, STATUS.yaml, extract/, queries/) — idempotent.`,
  );
}
