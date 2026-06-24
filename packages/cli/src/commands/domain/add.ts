import { mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import * as p from "@clack/prompts";
import { domainsDir } from "../../paths.ts";

const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

export async function addDomain(args: string[]): Promise<void> {
  let name = args[0];
  if (!name) {
    const answer = await p.text({
      message: "Domain name?",
      validate: (v) => (NAME_RE.test(v) ? undefined : "lowercase letters, digits, hyphens; must start with letter/digit"),
    });
    if (p.isCancel(answer)) {
      p.cancel("Cancelled.");
      process.exit(0);
    }
    name = answer;
  }
  if (!NAME_RE.test(name)) {
    throw new Error(`Invalid domain name "${name}". Allowed: ^[a-z0-9][a-z0-9-]*$`);
  }
  const dir = resolve(domainsDir, name);
  if (existsSync(dir)) {
    throw new Error(`Domain already exists: domains/${name}`);
  }
  await mkdir(dir, { recursive: true });
  await writeFile(resolve(dir, ".gitkeep"), "");

  // Domain-level README + PROGRESS so a new extension is usable immediately.
  await writeFile(
    resolve(dir, "README.md"),
    [
      `# \`${name}\` domain`,
      ``,
      `Top-level research domain. Leaves live in subfolders, each scaffolded with`,
      `\`pnpm leaf add ${name}/<leaf>\` (README, PLAN, PROGRESS, STATUS.yaml, extract/, queries/).`,
      ``,
      `## Optional: domain-specific tables`,
      ``,
      `Every domain gets the shared base schema (sources, documents, concepts, commands,`,
      `config_keys, failure_modes, relationships). To add domain-specific tables, create`,
      `\`schema.${name}.sql\` here using the \`{{schema}}\` placeholder; \`ingest init-db\``,
      `applies it on top of the base and leaves cross-domain \`meta.*\` views untouched.`,
      ``,
      `See \`domains/_shared/sessions/extend-playbook.md\` for the depth-configurable,`,
      `re-engageable research flow.`,
      ``,
    ].join("\n"),
  );
  await writeFile(
    resolve(dir, "PROGRESS.md"),
    `# ${name} — PROGRESS log\n\nPer-domain log; rolls up into \`domains/_shared/PROGRESS.md\`. Per-leaf logs roll up into this file.\n`,
  );

  p.log.success(`Created domains/${name}/ (README.md, PROGRESS.md). Add an optional schema.${name}.sql for domain-specific tables.`);
}
