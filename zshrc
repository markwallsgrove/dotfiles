# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git ant go grunt nvm node sudo tmux bower composer gitfast jsontools npm docker-compose rails rake)

# User configuration

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/go/bin:/home/smoky/workspace/golang/bin"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
#
export VISUAL=vim
export EDITOR="$VISUAL"

function collapse_pwd {
    echo $(pwd | sed -e "s,^$HOME,~,")
}

directory_name() {
    PROMPT_PATH=""

    CURRENT=`dirname ${PWD}`
    if [[ $CURRENT = / ]]; then
        PROMPT_PATH=""
    elif [[ $PWD = $HOME ]]; then
        PROMPT_PATH=""
    else
        PROMPT_PATH=$(print -P %3~)
        PROMPT_PATH="${PROMPT_PATH%/*}/"
    fi
    echo "%{$fg_bold[cyan]%}${PROMPT_PATH}%{$reset_color%}%{$fg[red]%}%1~%{$reset_color%}"
}

dir=$'$ $(directory_name)'
export PROMPT="$dir $PROMPT"

if [ -f ~/.security ]; then
    source ~/.security
fi

if [ -f ~/.aliases ]; then
    source ~/.aliases
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

autoload -U compinit && compinit
autoload -U bashcompinit && bashcompinit

export PATH="$PATH:$HOME/.ec2.cli"
script_dir=$(dirname $0)
if [ -f ~/.ec2.cli/completion.bash ]; then
	source ~/.ec2.cli/completion.bash
fi

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
source /home/smoky/.rvm/scripts/rvm
export PATH="$PATH:/home/smoky/.bin"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bind caps lock to ctrl
setxkbmap -option ctrl:nocaps

source ~/.exports
