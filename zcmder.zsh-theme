# set zsh theme options unless disabled
if ! (( ${+ZCMDER_NO_MODIFY_ZSH_THEME} )); then
    ZSH_THEME_GIT_PROMPT_PREFIX=" "
    ZSH_THEME_GIT_PROMPT_SUFFIX=""
    ZSH_THEME_GIT_PROMPT_DIRTY=" *"
    ZSH_THEME_GIT_PROMPT_CLEAN=" ✓"
    ZSH_THEME_GIT_PROMPT_AHEAD=" ↑"
    ZSH_THEME_GIT_PROMPT_BEHIND=" ↓"
    ZSH_THEME_GIT_PROMPT_DIVERGED=" ↑↓"
    ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE=""
    ZSH_THEME_GIT_PROMPT_STASHED=" ⚑"
fi

unset ZCMDER_STYLES ZCMDER_COMPONENTS ZCMDER_OPTIONS ZCMDER_STRINGS

declare -A ZCMDER_COMPONENTS=(
    [cwd]=true
    [git_status]=true
    [hostname]=false
    [python_env]=true
    [username]=false
)

declare -A ZCMDER_STYLES=(
    [caret]="fg=8"
    [caret_error]="fg=red"
    [cwd]="fg=green"
    [cwd_readonly]="fg=red"
    [git_branch_default]="fg=cyan"
    [git_modified]="fg=yellow"
    [git_new_repo]="fg=black"
    [git_staged]="fg=blue"
    [git_unmerged]="fg=magenta"
    [git_untracked]="fg=red"
    [python_env]="fg=8"
    [user_and_host]="fg=blue"
)

declare -A ZCMDER_OPTIONS=(
    [git_show_remote]=false
    [newline_before_prompt]=true
)

declare -A ZCMDER_STRINGS=(
    [caret]="λ"
    [caret_root]="#"
    [git_ahead_postfix]="${ZSH_THEME_GIT_PROMPT_AHEAD:- ↑}"
    [git_behind_postfix]="${ZSH_THEME_GIT_PROMPT_BEHIND:- ↓}"
    [git_clean_postfix]="${ZSH_THEME_GIT_PROMPT_CLEAN:- ✓}"
    [git_dirty_postfix]="${ZSH_THEME_GIT_PROMPT_DIRTY:- *}"
    [git_diverged_postfix]="${ZSH_THEME_GIT_PROMPT_DIVERGED:- ↑↓}"
    [git_label_new]="(new)"
    [git_prefix]="${ZSH_THEME_GIT_PROMPT_PREFIX:- }"
    [git_separator]="on "
    [git_stashed_modifier]="${ZSH_THEME_GIT_PROMPT_STASHED:- ⚑}"
    [git_suffix]="${ZSH_THEME_GIT_PROMPT_SUFFIX:-}"
    [readonly_prefix]=" "
)

# same approach as git.zsh so that we don't mess with the user git commands
__zcmder_git() {
    GIT_OPTIONAL_LOCKS=0 command git "$@"
}

__zcmder_git_prompt() {
    if [ ! $ZCMDER_COMPONENTS[git_status] ]; then
        return 0
    fi
    if ! __zcmder_git rev-parse --git-dir &> /dev/null \
        || [[ "$(__zcmder_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
        return 0
    fi

    local branch_style="$ZCMDER_STYLES[git_branch_default]"
    local branch=""

    # check if a new repo
    if [[ $(__zcmder_git rev-parse --abbrev-ref HEAD 2>/dev/null) == "HEAD" && -z "$(__zcmder_git rev-parse --short HEAD 2>/dev/null)" ]]; then
        branch="$ZCMDER_STRINGS[git_label_new]"
        branch_style="$ZCMDER_STYLES[git_new_repo]"
    # otherwise use a branch name/tag/commit sha
    else
        branch=$(__zcmder_git symbolic-ref --short HEAD 2>/dev/null) \
            || branch=$(__zcmder_git describe --tags --exact-match HEAD 2>/dev/null) \
            || branch=$(__zcmder_git rev-parse --short HEAD 2>/dev/null) \
            || return 0
    fi

    # set remote label (avoid git call if not needed)
    local remote=""
    if ${ZCMDER_OPTIONS[git_show_remote]}; then
        remote=$(__zcmder_git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) \
            && remote=":${remote}"
    fi

    local -i AHEAD BEHIND DIVERGED CHANGES MODIFIED UNTRACKED UNMERGED STASHED STAGED
    status_text="$(git status --porcelain -b 2>/dev/null)"
    status_lines=("${(@f)${status_text}}")
    for line in $status_lines; do
        # check for a remote status
        if [[ "$line" =~ "^## [^ ]+ \[(.*)\]" ]]; then
            branch_statuses=("${(@s/,/)match}")
            for branch_status in $branch_statuses; do
                if [[ ! $branch_status =~ "(behind|diverged|ahead) ([0-9]+)?" ]]; then
                    continue
                fi
                if [[ $match[1] == 'diverged' ]]; then
                    DIVERGED+=${+match[2]}
                elif [[ $match[1] == 'ahead' ]]; then
                    AHEAD+=${+match[2]}
                elif [[ $match[1] == 'behind' ]]; then
                    BEHIND+=${+match[2]}
                fi
            done
        elif [[ "${line:0:2}" == "##" ]]; then
            continue
        else
            CHANGES+=1
            case "${line:0:2}" in
                '?'*)      UNTRACKED+=1;;
                'U'*)      UNMERGED+=1;;
                *'M'|' '*) MODIFIED+=1;;
                *)         STAGED+=1;;
            esac
        fi
    done

    # get status modifiers from local changes
    local branch_modifier=""
    if (( $CHANGES )); then
        branch_modifier="$ZCMDER_STRINGS[git_dirty_postfix]"
    # otherwise repo is clean, but don't show if in a new repo
    elif [[ -z "$branch_modifier" && "$branch" != "$ZCMDER_STRINGS[git_label_new]" ]]; then
        branch_modifier="$ZCMDER_STRINGS[git_clean_postfix]"
    fi

    # check for any stashes
    STASHED=$(__zcmder_git rev-parse --verify refs/stash 2>/dev/null | wc -l)
    local stash_modifier=""
    (( $STASHED )) && stash_modifier="$ZCMDER_STRINGS[git_stashed_modifier]"

    # branch suffix from remote status
    local branch_suffix=""
    if (( $DIVERGED )) || [[ $AHEAD -gt 0 && $BEHIND -gt 0 ]]; then
        branch_suffix="$ZCMDER_STRINGS[git_diverged_postfix]"
    elif (( $BEHIND )); then
        branch_suffix="$ZCMDER_STRINGS[git_behind_postfix]"
    elif (( $AHEAD )); then
        branch_suffix="$ZCMDER_STRINGS[git_ahead_postfix]"
    fi

    # get style based on local or remote
    if (( $CHANGES > 0 && $CHANGES == $STAGED)); then
        branch_style="$ZCMDER_STYLES[git_staged]"
    elif (( $UNMERGED )) || (( $DIVERGED )) || [[ $AHEAD -gt 0 && $BEHIND -gt 0 ]]; then
        branch_style="$ZCMDER_STYLES[git_unmerged]"
    elif (( $UNTRACKED )); then
        branch_style="$ZCMDER_STYLES[git_untracked]"
    elif (( $MODIFIED )); then
        branch_style="$ZCMDER_STYLES[git_modified]"
    fi

    # using locals here to make it more readable
    local label="$(__zcmder_gen_style $branch_style])$ZCMDER_STRINGS[git_prefix]${branch:gs/%/%%}${remote:gs/%/%%}"
    local modifiers="$branch_modifier$branch_suffix$stash_modifier$ZCMDER_STRINGS[git_suffix]"
    echo "$ZCMDER_STRINGS[git_separator]$label$modifiers%{$reset_color%}"
}

__zcmder_gen_style() {
    if [ $# -lt 1 ]; then
        return 0
    fi

    tokens=(${(@s/,/)1})

    # invert and standout effect must be printed first
    if [[ ${tokens[(ie)standout]} -le ${#tokens} ]]; then
        print -n '%S'
    elif [[ ${tokens[(ie)invert]} -le ${#tokens} ]]; then
        print -n '\x1b[7m'
    fi

    for token in $tokens; do
        case "$token" in
            'fg='*)
                split=(${(@s/=/)token})
                print -n "%F{$split[2]%}";;
            'bg='*)
                split=(${(@s/=/)token})
                print -n "%K{$split[2]%}";;
            'bold')
                print -n '%B';;
            'dim')
                print -n '\x1b[2m';;
            'italic')
                print -n '\x1b[3m';;
            'underline')
                print -n '%U';;
        esac
    done
}

__zcmder_pyenv() {
    if ! $ZCMDER_COMPONENTS[python_env]; then
        return 0
    fi
    local py=""
    if [ -n "$CONDA_PROMPT_MODIFIER" ]; then
        py="${CONDA_PROMPT_MODIFIER%%[[:space:]]*}"
    elif [ -n "$VIRTUAL_ENV" ]; then
        py="($(basename $VIRTUAL_ENV 2>/dev/null))"
    fi
    if [ -n "$py" ]; then
        print "$(__zcmder_gen_style $ZCMDER_STYLES[python_env])$py%{$reset_color%} "
    fi
}

__zcmder_username() {
    if ! $ZCMDER_COMPONENTS[username]; then
        return 0
    fi
    local sp=""
    if ! $ZCMDER_COMPONENTS[hostname]; then
        sp=" "
    fi
    print "$(__zcmder_gen_style $ZCMDER_STYLES[user_and_host])%n%{$reset_color%}$sp"
}

__zcmder_hostname() {
    if ! $ZCMDER_COMPONENTS[hostname]; then
        return 0
    fi
    local sep=""
    if $ZCMDER_COMPONENTS[username]; then
        sep="@"
    fi
    print "$(__zcmder_gen_style $ZCMDER_STYLES[user_and_host])$sep%M%{$reset_color%} "
}

__zcmder_cwd() {
    if ! $ZCMDER_COMPONENTS[cwd]; then
        return 0
    fi
    [ -w "$(pwd)" ] && print -n "$(__zcmder_gen_style $ZCMDER_STYLES[cwd])" ||
        print -n "$(__zcmder_gen_style $ZCMDER_STYLES[cwd_readonly])$ZCMDER_STRINGS[readonly_prefix]"
    print "%~%{$reset_color%} "
}

__zcmder_caret() {
    style="$ZCMDER_STYLES[$1]"
    print -n "$(__zcmder_gen_style $style)%(!.$ZCMDER_STRINGS[caret_root].$ZCMDER_STRINGS[caret])"
}

# see: https://stackoverflow.com/a/60790101
autoload -Uz add-zsh-hook
__zcmder_precmd() {
    $funcstack[1]() {
        [ $ZCMDER_OPTIONS[newline_before_prompt] = true ] && echo
    }
}
add-zsh-hook precmd __zcmder_precmd

# "%(?.caret.caret_error)"
PROMPT='$(__zcmder_pyenv)$(__zcmder_username)$(__zcmder_hostname)$(__zcmder_cwd)$(__zcmder_git_prompt)
%(?.$(__zcmder_caret caret).$(__zcmder_caret caret_error))%{$reset_color%} '
PS2='$(__zcmder_gen_style $ZCMDER_STYLES[caret])%_>%{$reset_color%} '
PS3='$(__zcmder_gen_style $ZCMDER_STYLES[caret])?>%{$reset_color%} '
