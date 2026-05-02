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
  p.log.success(`Created domains/${name}/`);
}
