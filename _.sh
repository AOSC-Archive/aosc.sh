#!/bin/bash
##_.sh: Base library.
##Namespace: _, lib, log
##@copyright GPL-2.0+ WITH GPL-Classpath-Exception
# Not to be run directly.
# TODO:	Add basic support for bashdb.

shopt -s expand_aliases extglob
AOSCLIBS="|base|" # GLOBAL: AOSCLIBS='|base[|lib1|lib2]|'
# Should these information be redirected into aosc__log()?
# new ref impl: https://github.com/Arthur2e5/MobileConstructionVehicle/blob/master/common.sh
# Verbosity control needed! Refactor me please!
##Prints a warning message.
aosc_logw(){ printf %b "\e[33mW\e[0m\t$*\n" >&2; }
aosc_loge(){ printf %b "\e[31mE\e[0m\t$*\n" >&2; }
aosc_logi(){ printf %b "\e[96mI\e[0m\t$*\n" >&2; }
aosc_logd(){ printf %b "\e[32mD\e[0m\t$*\n" >&2; }

##Sources all args.
aosc__recursive_source(){
	local aosc__rsource_file aosc__rsource_cmd=${aosc__rsource_cmd}
	for aosc__rsource_file in "$@"; do
		"${aosc__rsource_cmd=aosc__wrap_source}" "$aosc__rsource_file" "${aosc__rsource_args[@]}";
	done
}

##Special Source with error info
aosc__wrap_source(){
	aosc__dbg "Sourcing from $1:"
	command . "$@"
	local _ret=$? # CATCH_TRANSPARENT
	if ((_ret)); then
		aosc__logw ". $(argprint "$@")returned $_ret."
	fi
	aosc__dbg "End Of $1."
	return $_ret
}

##aosc_lib NAME_OF_CURRENT_LIB
aosc_lib(){
	if [ "$(basename "$0")" == "$1.sh" ]; then
		aosc__die "$1 is a library and shouldn't be executed directly." 42
	fi
}

aosc_lib base
aosc_lib _

aosc__sourceskip(){
	aosc__warn "${1-$AOSC_SOURCE} loading skipped."
	return 1
}
alias aosc__libret='aosc__sourceskip $BASH_SOURCE || return 0'

aosc__argprint(){ printf '%q ' "$@"; }
readonly true=1 false=0 yes=1 no=0

aosc__oldbool(){
	case "$1" in
		[0fFnN]*) return 1;;
		[1tTyY]*) return 0;;
		*) return 2;;
	esac
}

aosc__reqexe(){
	local i;
	for i; do
		which $i &> /dev/null || aosc__icu "Executable ‘$i’ not found; returned value: $?."{\ Expect\ failures.,}
	done
}
alias aosc__tryexe='AOSC__STRICT=0 aosc__reqexe'

aosc__aosc__reqcmd(){
	local i;
	for i; do
		type "$i" &> /dev/null ||
		aosc__icu "Command ‘$i’ not found; returned value: $?."{\ Expect\ failures.,}
	done
}
alias aosc__trycmd='AOSC__STRICT=0 aosc__reqcmd'

aosc__cmdstub(){
	local i;
	for i; do
		_whichcmd "$i" &>/dev/null || alias "$i=${_aosc___stub_body:-:}"
	done
}

aosc_lib_load(){
	[ -f $AOSC__BLPREFIX/$1.sh ] || return 127
	. $AOSC__BLPREFIX/$1.sh || return $?
	AOSC__LIBS+="$1|"
	aosc__info "Loaded library $1" 1>&2
}

aosc__require(){
	local i
	for i; do
		[[ $AOSC__LIBS == *"|$i|"* ]] || aosc__loadlib "$i" ||
		aosc__icu "Library ‘$i’ failed to load; returned value: $?."{" Expect Failures",}
	done
}
alias aosc__trylib='AOSC__STRICT=0 aosc__require'

aosc__log(){
	if bool $AOSC__DUMB
	then cat > aosc__log
	else tee aosc__log
	fi
}

aosc__returns() { return $*; }
aosc__commaprint(){ local cnt; for i; do aosc__mkcomma; echo -n "$i"; done; }
aosc__mkcomma(){ ((cnt++)) && echo -n "${AOSC__COMMA-, }"; }

# hey buddy, you are dying!
aosc__icu(){
	if ((AOSC__STRICT)); then
		[ "$2" ] && shift
		aosc__die "$@"
	else
		aosc__err "$1"
		return 1
	fi
}

aosc__die() {
	
	echo -e "\e[1;31mautobuild encountered an error and couldn't continue.\e[0m" 1>&2
	echo -e "${1-Look at the stacktrace to see what happened.}" 1>&2
	echo "------------------------------autobuild ${VERSION:-3}------------------------------" 1>&2
	echo -e "Go to ‘\e[1mhttp://github.com/AOSC-Dev/autobuild3\e[0m’ for more information on this error." 1>&2
	if ((AOSC___DBG)); then
		read -n 1 -p "AUTOBUILD_DEBUG: CONTINUE? (Y/N)" -t 5 AOSC___DBGRUN || AOSC___DBGRUN=false
		bool $AOSC___DBGRUN && aosc__warn "Forced AUTOBUILD_DIE continue." && return 0 || aosc__dbg "AUTOBUILD_DIE EXIT - NO_CONTINUE"
	fi
	exit ${2-1}
}

[[ $BASH_VERSION ]] &&
##prints a stacktrace.
aosc__stacktrace(){
	local i t=''
	(($#)) && t=" $(printf '%q ' "$@")" || t='[None]'
	echo "Subshell level $BASH_SUBSHELL."
	echo "Cmdline ${t% }."
	for ((i=0; i< "${#FUNCNAME[@]}"; i++)); do
		echo "in ${FUNCNAME[i]} at ${BASH_SOURCE[i]}:${BASH_LINENO[i]}"
	done
}

# shopt/set control
# Name-encoding: Regular shopts should just use their regular names,
# and setflags use '-o xxx' as the name.
declare -A opt_memory
# set_opt opt-to-set
set_opt(){
	[ "$1" ] || return 2
	if ! shopt -q $1; then
		shopt -s $1 && # natural validation
		opt_memory["$1"]=0
	fi
}
# rec_opt [opts-to-recover ...]
rec_opt(){
	local _opt
	if [ -z "$1" ]; then
		rec_opt "${!opt_memory[@]}"
	elif [ "$1" == '-o' ]; then
		rec_opt "${!opt_memory[@]/#!(-o*)/_skip}"
	elif [ "$1" == '+o' ]; then
		rec_opt "${!opt_memory[@]/#-o*/_skip}"
	else
		for _opt; do
			[ "$_opt" == _skip ] && continue
			case "${opt_memory[$_opt]}" in
				(0)	uns_opt "$_opt";;
				(1)	set_opt "$_opt";;
				(*)	aosc__warn "Invaild memory $_opt: '${opt_memory[$_opt]}'"; unset opt_memory["$_opt"];;
			esac
		done
	fi
}
# uns_opt opt-to-unset
uns_opt(){
	[ "$1" ] || return 2
	if shopt -q $1; then
		shopt -s $1 && # natural validation
		opt_memory["$1"]=1
	fi
}

# USEOPT/NOOPT control
boolopt(){
	local t="$1"
	declare -n n u
	t="${f##NO_}"
	u="USE$t" n="NO$t"
	if ((n)); then
		return 1
	elif ((u)); then
		return 0
	elif [[ "$t" == NO_* ]]; then
		return 1
	else
		return 0
	fi
}

((aosc__lib_noexport)) && return
