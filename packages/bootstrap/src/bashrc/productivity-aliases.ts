// Bashrc fragment: productivity aliases.
//
// Replaces the legacy bash block at lines 415-420. CRITICAL DELTA: the
// 'grep=rg' alias is GONE. ripgrep is still installed and on PATH as 'rg';
// users can call it deliberately. We do NOT silently shadow grep, because:
//
//   1. grep -E / -A / -B have flag semantics ripgrep doesn't share, so
//      shell scripts written against grep break under the alias.
//   2. dmesg | grep -iE 'oom|killed' is a muscle-memory pattern that
//      silently fails under the alias.
//   3. Standard interview-day commands assume grep is grep.
//
// Other aliases (ls=eza, cat=bat, cd=z) are kept because their replacements
// are largely flag-compatible. demoshell() (in safety.ts) provides an
// escape hatch if any of them ever cause issues.

export const PRODUCTIVITY_ALIASES_BLOCK: string = `# Productivity aliases (graceful fallback if tool isn't installed).
# NOTE: grep is intentionally NOT aliased to ripgrep. See safety.ts for why.
command -v eza    >/dev/null && alias ls='eza --icons --group-directories-first'
command -v batcat >/dev/null && alias cat='batcat --paging=never --plain'
command -v bat    >/dev/null && alias cat='bat --paging=never --plain'
command -v zoxide >/dev/null && alias cd='z'`;
