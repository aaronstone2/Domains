// Bashrc fragment: DEMO/INTERVIEW SAFETY LAYER.
//
// Two functions injected into ~/.bashrc:
//   - demoshell        — drop into a clean subshell with no alias overrides
//   - bashrc-landmines — read-only check that flags shell config that
//                        would break the interview (grep aliased away,
//                        inshellisense process running, bashrc syntax
//                        broken, missing standard tools)
//
// Why these exist: during interview prep, `grep='rg'` silently broke
// `dmesg | grep -iE` and inshellisense corrupted the terminal mid-session.
// Defense in depth: don't ship landmines (the source fix); have an escape
// hatch (demoshell) and a check (bashrc-landmines).
//
// Implementation note: the bash content is stored as an array of lines
// joined with "\n" rather than a template literal because the bash code
// contains BOTH backticks (e.g. \`demoshell\`) AND ${...} parameter
// expansions, both of which conflict with TS template-literal syntax.
// Writing as plain string literals sidesteps all escape issues.

const LINES: readonly string[] = [
  "# ============================================================",
  "# DEMO/INTERVIEW SAFETY LAYER",
  "# ============================================================",
  "#",
  "# demoshell — drops into a clean subshell with all alias overrides cleared.",
  "# Use this during practice + interview screen-share so muscle-memory",
  "# 'grep -E ...' doesn't get hijacked by 'rg', 'cat' isn't 'bat', etc.",
  "# 'exit' returns to your normal shell.",
  "demoshell() {",
  "    bash --noprofile --norc -c '",
  "        export PS1=\"\\[\\033[1;32m\\]demo\\[\\033[0m\\]:\\w\\$ \"",
  "        export PATH=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"",
  "        export EDITOR=\"${EDITOR:-vi}\" PAGER=\"${PAGER:-less}\" LESS=\"${LESS:-FRX}\"",
  "        echo \"demoshell — vanilla bash, no aliases, no shell integrations.\"",
  "        echo \"Type \\\"exit\\\" to return to your normal shell.\"",
  "        exec bash --norc --noprofile -i",
  "    '",
  "}",
  "",
  "# bashrc-landmines — read-only check that flags shell config that will break",
  "# the interview. Call from preflight; safe to invoke any time.",
  "bashrc-landmines() {",
  "    local issues=0",
  "    echo \"=== Bashrc landmine scan ===\"",
  "",
  "    # 1. grep aliased to a non-grep tool",
  "    local grep_alias",
  "    grep_alias=\"$(alias grep 2>/dev/null | sed -n \"s/^alias grep='\\(.*\\)'$/\\1/p\")\"",
  "    if [[ -n \"$grep_alias\" && \"$grep_alias\" != grep* ]]; then",
  "        echo \"  [FAIL] grep is aliased to: $grep_alias  ->  breaks grep -E/-A/-B\"",
  "        issues=$((issues+1))",
  "    else",
  "        echo \"  [OK]   grep alias safe ($grep_alias)\"",
  "    fi",
  "",
  "    # 2. inshellisense process running (terminal corruption source)",
  "    if pgrep -f inshellisense >/dev/null 2>&1; then",
  "        echo \"  [FAIL] inshellisense process active  ->  causes terminal corruption\"",
  "        issues=$((issues+1))",
  "    else",
  "        echo \"  [OK]   no inshellisense process running\"",
  "    fi",
  "",
  "    # 3. bashrc syntax check",
  "    if bash -n ~/.bashrc 2>/dev/null; then",
  "        echo \"  [OK]   ~/.bashrc parses cleanly\"",
  "    else",
  "        echo \"  [FAIL] ~/.bashrc has syntax errors  ->  shell may misbehave\"",
  "        issues=$((issues+1))",
  "    fi",
  "",
  "    # 4. Standard tools resolve to real binaries (type -P bypasses aliases)",
  "    local missing=\"\"",
  "    for c in grep sed awk find ps; do",
  "        [[ -z \"$(type -P \"$c\")\" ]] && missing=\"$missing $c\"",
  "    done",
  "    if [[ -n \"$missing\" ]]; then",
  "        echo \"  [FAIL] missing on PATH:$missing\"",
  "        issues=$((issues+1))",
  "    else",
  "        echo \"  [OK]   standard tools resolve (grep sed awk find ps)\"",
  "    fi",
  "",
  "    # 5. Stale screen size warning",
  "    if [[ \"$(stty size 2>/dev/null | awk \"{print \\$2}\")\" == \"1\" ]]; then",
  "        echo \"  [WARN] terminal reports 1-col width  ->  expect display weirdness\"",
  "    fi",
  "",
  "    echo \"\"",
  "    if [[ $issues -eq 0 ]]; then",
  "        echo \"  Result: clean. Safe for interview/demo.\"",
  "    else",
  "        echo \"  Result: $issues issue(s). Run 'demoshell' for a clean fallback.\"",
  "    fi",
  "    return $issues",
  "}",
  "# ============================================================",
];

export const SAFETY_BLOCK: string = LINES.join("\n");
