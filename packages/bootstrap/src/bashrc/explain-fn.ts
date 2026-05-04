// Bashrc fragment: explain() helper.
//
// One-liner that wraps `claude --print "Explain this concisely + suggest a
// fix: ..."`. Inherited from the legacy bash for parity.

export const EXPLAIN_FN_BLOCK: string = `# Quick claude wrapper for one-shot questions
explain() {
  if command -v claude >/dev/null 2>&1; then
    claude --print "Explain this concisely + suggest a fix: $*"
  else
    echo "claude not installed (run bootstrap install)" >&2
  fi
}`;
