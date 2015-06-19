#
# .zshrc is sourced in interactive shells.
# It should contain commands to set up aliases,
# functions, options, key bindings, etc.
#

autoload -U compinit
compinit

#allow tab completion in the middle of a word
setopt COMPLETE_IN_WORD

export IDEA_JDK="/usr/java/jdk1.6.0_38"
export PATH=/workplace/bmulder/BrianDotFiles/src/BrianDotFiles/scripts:$PATH

export RPMDIR=$HOME/rpm

# export PATH=$HOME/code/BuysDotfiles/home/bin
# export PATH="$JAVA_HOME/bin:$PATH"

## keep background processes at full speed
#setopt NOBGNICE
## restart running processes on exit
#setopt HUP

## history
#setopt APPEND_HISTORY
## for sharing history between zsh processes
#setopt INC_APPEND_HISTORY
#setopt SHARE_HISTORY

## never ever beep ever
#setopt NO_BEEP

## automatically decide when to page a list of completions
#LISTMAX=0

## disable mail checking
#MAILCHECK=0

# autoload -U colors
#colors

# Functions
source /workplace/bmulder/BrianDotFiles/src/BrianDotFiles/zsh/functions

# Aliases
source /workplace/bmulder/BrianDotFiles/src/BrianDotFiles/zsh/aliases.rhel

# tmux/tmuxinator
export TERM=xterm-256color

ensure_kerberos() {
    klist -s || kinit -f
}
 
precmd() {
    ensure_kerberos
}

# SSH Magic (link: https://w.amazon.com/index.php/EC2/Security/Howto/Setup_SSH_Credential_Forwarding)
AGENT_SOCKET=$HOME/.ssh/.ssh-agent-socket
AGENT_INFO=$HOME/.ssh/.ssh-agent-info
SCSSH_AGENT=#path to folder with ssh-agent and ssh-add

if [[ -s "$AGENT_INFO" ]]
then
    source $AGENT_INFO
fi
 
other=0
if [[ -z "$SSH_AGENT_PID" ]]
then
    running=0
else
    running=0
    for u in `ps -C ssh-agent -o pid=`
    do
        if [[ "$running" != "1" ]]
        then
            if [[ "$SSH_AGENT_PID" != "$u" ]]
            then
                running=2
                other=$u
            else
                running=1
                echo "Agent $u Already Running"
            fi
        fi
    done
fi
 
if [[ "$running" != "1" ]]
then
    echo "Re-starting Agent"
    killall -15 ssh-agent
    eval `$SCSSH_AGENT/ssh-agent -s -a $AGENT_SOCKET`
    echo "export SSH_AGENT_PID=$SSH_AGENT_PID" > $AGENT_INFO
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $AGENT_INFO
    for file in `ls -1 ~/.ssh/id_dsa`
    do
        ssh-add $file
    done
    $SCSSH_AGENT/ssh-add -s /usr/lib64/libeToken.so
elif [[ "$other" != "0" ]]
then
    if ps -p $other|grep $other|grep defunct >/dev/null
    then
        echo "DEFUNCT process $other is still running"
    else
        echo "WARNING!! non defunct process $other is still running"
    fi
fi

# If we are starting a shell with a socket already set, then it must be a good one
if [ $SSH_AUTH_SOCK ]
then
  if [ $SSH_AUTH_SOCK != $HOME/.ssh_auth_sock ]
  then
    rm $HOME/.ssh_auth_sock
    ln -s $SSH_AUTH_SOCK $HOME/.ssh_auth_sock
  fi    
fi
export SSH_AUTH_SOCK=$HOME/.ssh_auth_sock

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init - )"