// Bashrc fragment: source repo-local aliases if present.
//
// The domains repo can ship a $REPO/.aliases file with project-specific
// shortcuts (e.g. `ha` → `pnpm harness ask`). We source it after our own
// aliases so the repo can override.

export function repoAliasesBlock(repoDir: string): string {
  // Use literal $REPO_DIR substitution at write time so the resulting bashrc
  // line is portable even if the user's $HOME differs at install vs runtime.
  return `# Repo-specific aliases (sourced from current dir of repo)
if [[ -f "${repoDir}/.aliases" ]]; then
  source "${repoDir}/.aliases"
fi`;
}
