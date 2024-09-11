# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                                                                            ║
# ║  /\/|  ___               _                   _    _ _                      ║
# ║ |/\/  / / |__   __ _ ___| |__  _ __ ___     / \  | (_) __ _ ___  ___  ___  ║
# ║      / /| '_ \ / _` / __| '_ \| '__/ __|   / _ \ | | |/ _` / __|/ _ \/ __| ║
# ║     / / | |_) | (_| \__ \ | | | | | (__   / ___ \| | | (_| \__ \  __/\__ \ ║
# ║    /_(_)|_.__/ \__,_|___/_| |_|_|  \___| /_/   \_\_|_|\__,_|___/\___||___/ ║
# ║                                                                            ║
# ╚════════════════════════════════════════════════════════════════════════════╝
#  https://github.com/cagatayuresin

#######################################################
#          Essential Aliases
#######################################################

# Alias for installing packages with apt
alias get="sudo apt install -y"

# Update package list and upgrade all packages
alias upgrade="sudo apt update && sudo apt upgrade -y"

# Clear the terminal screen
alias clr="clear"

# Edit the .bashrc file with vi editor
alias bashrc="vi ~/.bashrc"

# Colorful ls command
alias ls="ls --color=auto"

# List all files, including hidden files (-a) in long format (-l)
alias ll="ls -la"

# List only hidden files and directories
alias l.="ls -d .* --color=auto"

# Colorful grep command
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"

# Show command history
alias h="history"

# List active jobs with details
alias j="jobs -l"

# Display open network ports
alias ports="netstat -tulanp"

# List iptables rules with line numbers
alias iptlist="sudo /sbin/iptables -L -n -v --line-numbers"
alias iptlistin="sudo /sbin/iptables -L INPUT -n -v --line-numbers"
alias iptlistout="sudo /sbin/iptables -L OUTPUT -n -v --line-numbers"
alias iptlistfw="sudo /sbin/iptables -L FORWARD -n -v --line-numbers"

# Show memory info in megabytes
alias meminfo="free -m -l -t"

# List processes sorted by memory usage
alias psmem="ps auxf | sort -nr -k 4"
alias psmem10="ps auxf | sort -nr -k 4 | head -10"

# List processes sorted by CPU usage
alias pscpu="ps auxf | sort -nr -k 3"
alias pscpu10="ps auxf | sort -nr -k 3 | head -10"

# Show CPU info
alias cpuinfo="lscpu"

# Show GPU memory info
alias gpumeminfo="grep -i --color memory /var/log/Xorg.0.log"

#######################################################
#               Git Aliases
#######################################################

# git
alias g="git"

# Git status
alias gs="git status"

# Git add
alias ga="git add"

# Git commit
alias gc="git commit"

# Git commit with message
alias gcm="git commit -m"

# Git amend commit
alias gca="git commit --amend"

# Git checkout
alias gco="git checkout"

# Git branch
alias gb="git branch"

# Git list all branches
alias gba="git branch -a"

# Git delete branch
alias gbd="git branch -d"

# Git rename branch
alias gbm="git branch -m"

# Git list merged branches
alias gbs="git branch --merged"

# Git clone
alias gcl="git clone"

# Git cherry-pick
alias gcp="git cherry-pick"

# Git diff
alias gd="git diff"

# Git diff staged changes
alias gds="git diff --staged"

# Git log
alias gl="git log"

# Git log with graph
alias glg="git log --graph --oneline --decorate --all"

# Git pull
alias gp="git pull"

# Git pull with rebase
alias gpr="git pull --rebase"

# Git push to origin
alias gpo="git push origin"

# Git push force
alias gpf="git push --force"

# Git push with tags
alias gpt="git push --tags"

# Git fetch
alias gf="git fetch"

# Git merge
alias gm="git merge"

# Git merge abort
alias gma="git merge --abort"

# Git merge continue
alias gmc="git merge --continue"

# Git merge tool
alias gmt="git mergetool"

# Git pull and push
alias gpp="git pull && git push"

# Git rebase
alias gr="git rebase"
alias grc="git rebase --continue"
alias gra="git rebase --abort"
alias grs="git rebase --skip"

# Git reset
alias grh="git reset --hard"
alias grs="git reset --soft"
alias grm="git reset --mixed"

# Git revert
alias grv="git revert"

# Git stash
alias gst="git stash"
alias gsta="git stash apply"
alias gstp="git stash pop"
alias gstd="git stash drop"
alias gsts="git stash show --text"

# Gitk and Gitx for visual git history
alias gk="gitk --all&"
alias gx="gitx --all"

#######################################################
#            Docker Aliases
#######################################################

# Docker commands
alias d="docker"

# Docker Compose commands
alias dc="docker-compose"
alias dce="docker-compose exec"
alias dcl="docker-compose logs"
alias dclf="docker-compose logs -f"
alias dcr="docker-compose run"
alias dcrm="docker-compose rm"
alias dcs="docker-compose stop"
alias dcu="docker-compose up"
alias dcud="docker-compose up -d"
alias dcd="docker-compose down"
alias dcdv="docker-compose down -v"
alias dcdva="docker-compose down --volumes --rmi all"
alias dcdvaf="docker-compose down --volumes --rmi all --remove-orphans"

#######################################################
#          Kubernetes Aliases
#######################################################

# kubectl
alias k="kubectl"

# Kubernetes get commands
alias kg="kubectl get"
alias kgp="kubectl get pods"
alias kgs="kubectl get services"
alias kgc="kubectl get configmaps"
alias kgi="kubectl get ingresses"
alias kgn="kubectl get namespaces"
alias kgr="kubectl get replicasets"

# Kubernetes describe commands
alias kdp="kubectl describe pods"
alias kds="kubectl describe services"
alias kdc="kubectl describe configmaps"
alias kdi="kubectl describe ingresses"
alias kdn="kubectl describe namespaces"
alias kdr="kubectl describe replicasets"
alias kd="kubectl describe"

# Apply and delete Kubernetes configs
alias kaf="kubectl apply -f"
alias kdf="kubectl delete -f"

# Kubernetes exec and logs
alias kex="kubectl exec -it"
alias klo="kubectl logs -f"
alias klof="kubectl logs -f --tail 0"
alias kloa="kubectl logs --all-containers -f"
alias klofa="kubectl logs --all-containers -f --tail 0"

#######################################################
#         Terraform Aliases
#######################################################

# Terraform commands
alias tf="terraform"
alias tfi="terraform init"
alias tfa="terraform apply"
alias tfd="terraform destroy"
alias tff="terraform fmt"
alias tfp="terraform plan"
alias tfs="terraform show"
alias tfo="terraform output"
alias tfl="terraform validate"
alias tfw="terraform workspace"
alias tfws="terraform workspace select"
alias tfwn="terraform workspace new"
alias tfwd="terraform workspace delete"

#######################################################
#          Miscellaneous Aliases
#######################################################

alias dus="du -sh *"
alias myip="curl ifconfig.me"
alias now="date +'%Y-%m-%d %H:%M:%S'"

#######################################################
#          Python Aliases
#######################################################

# Python3
alias py="python3"

# Python3 pip
alias pip="python3 -m pip"

# Python3 upgrade pip
alias pipup="python3 -m pip install --upgrade pip"

# Python3 list installed packages
alias pipl="pip list"

# Python3 install package
alias pipi="python3 -m pip install"

# Python3 uninstall package
alias pipu="python3 -m pip uninstall"

# Python3 virtualenv
alias venv="python3 -m pip install --upgrade pip && python3 -m venv"

# Python3 make venv and activate
alias venva="python3 -m pip install --upgrade pip && python3 -m venv venv && source venv/bin/activate"

# Python3 deactivate venv
alias venvd="deactivate"

# Python3 virtualenvwrapper
alias venvw="source /usr/local/bin/virtualenvwrapper.sh"

#######################################################
# ASCII-styled script header
#######################################################
