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

####################
# Users and groups #
####################

passwd_file="/etc/passwd"
[[ -f "${passwd_file}" ]] || error "passwd file not found." 1
[[ -r "${passwd_file}" ]] || error "passwd file not readable." 1

groups_file="/etc/group"
[[ -f "${groups_file}" ]] || error "group file not found." 1
[[ -r "${groups_file}" ]] || error "group file not readable." 1

[[ -d "${output_dir}/users" ]] || mkdir -p "${output_dir}/users"
[[ -d "${output_dir}/groups" ]] || mkdir -p "${output_dir}/groups"

printf 'Username,UID,GID,Shell,Home\n' > "${output_dir}/users/users.csv"
cut -d: -f1 ${passwd_file} | paste -d, - \
    <(cut -d: -f3 ${passwd_file}) \
    <(cut -d: -f3 ${passwd_file}) \
    <(cut -d: -f7 ${passwd_file}) \
    <(cut -d: -f6 ${passwd_file}) >> \
    "${output_dir}/users/users.csv"

info "Users found on the system:"
column -t -s, "${output_dir}/users/users.csv"

info "Users with login shells:"
while read -r shell; do
    info "Users with '${shell}':"

    # ||: is required since the script will exit with 1
    # if no users are found with the shell.
    grep -E ":${shell}$" ${passwd_file} | cut -d: -f1 || :
done < "/etc/shells"

info "Privileged users:"
while IFS=':' read -r group _ _ user; do
    case "${group}" in
        wheel|sudo)
            printf "%s\n" "${user}"
    esac
done < "${groups_file}"

info "Custom sudo rules:"
printf 'Username,Privilege,Source\n' > "${output_dir}/users/sudoers.csv"
while read -r user priv; do
    printf "%s,%s,%s\n" "${user##*:}" "${priv}" "${user%%:*}" >> \
        "${output_dir}/users/sudoers.csv"
done < <(grep -E '^[^#]*ALL=\(ALL\)' /etc/sudoers /etc/sudoers.d/*)

column -t -s, "${output_dir}/users/sudoers.csv"

printf 'Groupname,GID,Members\n' > "${output_dir}/groups/groups.csv"
cut -d: -f1 "${groups_file}" | paste -d, - \
    <(cut -d: -f3 "${groups_file}") \
    <(cut -d: -f4 "${groups_file}" | sed 's/,/ /g') >> \
    "${output_dir}/groups/groups.csv"

info "Groups found on the system:"
column -t -s, "${output_dir}/groups/groups.csv"

info "Creating tarball..."
tar -cvf "${output_dir}.tar.gz" "${output_dir}" &> /dev/null && \
    rm -rf "${output_dir}"
