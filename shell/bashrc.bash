# Interactive bash setup: oh-my-bash for completion and plugins, starship for the prompt.
# Sourced from ~/.bashrc by a line that `install.sh --shell` adds.

[[ $- == *i* ]] || return 0
# Claude Code starts its command shell through ~/.bashrc; a prompt framework there only costs time.
[[ -n "${CLAUDECODE-}" ]] && return 0

# a ~/.bashrc written by oh-my-bash's own installer has loaded it already
if ! declare -F _omb_module_require >/dev/null; then
  export OSH="$HOME/.oh-my-bash"
  OSH_THEME=""                         # the prompt is starship's
  DISABLE_AUTO_UPDATE=true             # updated by `install.sh --shell`, never in the middle of work
  completions=(git ssh)
  aliases=()                           # the "general" set turns cp and mv into prompting commands
  plugins=(git)
  source "$OSH/oh-my-bash.sh"
fi

export CONDA_CHANGEPS1=false           # starship shows the environment; conda would print it a second time
export STARSHIP_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/starship.toml"
eval "$(starship init bash)"
