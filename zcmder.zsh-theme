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

unset ZCMDER_COLORS ZCMDER_COMPONENTS ZCMDER_OPTIONS ZCMDER_STRINGS

declare -A ZCMDER_COMPONENTS=(
    [cwd]=true
    [git_status]=true
    [hostname]=false
    [python_env]=true
    [username]=false
)

declare -A ZCMDER_COLORS=(
    [caret]="black"
    [caret_error]="red"
    [cwd]="green"
    [cwd_readonly]="red"
    [git_branch_default]="cyan"
    [git_modified]="yellow"
    [git_new_repo]="black"
    [git_staged]="blue"
    [git_unmerged]="magenta"
    [git_untracked]="red"
    [hostname]="blue"
    [python_env]="black"
    [username]="blue"
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
    [git_separator]=" on "
    [git_stashed_modifier]="${ZSH_THEME_GIT_PROMPT_STASHED:- ⚑}"
    [git_suffix]="${ZSH_THEME_GIT_PROMPT_SUFFIX:-}"
    [readonly_prefix]=" "
)

# same approach as git.zsh so that we don't mess with the user git commands
__zcmder_git() {
    GIT_OPTIONAL_LOCKS=0 command git "$@"
}

__zcmder_git_prompt() {
    if ! __zcmder_git rev-parse --git-dir &> /dev/null \
        || [[ "$(__zcmder_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
        return 0
    fi

    local branch_color="$ZCMDER_COLORS[git_branch_default]"
    local branch=""

    # check if a new repo
    if [[ $(__zcmder_git rev-parse --abbrev-ref HEAD 2>/dev/null) == "HEAD" && -z "$(__zcmder_git rev-parse --short HEAD 2>/dev/null)" ]]; then
        branch="$ZCMDER_STRINGS[git_label_new]"
        branch_color="$ZCMDER_COLORS[git_new_repo]"
    # otherwise use a branch name/tag/commit sha
    else
        branch=$(__zcmder_git symbolic-ref --short HEAD 2>/dev/null) \
            || branch=$(__zcmder_git describe --tags --exact-match HEAD 2>/dev/null) \
            || branch=$(__zcmder_git rev-parse --short HEAD 2>/dev/null) \
            || return 0
    fi

    # set remote label (avoid git call if not needed)
    local remote=""
    if [ ${ZCMDER_OPTIONS[git_show_remote]} ]; then
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

    # get color based on local or remote
    if (( $CHANGES > 0 && $CHANGES == $STAGED)); then
        branch_color="$ZCMDER_COLORS[git_staged]"
    elif (( $UNMERGED )) || (( $DIVERGED )) || [[ $AHEAD -gt 0 && $BEHIND -gt 0 ]]; then
        branch_color="$ZCMDER_COLORS[git_unmerged]"
    elif (( $UNTRACKED )); then
        branch_color="$ZCMDER_COLORS[git_untracked]"
    elif (( $MODIFIED )); then
        branch_color="$ZCMDER_COLORS[git_modified]"
    fi

    # using locals here to make it more readable
    local label="%{$fg[$branch_color]%}$ZCMDER_STRINGS[git_prefix]${branch:gs/%/%%}${remote:gs/%/%%}"
    local modifiers="$branch_modifier$branch_suffix$stash_modifier$ZCMDER_STRINGS[git_suffix]"
    echo "$ZCMDER_STRINGS[git_separator]$label$modifiers%{$reset_color%}"
}

__zcmder_cwd() {
    [ -w "$(pwd)" ] && echo -n "%{$fg[$ZCMDER_COLORS[cwd]]%}" || echo -n "%{$fg[$ZCMDER_COLORS[cwd_readonly]]%}$ZCMDER_STRINGS[readonly_prefix]"
    print "%~%{$reset_color%}"
}

__zcmder_caret() {
    print "%(!.$ZCMDER_STRINGS[caret_root].$ZCMDER_STRINGS[caret])"
}

# see: https://stackoverflow.com/a/60790101
autoload -Uz add-zsh-hook
__zcmder_precmd() {
    $funcstack[1]() {
        [ $ZCMDER_OPTIONS[newline_before_prompt] = true ] && echo
    }
}
add-zsh-hook precmd __zcmder_precmd

PROMPT='$(__zcmder_cwd)$(__zcmder_git_prompt)
%(?:%{$fg[$ZCMDER_COLORS[caret]]%}:%{$fg[$ZCMDER_COLORS[caret_error]]%})$(__zcmder_caret)%{$reset_color%} '
PS2='%{$fg[$ZCMDER_COLORS[caret]]%}%_>%{$reset_color%} '
PS3='%{$fg[$ZCMDER_COLORS[caret]]%}?>%{$reset_color%} '
