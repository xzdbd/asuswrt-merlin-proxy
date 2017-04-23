function add_service {
    [ -e /jffs/scripts/$1 ] || echo '#!/bin/sh' > /jffs/scripts/$1
    chmod +x /jffs/scripts/$1
    fgrep -qs -e "$2" /jffs/scripts/$1 || echo "$2" >> /jffs/scripts/$1
}

function regexp_escape () {
    sed -e 's/[]\/$*.^|[]/\\&/g'
}

function replace_escape () {
    sed -e 's/[\/&]/\\&/g'
}

function replace_string () {
    local regexp="$(echo "$1" |regexp_escape)"
    local replace="$(echo "$2" |replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" "$config_file"
}

function replace_regex () {
    local regexp=$1
    local replace="$(echo "$2" |replace_escape)"
    local config_file=$3

    sed -i -e "s/$regexp/$replace/" "$config_file"
}

function __export () {
    export_hooks="$export_hooks $@"
    builtin export "$@"
}
alias export=__export
