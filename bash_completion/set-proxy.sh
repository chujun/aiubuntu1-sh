#!/bin/bash

_set_proxy_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="-s --set -u --unset --show -t --test -e --enable -i --ip -h --help"
    
    case "${prev}" in
        -i|--ip)
            COMPREPLY=($(compgen -W "" -- ${cur}))
            return 0
            ;;
        -s|--set)
            COMPREPLY=($(compgen -W "10810 7890 1080 10809" -- ${cur}))
            return 0
            ;;
        -*)
            COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
            return 0
            ;;
    esac
    
    COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
    return 0
}

complete -F _set_proxy_completion set-proxy.sh
