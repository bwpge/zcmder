# set zcmder theme options
ZCMDER_ROOT_COLOR="red"
ZCMDER_DIR_COLOR="green"
ZCMDER_DIR_READONLY_COLOR="red"
ZCMDER_DIR_READONLY_PREFIX=" "
ZCMDER_GIT_BRANCH_NEW_NAME="(new)"
ZCMDER_GIT_BRANCH_NEW_COLOR="black"
ZCMDER_GIT_BRANCH_COLOR="cyan"
ZCMDER_GIT_BRANCH_MODIFIED_COLOR="yellow"
ZCMDER_GIT_BRANCH_UNTRACKED_COLOR="red"
ZCMDER_GIT_BRANCH_UNMERGED_COLOR="magenta"
ZCMDER_GIT_BRANCH_STAGED_COLOR="blue"

# set zsh theme options
ZSH_THEME_GIT_PROMPT_PREFIX=" "
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=" ✓"
ZSH_THEME_GIT_PROMPT_AHEAD=" ↑"
ZSH_THEME_GIT_PROMPT_BEHIND=" ↓"
ZSH_THEME_GIT_PROMPT_DIVERGED=" ↑↓"
ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE=
ZSH_THEME_GIT_PROMPT_STASHED=" ⚑"

# same approach as git.zsh so that we don't mess with the user git commands
__zcmder_git() {
    GIT_OPTIONAL_LOCKS=0 command git "$@"
}

__zcmder_git_prompt() {
    if ! __zcmder_git rev-parse --git-dir &> /dev/null \
        || [[ "$(__zcmder_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
        return 0
    fi

    local branch_color="$ZCMDER_GIT_BRANCH_COLOR"
    local branch=""

    # check if a new repo
    if [[ $(__zcmder_git rev-parse --abbrev-ref HEAD 2>/dev/null) == "HEAD" && -z "$(__zcmder_git rev-parse --short HEAD 2>/dev/null)" ]]; then
        branch="$ZCMDER_GIT_BRANCH_NEW_NAME"
        branch_color="$ZCMDER_GIT_BRANCH_NEW_COLOR"
    # otherwise use a branch name/tag/commit sha
    else
        branch=$(__zcmder_git symbolic-ref --short HEAD 2>/dev/null) \
            || branch=$(__zcmder_git describe --tags --exact-match HEAD 2>/dev/null) \
            || branch=$(__zcmder_git rev-parse --short HEAD 2>/dev/null) \
            || return 0
    fi

    local upstream=""
    if (( ${+ZSH_THEME_GIT_SHOW_UPSTREAM} )); then
        upstream=$(__zcmder_git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null) \
            && upstream=":${upstream}"
    fi

    local -i AHEAD BEHIND DIVERGED CHANGED UNTRACKED UNMERGED STASHED
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
            case "${line:0:2}" in
                '??')   UNTRACKED+=1;;
                'UU')   UNMERGED+=1;;
                *)      CHANGED+=1;;
            esac
        fi
    done

    # check for any stashes
    STASHED=$(__zcmder_git rev-parse --verify refs/stash 2>/dev/null | wc -l)
    local stash_modifier=""
    (( $STASHED )) && stash_modifier="$ZSH_THEME_GIT_PROMPT_STASHED"

    local branch_suffix=""
    if (( $DIVERGED )) || [[ $AHEAD -gt 0 && $BEHIND -gt 0 ]]; then
        branch_suffix="$ZSH_THEME_GIT_PROMPT_DIVERGED"
    elif (( $BEHIND )); then
        branch_suffix="$ZSH_THEME_GIT_PROMPT_BEHIND"
    elif (( $AHEAD )); then
        branch_suffix="$ZSH_THEME_GIT_PROMPT_AHEAD"
    fi

    local branch_modifier=""
    if (( $UNMERGED+$UNTRACKED+$CHANGED )); then
        branch_modifier="$ZSH_THEME_GIT_PROMPT_DIRTY"
    fi

    # determine what to color the branch based on status
    if (( $UNMERGED )) || (( $DIVERGED )) || [[ $AHEAD -gt 0 && $BEHIND -gt 0 ]]; then
        branch_color="$ZCMDER_GIT_BRANCH_UNMERGED_COLOR"
    elif (( $UNTRACKED )); then
        branch_color="$ZCMDER_GIT_BRANCH_UNTRACKED_COLOR"
    elif (( $CHANGED )); then
        branch_color="$ZCMDER_GIT_BRANCH_MODIFIED_COLOR"
    fi
    # check if all changes are staged
    if __zcmder_git diff --exit-code &>/dev/null && ! __zcmder_git diff --cached --exit-code &>/dev/null; then
        branch_color="$ZCMDER_GIT_BRANCH_STAGED_COLOR"
    fi
    # if no modifier was set by this point, then repo is clean
    # but don't set if this a new repo
    [[ -z "$branch_modifier" && "$branch" != "$ZCMDER_GIT_BRANCH_NEW_NAME" ]] && branch_modifier="$ZSH_THEME_GIT_PROMPT_CLEAN"

    echo " on %{$fg[$branch_color]%}${ZSH_THEME_GIT_PROMPT_PREFIX}${branch:gs/%/%%}${upstream:gs/%/%%}$branch_modifier$branch_suffix$stash_modifier${ZSH_THEME_GIT_PROMPT_SUFFIX}%{$reset_color%}"
}

__zcmder_root() {
    echo -n "%(!.%{$fg[$ZCMDER_ROOT_COLOR]%}%n%{$reset_color%}:.)"
}

__zcmder_pwd() {
    [ -w $(pwd) ] && echo -n "%{$fg[$ZCMDER_DIR_COLOR]%}" || echo -n "%{$fg[$ZCMDER_DIR_READONLY_COLOR]%}$ZCMDER_READONLY_PREFIX"
    echo -n "%~%{$reset_color%}"
}

PROMPT='$(__zcmder_root)$(__zcmder_pwd)\
$(__zcmder_git_prompt)
%(?:%{$fg[black]%}:%{$fg[red]%})λ%{$reset_color%} '
PS2='%{$fg[black]%}%_>%{$reset_color%} '
PS3='%{$fg[black]%}?>%{$reset_color%} '
