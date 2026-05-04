// Logger — single source of truth for output formatting. Replaces the
// duplicated bash echo helpers (step/ok/warn/skip/fail) scattered across
// the legacy script. ANSI colors via raw escape codes — no chalk dep.

const ANSI: {
  readonly reset: string;
  readonly bold: string;
  readonly dim: string;
  readonly green: string;
  readonly yellow: string;
  readonly red: string;
  readonly blue: string;
  readonly cyan: string;
} = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  green: "\x1b[0;32m",
  yellow: "\x1b[0;33m",
  red: "\x1b[0;31m",
  blue: "\x1b[0;34m",
  cyan: "\x1b[0;36m",
};

const stripAnsi = (s: string): string => s.replace(/\x1b\[[0-9;]*m/g, "");

export class Logger {
  private readonly useColor: boolean;
  private readonly prefix: string;

  constructor(opts: { readonly useColor?: boolean; readonly prefix?: string } = {}) {
    this.useColor = opts.useColor ?? (process.stdout.isTTY === true);
    this.prefix = opts.prefix ?? "";
  }

  private fmt(color: string, s: string): string {
    return this.useColor ? `${color}${s}${ANSI.reset}` : stripAnsi(s);
  }

  /** Section heading — used for major phases (e.g. "installing tools"). */
  step(msg: string): void {
    process.stdout.write(`\n${this.fmt(ANSI.cyan + ANSI.bold, "==>")} ${this.prefix}${msg}\n`);
  }

  /** Success — used for completed sub-tasks. */
  ok(msg: string): void {
    process.stdout.write(`  ${this.fmt(ANSI.green, "ok")}    ${this.prefix}${msg}\n`);
  }

  /** Warning — non-fatal issue; install continues. */
  warn(msg: string): void {
    process.stdout.write(`  ${this.fmt(ANSI.yellow, "warn")}  ${this.prefix}${msg}\n`);
  }

  /** Skip — module decided not to run (e.g. --with-docker not set). */
  skip(msg: string): void {
    process.stdout.write(`  ${this.fmt(ANSI.dim, "skip")}  ${this.prefix}${msg}\n`);
  }

  /** Failure — write to stderr; install continues to next module. */
  fail(msg: string): void {
    process.stderr.write(`  ${this.fmt(ANSI.red + ANSI.bold, "FAIL")}  ${this.prefix}${msg}\n`);
  }

  /** Info — same channel as step but smaller. */
  info(msg: string): void {
    process.stdout.write(`  ${this.fmt(ANSI.blue, "info")}  ${this.prefix}${msg}\n`);
  }

  /** Raw — no formatting, no prefix. Used for pass-through of subprocess output. */
  raw(msg: string): void {
    process.stdout.write(msg);
  }

  /** Returns a child logger that prepends `[childPrefix] ` to every line. */
  child(childPrefix: string): Logger {
    return new Logger({
      useColor: this.useColor,
      prefix: this.prefix === "" ? `[${childPrefix}] ` : `${this.prefix}[${childPrefix}] `,
    });
  }
}

/** Convenience for ad-hoc one-off logging without instantiating. */
export const defaultLogger: Logger = new Logger();
