import * as p from "@clack/prompts";
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline/promises";

const here: string = dirname(fileURLToPath(import.meta.url));
const DRILLS_DIR: string = join(here, "..", "..", "drills");

interface DrillTurn {
  user_message: string;
  se_response_summary: string;
  expected_harness_commands: string[];
  expected_keywords: string[];
  hints: string[];
}

interface Drill {
  id: string;
  title: string;
  difficulty: string;
  domains: string[];
  primary_fm: string | null;
  scenario_md: string;
  turns: DrillTurn[];
}

function listDrills(): Drill[] {
  const files = readdirSync(DRILLS_DIR).filter((f) => f.endsWith(".json"));
  return files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(DRILLS_DIR, f), "utf8")) as Drill;
      } catch {
        return null;
      }
    })
    .filter((d): d is Drill => d !== null);
}

function loadDrill(id: string): Drill | null {
  // accept "01" or "01-docker-oom" or full filename
  const stripped = id.replace(/\.json$/i, "");
  const all = listDrills();
  const direct = all.find((d) => d.id === stripped);
  if (direct) return direct;
  const byPrefix = all.find((d) => d.id.startsWith(stripped));
  if (byPrefix) return byPrefix;
  const byNumber = all.find((d) => d.id.startsWith(`${stripped.padStart(2, "0")}-`));
  return byNumber ?? null;
}

function pickRandom<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]!;
}

function dim(s: string): string {
  return `\x1b[90m${s}\x1b[0m`;
}
function bold(s: string): string {
  return `\x1b[1m${s}\x1b[0m`;
}
function green(s: string): string {
  return `\x1b[32m${s}\x1b[0m`;
}
function yellow(s: string): string {
  return `\x1b[33m${s}\x1b[0m`;
}
function cyan(s: string): string {
  return `\x1b[36m${s}\x1b[0m`;
}

interface TurnScore {
  commands_hit: string[];
  commands_missed: string[];
  keywords_hit: string[];
  keywords_missed: string[];
}

function scoreTurn(answer: string, turn: DrillTurn): TurnScore {
  const lower = answer.toLowerCase();
  const commands_hit: string[] = [];
  const commands_missed: string[] = [];
  for (const cmd of turn.expected_harness_commands) {
    if (lower.includes(cmd.toLowerCase())) {
      commands_hit.push(cmd);
    } else {
      commands_missed.push(cmd);
    }
  }
  const keywords_hit: string[] = [];
  const keywords_missed: string[] = [];
  for (const kw of turn.expected_keywords) {
    if (lower.includes(kw.toLowerCase())) {
      keywords_hit.push(kw);
    } else {
      keywords_missed.push(kw);
    }
  }
  return { commands_hit, commands_missed, keywords_hit, keywords_missed };
}

interface InputSource {
  next(): Promise<string | null>;
  close(): void;
}

function makeInputSource(): InputSource {
  const isTTY = Boolean(process.stdin.isTTY);
  if (isTTY) {
    const rl = createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: true,
    });
    return {
      next: async () => {
        try {
          return await rl.question("> ");
        } catch {
          return null;
        }
      },
      close: () => rl.close(),
    };
  }
  // Non-TTY: read all stdin upfront, queue lines.
  const chunks: Buffer[] = [];
  let resolved: Promise<string[]> | null = null;
  function ensureLoaded(): Promise<string[]> {
    if (resolved) return resolved;
    resolved = new Promise((resolve) => {
      process.stdin.on("data", (c: Buffer) => chunks.push(c));
      process.stdin.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve(text.split(/\r?\n/));
      });
      process.stdin.on("error", () => resolve([]));
    });
    return resolved;
  }
  let idx = 0;
  return {
    next: async () => {
      const lines = await ensureLoaded();
      if (idx >= lines.length) return null;
      const line = lines[idx]!;
      idx++;
      console.log(`> ${line}`);
      return line;
    },
    close: () => {
      try {
        process.stdin.pause();
      } catch {
        // ignore
      }
    },
  };
}

async function readMultilineAnswer(input: InputSource): Promise<string> {
  const lines: string[] = [];
  for (;;) {
    const line = await input.next();
    if (line === null) {
      // stdin EOF — treat accumulated buffer as done
      return lines.join("\n");
    }
    const trimmed = line.trim();
    if (trimmed === "") continue;
    if (trimmed === "." || trimmed === ".send") break;
    if (
      trimmed === "hint" ||
      trimmed === "skip" ||
      trimmed === "show" ||
      trimmed === "quit"
    ) {
      return trimmed;
    }
    lines.push(line);
  }
  return lines.join("\n");
}

interface RunOptions {
  showFullOnComplete: boolean;
}

async function runDrill(drill: Drill, opts: RunOptions): Promise<void> {
  console.log("");
  console.log(bold(`=== Drill: ${drill.title} ===`));
  console.log(
    dim(`difficulty=${drill.difficulty}  domains=${drill.domains.join(",")}  turns=${drill.turns.length}`),
  );
  if (drill.primary_fm) console.log(dim(`primary_fm=${drill.primary_fm}`));
  console.log("");
  console.log(
    dim(
      "How this works: each turn shows a user message; type your SE response; finish with `.` on a line by itself. Special: `hint` (next hint), `show` (reveal canonical without scoring), `skip` (no scoring), `quit` (exit).",
    ),
  );
  console.log("");

  const inputSource = makeInputSource();

  const turnScores: TurnScore[] = [];
  let turnNumber = 0;
  try {
    for (const turn of drill.turns) {
      turnNumber++;
      console.log(bold(`--- Turn ${turnNumber}/${drill.turns.length} ---`));
      console.log("");
      console.log(yellow(`USER:`));
      console.log(turn.user_message);
      console.log("");
      console.log(cyan("YOUR RESPONSE (finish with `.` on a line by itself; or `hint`, `show`, `skip`, `quit`):"));

      let hintsShown = 0;
      let answer = "";
      let revealed = false;
      let skipped = false;

      for (;;) {
        const input = await readMultilineAnswer(inputSource);
        if (input === "quit") {
          console.log(dim("Drill aborted."));
          return;
        }
        if (input === "skip") {
          console.log(dim("Skipping this turn."));
          skipped = true;
          break;
        }
        if (input === "show") {
          console.log("");
          console.log(green(`SE response (revealed):`));
          console.log(turn.se_response_summary);
          console.log("");
          revealed = true;
          break;
        }
        if (input === "hint") {
          if (hintsShown >= turn.hints.length) {
            console.log(dim("(no more hints)"));
          } else {
            console.log(dim(`hint ${hintsShown + 1}/${turn.hints.length}: ${turn.hints[hintsShown]}`));
            hintsShown++;
          }
          continue;
        }
        answer = input;
        break;
      }

      if (skipped || revealed) {
        if (revealed) {
          turnScores.push({
            commands_hit: [],
            commands_missed: turn.expected_harness_commands,
            keywords_hit: [],
            keywords_missed: turn.expected_keywords,
          });
        }
        console.log("");
        continue;
      }

      const score = scoreTurn(answer, turn);
      turnScores.push(score);

      const totalExpected =
        turn.expected_harness_commands.length + turn.expected_keywords.length;
      const totalHit = score.commands_hit.length + score.keywords_hit.length;
      console.log("");
      console.log(
        bold(`Coverage: ${totalHit}/${totalExpected} (${turn.expected_harness_commands.length} cmds + ${turn.expected_keywords.length} keywords expected)`),
      );
      if (score.commands_hit.length > 0) {
        console.log(green(`✓ commands hit: ${score.commands_hit.join(", ")}`));
      }
      if (score.commands_missed.length > 0) {
        console.log(yellow(`◯ commands missed: ${score.commands_missed.join(", ")}`));
      }
      if (score.keywords_hit.length > 0) {
        console.log(green(`✓ keywords hit: ${score.keywords_hit.join(", ")}`));
      }
      if (score.keywords_missed.length > 0) {
        console.log(yellow(`◯ keywords missed: ${score.keywords_missed.join(", ")}`));
      }
      console.log("");
      console.log(green(`SE response:`));
      console.log(turn.se_response_summary);
      console.log("");
    }
  } finally {
    inputSource.close();
  }

  // Final summary
  const totalCmds = turnScores.reduce(
    (s, t) => s + t.commands_hit.length + t.commands_missed.length,
    0,
  );
  const hitCmds = turnScores.reduce((s, t) => s + t.commands_hit.length, 0);
  const totalKws = turnScores.reduce(
    (s, t) => s + t.keywords_hit.length + t.keywords_missed.length,
    0,
  );
  const hitKws = turnScores.reduce((s, t) => s + t.keywords_hit.length, 0);

  console.log(bold("=== Final summary ==="));
  console.log(`commands: ${hitCmds}/${totalCmds}`);
  console.log(`keywords: ${hitKws}/${totalKws}`);
  console.log("");

  const missedKws = turnScores.flatMap((t) => t.keywords_missed);
  if (missedKws.length > 0) {
    const unique = [...new Set(missedKws)];
    console.log(yellow(`Top missed concepts (study these): ${unique.slice(0, 12).join(", ")}`));
    console.log("");
  }

  console.log(dim(`Full markdown scenario: ${drill.scenario_md}`));
  if (opts.showFullOnComplete) {
    try {
      const full = readFileSync(
        join(here, "..", "..", "..", "..", drill.scenario_md),
        "utf8",
      );
      console.log("");
      console.log(full);
    } catch {
      console.log(dim("(could not read scenario markdown)"));
    }
  }
}

interface ParsedArgs {
  list: boolean;
  random: boolean;
  drillId: string | null;
  showFull: boolean;
}

function parseArgs(args: string[]): ParsedArgs {
  let list = false;
  let random = false;
  let drillId: string | null = null;
  let showFull = false;
  for (const a of args) {
    if (a === "--list") list = true;
    else if (a === "--random" || a === "random") random = true;
    else if (a === "--show-full") showFull = true;
    else if (!a.startsWith("--")) drillId = a;
  }
  return { list, random, drillId, showFull };
}

export async function drillCmd(args: string[]): Promise<void> {
  const { list, random, drillId, showFull } = parseArgs(args);

  if (list) {
    const all = listDrills();
    p.log.info("Available drills:");
    for (const d of all) {
      console.log(
        `  ${d.id.padEnd(28)} [${d.difficulty.padEnd(10)}] ${d.title}`,
      );
    }
    console.log("\nUsage:");
    console.log("  pnpm harness drill <id|number>     # e.g. 01 or 01-docker-oom");
    console.log("  pnpm harness drill random          # random drill");
    console.log("  pnpm harness drill <id> --show-full  # also print full scenario.md after");
    return;
  }

  let drill: Drill | null = null;
  if (random) {
    drill = pickRandom(listDrills());
  } else if (drillId) {
    drill = loadDrill(drillId);
    if (!drill) {
      p.log.error(`drill not found: ${drillId}`);
      p.log.info("Run `pnpm harness drill --list` to see available drills.");
      process.exit(2);
    }
  } else {
    p.log.error("usage: harness drill <id|number> | random | --list");
    process.exit(1);
  }

  await runDrill(drill, { showFullOnComplete: showFull });
}
