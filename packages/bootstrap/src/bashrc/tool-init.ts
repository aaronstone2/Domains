// Bashrc fragment: init lines for atuin / zoxide / fzf.
//
// Each tool publishes a "shell init" command (e.g. `atuin init bash`) that
// emits the bash code to wire the tool into the current shell. We eval those
// at startup, gated on the tool being installed.

export const TOOL_INIT_BLOCK: string = `# atuin (shell history with TUI search). Adds Ctrl-R rebinding.
if [[ -d "$HOME/.atuin/bin" ]]; then
  export PATH="$PATH:$HOME/.atuin/bin"
fi
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash)"
fi

# zoxide (smarter cd). Adds 'z <fragment>' to jump to frecent dirs.
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# fzf key bindings (Ctrl-R for fuzzy history if atuin not present, Ctrl-T
# for fuzzy file pick, Alt-C for fuzzy cd).
if [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  source /usr/share/doc/fzf/examples/completion.bash 2>/dev/null || true
fi`;
