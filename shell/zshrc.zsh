# Interactive zsh setup: oh-my-zsh for completion, history and plugins, starship for the prompt.
# Sourced from ~/.zshrc by a line that `install.sh --shell` adds.

[[ -o interactive ]] || return 0
# Claude Code starts its command shell through ~/.zshrc; a prompt framework there only costs time.
[[ -n "${CLAUDECODE-}" ]] && return 0

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""                           # the prompt is starship's
zstyle ':omz:update' mode disabled     # updated by `install.sh --shell`, never in the middle of work
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

export CONDA_CHANGEPS1=false           # starship shows the environment; conda would print it a second time
export STARSHIP_CONFIG="${${(%):-%x}:A:h}/starship.toml"
eval "$(starship init zsh)"
