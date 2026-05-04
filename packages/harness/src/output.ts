// Shared output helpers — TTY-aware ANSI styling, sectioned output, talk-track
// callouts. Used by every harness command so output looks polished and
// consistent when interviewers watch the screen-share live.
//
// When stdout is not a TTY (piped to a file, redirected, etc.) all ANSI
// escapes collapse to plain text so logs stay grep-friendly.

// Writer abstraction — by default writes go to process.stdout (CLI behavior).
// MCP server calls setOut(captureStream) before each tool invocation so the
// harness output goes into a buffer instead of process.stdout (which the MCP
// SDK uses for the JSON-RPC protocol). MCP requests are stdio-serial so a
// module-level mutable writer is safe.
let currentOut: NodeJS.WritableStream = process.stdout;
export function setOut(s: NodeJS.WritableStream): void { currentOut = s; }
export function resetOut(): void { currentOut = process.stdout; }
export function out(): NodeJS.WritableStream { return currentOut; }
export function println(s: string = ""): void { currentOut.write(s + "\n"); }

const isTTY: boolean = !!process.stdout.isTTY && process.env["NO_COLOR"] !== "1";

function wrap(open: string, close: string): (s: string) => string {
  return (s: string) => (isTTY ? `\x1b[${open}m${s}\x1b[${close}m` : s);
}

export const bold: (s: string) => string = wrap("1", "22");
export const dim: (s: string) => string = wrap("2", "22");
export const italic: (s: string) => string = wrap("3", "23");
export const underline: (s: string) => string = wrap("4", "24");

export const red: (s: string) => string = wrap("31", "39");
export const green: (s: string) => string = wrap("32", "39");
export const yellow: (s: string) => string = wrap("33", "39");
export const blue: (s: string) => string = wrap("34", "39");
export const magenta: (s: string) => string = wrap("35", "39");
export const cyan: (s: string) => string = wrap("36", "39");
export const gray: (s: string) => string = wrap("90", "39");

export const bgRed: (s: string) => string = wrap("41", "49");
export const bgYellow: (s: string) => string = wrap("43", "49");
export const bgGreen: (s: string) => string = wrap("42", "49");

const TERM_WIDTH: number = (() => {
  const cols = process.stdout.columns;
  if (typeof cols === "number" && cols >= 40) return Math.min(cols, 100);
  return 80;
})();

// Visible width — strip ANSI escapes before measuring.
function visibleLen(s: string): number {
  return s.replace(/\x1b\[[0-9;]*m/g, "").length;
}

export function hr(char: string = "─"): string {
  return gray(char.repeat(TERM_WIDTH));
}

export function header(title: string, sub?: string): string {
  const top = "┌" + "─".repeat(TERM_WIDTH - 2) + "┐";
  const bot = "└" + "─".repeat(TERM_WIDTH - 2) + "┘";
  const titleLine = padBox(bold(title));
  const lines = [cyan(top), titleLine];
  if (sub) lines.push(padBox(dim(sub)));
  lines.push(cyan(bot));
  return lines.join("\n");
}

function padBox(content: string): string {
  const pad = TERM_WIDTH - 2 - visibleLen(content) - 2;
  const right = pad > 0 ? " ".repeat(pad) : "";
  return cyan("│ ") + content + right + cyan(" │");
}

export function section(label: string): string {
  const left = `── ${bold(label)} `;
  const fillLen = TERM_WIDTH - visibleLen(left);
  const fill = fillLen > 0 ? "─".repeat(fillLen) : "";
  return "\n" + gray("──") + " " + bold(label) + " " + gray(fill);
}

// Aligned 2-column table. cols = [{header, width?}]
export interface Col { header: string; width?: number; align?: "left" | "right" }
export function table(cols: Col[], rows: string[][]): string {
  const widths = cols.map((c, i) => {
    if (c.width) return c.width;
    const cellMax = Math.max(
      visibleLen(c.header),
      ...rows.map((r) => visibleLen(r[i] ?? "")),
    );
    return cellMax;
  });
  const sep = "  ";
  const fmtRow = (cells: string[], styler: (s: string) => string = (s) => s): string =>
    cells
      .map((c, i) => {
        const w = widths[i] ?? 0;
        const text = c ?? "";
        const padLen = w - visibleLen(text);
        const padding = padLen > 0 ? " ".repeat(padLen) : "";
        return cols[i]?.align === "right" ? styler(padding + text) : styler(text + padding);
      })
      .join(sep);
  const headerRow = fmtRow(cols.map((c) => c.header), bold);
  const ruleRow = widths.map((w) => "─".repeat(w)).join(sep);
  return [headerRow, gray(ruleRow), ...rows.map((r) => fmtRow(r))].join("\n");
}

// Talk-track callout. Renders a 4-line structured cue the user can read aloud
// to demonstrate the eval criteria (curiosity → diagnose → fix → trade-offs).
export interface TalkTrackInput {
  symptom: string;
  rootCauseClass?: string | null;
  diagFirstAction?: string | null;
  fixFirstAction?: string | null;
  alternateFms?: string[]; // top other plausible fm ids
}
export function talkTrack(t: TalkTrackInput): string {
  const lines: string[] = [];
  lines.push(bgYellow(bold(" 🎤 TALK TRACK ")) + " " + dim("(read aloud — shows curiosity + tradeoffs)"));
  lines.push("");
  const sym = t.symptom.replace(/\.$/, "");
  const rcc = t.rootCauseClass ? ` Smells like a ${t.rootCauseClass} issue.` : "";
  lines.push(`  ${bold("Frame:")} "Looks like ${sym.toLowerCase()}.${rcc}"`);
  lines.push(`  ${bold("Ask first:")} "Before I touch anything — when did this start, and is it user-impacting now?"`);
  if (t.diagFirstAction) {
    lines.push(`  ${bold("Then diagnose:")} "I'll start by ${t.diagFirstAction.replace(/^["']|["']$/g, "").toLowerCase()} — that confirms the class before I commit to a fix."`);
  }
  if (t.alternateFms && t.alternateFms.length > 0) {
    lines.push(`  ${bold("Trade-off:")} "Could also be ${t.alternateFms.slice(0, 2).join(" or ")} — diag step #1 distinguishes."`);
  }
  if (t.fixFirstAction) {
    lines.push(`  ${bold("Then fix:")} "${t.fixFirstAction.replace(/^["']|["']$/g, "")} — with rollback if it doesn't take."`);
  }
  return lines.join("\n");
}

// Compact citation line — one source per line, dim URL.
export function citationLine(id: string, title: string | null, url: string | null): string {
  const t = title ? `: ${title}` : "";
  const u = url ? "\n    " + dim(url) : "";
  return `  ${cyan("•")} ${bold(id)}${t}${u}`;
}

// Numbered step. step = "1", "2"; prefix one of "diag" / "fix".
export function stepLine(step: number, action: string, kind: "diag" | "fix"): string {
  const tag = kind === "diag" ? yellow(`◆ diag ${step}`) : green(`✓ fix ${step}`);
  return `  ${tag}  ${action}`;
}

export function commandLine(cmd: string): string {
  return `       ${dim("$")} ${cmd}`;
}

export function expectLine(label: string, text: string): string {
  return `       ${dim(label + ":")} ${italic(text)}`;
}

export function chip(label: string, value: string, color: (s: string) => string = blue): string {
  return color(bold(label) + " " + value);
}

// Severity chip helper — red/yellow/green based on confidence (0–1) or count.
export function confidenceChip(conf: number | null): string {
  if (conf === null || conf === undefined) return gray("conf=?");
  if (conf >= 0.85) return green(`conf ${conf.toFixed(2)}`);
  if (conf >= 0.6) return yellow(`conf ${conf.toFixed(2)}`);
  return red(`conf ${conf.toFixed(2)}`);
}

export function domainChip(domain: string): string {
  const colors: Record<string, (s: string) => string> = {
    docker: cyan,
    linux: blue,
    k8s: magenta,
    devin: green,
    methodology: yellow,
    firecracker: red,
    ecs: gray,
  };
  const c = colors[domain] ?? gray;
  return c(`[${domain}]`);
}
