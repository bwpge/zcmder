ZCMDER_ROOT_COLOR="red"
ZCMDER_DIR_COLOR="green"
ZCMDER_DIR_READONLY_COLOR="red"
ZCMDER_DIR_READONLY_PREFIX=" "
ZCMDER_NEW_BRANCH_NAME="(new)"
ZCMDER_NEW_BRANCH_COLOR="black"
ZCMDER_BRANCH_COLOR="cyan"
ZCMDER_BRANCH_MODIFIED_COLOR="yellow"
ZCMDER_BRANCH_UNTRACKED_COLOR="red"
ZCMDER_BRANCH_UNMERGED_COLOR="magenta"
ZCMDER_BRANCH_STAGED_COLOR="blue"
ZCMDER_BRANCH_STAGED_SUFFIX="+"

# same approach as git.zsh so that we don't mess with the user git commands
__zcmder_git() {
	GIT_OPTIONAL_LOCKS=0 command git "$@"
}

__zcmder_git_prompt() {
	if ! __zcmder_git rev-parse --git-dir &> /dev/null \
		|| [[ "$(__zcmder_git config --get oh-my-zsh.hide-info 2>/dev/null)" == 1 ]]; then
    	return 0
	fi
	
	local branch_color="$ZCMDER_BRANCH_COLOR"
	local branch=""
    # check if a new repo
    if [[ $(__zcmder_git rev-parse --abbrev-ref HEAD 2>/dev/null) == "HEAD" && -z "$(__zcmder_git rev-parse --short HEAD 2>/dev/null)" ]]; then
		branch="$ZCMDER_NEW_BRANCH_NAME"
		branch_color="$ZCMDER_NEW_BRANCH_COLOR"
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

	local -i AHEAD BEHIND DIVERGED UNTRACKED ADDED MODIFIED RENAMED DELETED UNMERGED STASHED
	status_text="$(git status --porcelain -b 2>/dev/null)"
	status_lines=("${(@f)${status_text}}")
	for line in $status_lines; do
		# check for a remote status
		if [[ "$line" =~ "^## [^ ]+ \[(.*)\]" ]]; then
			case "$match" in
				behind*)	BEHIND+=1;;
				ahead*)		AHEAD+=1;;
				diverged*)	DIVERGED+=1;;
			esac
		elif [[ "${line:0:2}" == "##" ]]; then
			continue
		else
			case "${line:0:2}" in
				'??')						UNTRACKED+=1;;
				'A ' | 'M ')				ADDED+=1;;
				'MM' | 'AM' | ' M' | ' T')	MODIFIED+=1;;
				'R ')						RENAMED+=1;;
				'D ')						DELETED+=1;;
				'UU')						UNMERGED+=1;;
			esac
		fi
	done

	# check for any stashes
	STASHED=$(__zcmder_git rev-parse --verify refs/stash 2>/dev/null | wc -l)
	#echo -n " >>AHEAD:$AHEAD|BEHIND:$BEHIND<< "

	# get the suffix character
	local branch_suffix=""
	if (( $DIVERGED )); then
		branch_suffix="$ZSH_THEME_GIT_PROMPT_DIVERGED"
	elif (( $BEHIND )); then
		branch_suffix="$ZSH_THEME_GIT_PROMPT_BEHIND"
	elif (( $AHEAD )); then
		branch_suffix="$ZSH_THEME_GIT_PROMPT_AHEAD"
	fi

	# determine what to color the branch based on status
	local branch_modifier=""
	if (( $UNMERGED )); then
		branch_color="$ZCMDER_BRANCH_UNMERGED_COLOR"
		branch_modifier="$ZSH_THEME_GIT_PROMPT_UNMERGED"
	elif (( $UNTRACKED )); then
		branch_color="$ZCMDER_BRANCH_UNTRACKED_COLOR"
		branch_modifier="$ZSH_THEME_GIT_PROMPT_DIRTY"
	elif (( $MODIFIED+$RENAMED+$DELETED )); then
		branch_color="$ZCMDER_BRANCH_MODIFIED_COLOR"
		branch_modifier="$ZSH_THEME_GIT_PROMPT_DIRTY"
	elif (( $ADDED )); then
		branch_color="$ZCMDER_BRANCH_STAGED_COLOR"
		branch_modifier="$ZCMDER_BRANCH_STAGED_SUFFIX"
	fi
	[[ -z "$branch_modifier" ]] && branch_modifier="$ZSH_THEME_GIT_PROMPT_CLEAN"

	local stash_modifier=""
	(( $STASHED )) && stash_modifier="$ZSH_THEME_GIT_PROMPT_STASHED"

	echo " on %{$fg[$branch_color]%}${ZSH_THEME_GIT_PROMPT_PREFIX}${branch:gs/%/%%}${upstream:gs/%/%%}$branch_modifier$branch_suffix$stash_modifier${ZSH_THEME_GIT_PROMPT_SUFFIX}%{$reset_color%}"
}

__zcmder_root() {
	echo -n "%(!.%{$fg[$ZCMDER_ROOT_COLOR]%}%n%{$reset_color%}:.)"
}

__zcmder_pwd() {
	 [ -w $(pwd) ] && echo -n "%{$fg[$ZCMDER_DIR_COLOR]%}" || echo -n "%{$fg[$ZCMDER_DIR_READONLY_COLOR]%}$ZCMDER_READONLY_PREFIX"
	 echo -n "%~%{$reset_color%}"
}

ZSH_THEME_GIT_PROMPT_PREFIX=" "
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_DIRTY="*"
ZSH_THEME_GIT_PROMPT_CLEAN=" ✓"
ZSH_THEME_GIT_PROMPT_AHEAD=" ↑"
ZSH_THEME_GIT_PROMPT_BEHIND=" ↓"
ZSH_THEME_GIT_PROMPT_DIVERGED=" ↑↓"
ZSH_THEME_GIT_PROMPT_EQUAL_REMOTE=
ZSH_THEME_GIT_PROMPT_STASHED=" ⚑"
ZSH_THEME_GIT_PROMPT_UNMERGED=" ⚡"

PROMPT='$(__zcmder_root)$(__zcmder_pwd)\
$(__zcmder_git_prompt)
%(?:%{$fg[black]%}:%{$fg[red]%})λ%{$reset_color%} '

PS2='%{$fg[black]%}%_>%{$reset_color%} '
PS3='%{$fg[black]%}?>%{$reset_color%} '
