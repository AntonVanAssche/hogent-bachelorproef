#!/usr/bin/env bash

# Title: ConfiScan
# Author: Anton Van Assche <anton.vanassche@student.hogent.be> (2024)
#                          <vanasscheanton@gmail.com>
#
# Description:
#  ConfiScan is a tool to gather basic system info and generate a tarball
#  with all the config files in a specified directory.
#  Some config files will be parsed to a CSV file.
#  Making sure the information can be used for further analysis.

set -o errexit  # Abort on nonzero exit code.
set -o nounset  # Abort on unbound variable.
set -o pipefail # Don't hide errors within pipes.
# set -o xtrace # Enable for debugging.

# Reset
declare -r RESET='\e[0m'           # text reset
declare -r DEFAULT=${RESET}

# Colors
declare -r BRED='\e[1;31m'         # red
declare -r BYELLOW='\e[1;33m'      # yellow
declare -r BBLUE='\e[1;34m'        # blue

# Variables
VERSION="0.1-devel"
NAME="ConfiScan"
SCRIPT_NAME="${0##*/}"
HOSTNAME="$(cat "/proc/sys/kernel/hostname")"
REPLY=""

error() {
    printf '%b' "${BRED}Error: ${DEFAULT}${1}\n"
    exit "${2}"
}

warn() {
    printf '%b' "${BYELLOW}Warning: ${DEFAULT}${1}\n"
}

info() {
    printf '%b' "${BBLUE}Info: ${DEFAULT}${1}\n"
}

usage() {
    printf '%b' "${BBLUE}Usage: ${SCRIPT_NAME} [OPTION]${DEFAULT}

Options:
    -h   Display help
    -c   Specify one, or more, config file(s)

Examples:
    ${SCRIPT_NAME} -h
    ${SCRIPT_NAME} -c /path/to/config,/path/to/config2
"
}

# Wrapper for 'command -v' to avoid spamming '> /dev/null'.
# It also protects against user aliasses and functions.
has() {
    command=$(command -v "${1}") 2> /dev/null || error_out "${1} is required" 127
    [[ -x ${command} ]] || error_out "${1} is not an executable" 1
}

info "You are running: ${NAME} v${VERSION}"
while getopts ":hc:" opt; do
    case ${opt} in
        h)
            usage
            exit 0
            ;;
        c)
            config_file=${OPTARG}
            ;;
        \?)
            error "Invalid option: ${OPTARG}" 1
            ;;
    esac
done

if [[ -f "/etc/os-release" ]]; then
    # source=/etc/os-release doesn't work for som benign reason.
    # shellcheck source=/dev/null
    . /etc/os-release
else
    error "OS release file not found." 1
fi

[[ "${ID}" != "debian" ]] && error "Only Debian is supported." 1
[[ "${UID}" -ne 0 ]] && error "Please run as root." 1

if [[ -z ${config_file:-} ]]; then
    warn "No config file specified, using default: '/etc/."
    config_file="/etc/"
else
    info "Using config file(s): ${config_file}"
fi

info "Creating directories..."
output_dir="$(pwd)/${HOSTNAME}-configs"

if [[ -d "${output_dir}" ]]; then
    while [[ ! "${REPLY}" =~ ^[YyNn]$ ]]; do
        warn "Output directory already exists..."
        read -rp "overwrite? [y/n]: " -n 1 -r
        printf '\n'
    done

    [[ "${REPLY}" =~ ^[Nn]$ ]] && \
        error "Output directory already exists..." 1
    [[ "${REPLY}" =~ ^[Yy]$ ]] && \
        mkdir -p "${output_dir}"
else
    mkdir -p "${output_dir}"
fi

info "Creating tarball..."
tar -cvf "${output_dir}.tar.gz" "${output_dir}" && \
   rm -rf "${output_dir}"
