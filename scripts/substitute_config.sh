#!/bin/bash
# Script to substitute template variables in config files

substitute_vars() {
    local file="$1"
    local hostname="$2"
    local ergo_network="$3"
    local ergo_motd="$4"
    
    sed -i "s/{hostname}/$hostname/g" "$file"
    sed -i "s/{ergo_network}/$ergo_network/g" "$file"
    sed -i "s|{ergo_motd}|$ergo_motd|g" "$file"
}

# Usage: substitute_vars <file> <hostname> <ergo_network> <ergo_motd>
substitute_vars "$@"