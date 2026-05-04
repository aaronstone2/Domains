// Module: docker-completion — write a static fallback for docker bash
// completion. Docker Desktop installs a symlink at
// /usr/share/bash-completion/completions/docker → /mnt/wsl/docker-desktop/...
// that frequently breaks (the WSL mount disappears between sessions). Our
// fallback lives at $HOME/.local/share/bash-completion/completions/docker
// and is sourced unconditionally by the bashrc managed block.
//
// Once Docker Desktop's WSL integration is stable AND the user prefers the
// upstream completion, they can replace with:
//   docker completion bash > ~/.local/share/bash-completion/completions/docker

import * as path from "node:path";

import type { InstallContext, InstallerModule, VerifyResult } from "../lib/types.ts";

const TARGET = ".local/share/bash-completion/completions/docker";

const DOCKER_COMPLETION_BODY: string = `# Minimal bash completion for docker — installed by @domains/bootstrap.
# Replaces broken Docker Desktop symlinks. To upgrade later:
#   docker completion bash > ~/.local/share/bash-completion/completions/docker

_docker_min() {
    local cur prev words cword
    _init_completion || return

    local subcmds="
        attach build builder buildx checkpoint commit compose config container
        context cp create diff events exec export history image images
        import info inspect kill load login logout logs manifest network
        node plugin port ps pull push rename restart rm rmi run save scan
        search secret service stack start stats stop swarm system tag top
        trust unpause update version volume wait
        completion
    "

    local ps_flags="-a --all -q --quiet --filter --format --last --latest --no-trunc --size"
    local logs_flags="-f --follow --tail --since --until -t --timestamps --details"
    local run_flags="-d --detach -it --rm --name --network --env -e --env-file -v --volume -p --publish --memory --cpus --restart --user --entrypoint"
    local exec_flags="-it --user --workdir --env -e --detach -d --privileged"

    if [ "$cword" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$subcmds" -- "$cur") )
        return 0
    fi

    case "\${words[1]}" in
        ps)
            COMPREPLY=( $(compgen -W "$ps_flags" -- "$cur") )
            return 0
            ;;
        logs)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$logs_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            fi
            return 0
            ;;
        run)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$run_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur") )
            fi
            return 0
            ;;
        exec)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$exec_flags" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$(docker ps --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            fi
            return 0
            ;;
        inspect|stop|start|restart|kill|rm|pause|unpause|wait|top|attach|cp|diff|stats)
            COMPREPLY=( $(compgen -W "$(docker ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur") )
            return 0
            ;;
        rmi|history|tag|push|pull|save)
            COMPREPLY=( $(compgen -W "$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur") )
            return 0
            ;;
        network|volume|system|image|container|builder|context)
            local sub2="ls inspect rm prune create"
            [ "\${words[1]}" = "system" ] && sub2="info df events prune"
            [ "\${words[1]}" = "context" ] && sub2="ls inspect use create rm"
            if [ "$cword" -eq 2 ]; then
                COMPREPLY=( $(compgen -W "$sub2" -- "$cur") )
            fi
            return 0
            ;;
    esac
}

complete -F _docker_min docker
`;

export const dockerCompletionModule: InstallerModule = {
  id: "docker-completion",
  description: "User-local docker bash completion fallback (handles broken Docker Desktop symlink)",
  tags: ["shell", "docker"],

  shouldRun(config): boolean {
    return !config.noShellConfig;
  },

  async isInstalled(ctx: InstallContext): Promise<boolean> {
    const target = path.join(ctx.home, TARGET);
    if (!(await ctx.runner.pathExists(target))) return false;
    const result = await ctx.runner.run(`grep -q '_docker_min' ${target}`, { allowFailure: true });
    return result.code === 0;
  },

  async install(ctx: InstallContext): Promise<void> {
    const target = path.join(ctx.home, TARGET);
    await ctx.runner.writeFile(target, DOCKER_COMPLETION_BODY);
    ctx.logger.ok(`wrote docker completion to ${target}`);
  },

  async verify(ctx: InstallContext): Promise<VerifyResult> {
    const target = path.join(ctx.home, TARGET);
    if (!(await ctx.runner.pathExists(target))) {
      return { ok: false, message: `${target} missing` };
    }
    return { ok: true, message: "docker completion file present" };
  },
};
