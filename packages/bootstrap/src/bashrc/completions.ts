// Bashrc fragment: bash-completion framework + per-tool completions.
//
// The default Ubuntu bashrc has the framework-source block commented out;
// most users never enable it and end up with no Tab completion. We always
// source it (gated on the file existing) and then chain the user-local
// per-tool completion dir, which is where docker-completion.ts writes its
// fallback file when Docker Desktop's symlink is broken.

export const COMPLETIONS_BLOCK: string = `# bash-completion framework + per-tool completions
if ! shopt -oq posix 2>/dev/null; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    source /etc/bash_completion
  fi
fi

# User-local docker completion (fallback when Docker Desktop symlink is dead).
# The bootstrap docker-completion module writes to this path.
if [[ -f "$HOME/.local/share/bash-completion/completions/docker" ]]; then
  source "$HOME/.local/share/bash-completion/completions/docker"
fi`;
