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
VERSION="0.2-devel"
NAME="ConfiScan"
SCRIPT_NAME="${0##*/}"
HOSTNAME="$(cat "/proc/sys/kernel/hostname")"
REPLY=""
MAKE_TAR=0

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
    -t   Create tarball of output directory

Examples:
    ${SCRIPT_NAME} -h
    ${SCRIPT_NAME} -c /path/to/config,/path/to/config2
    ${SCRIPT_NAME} -t
"
}

info "You are running: ${NAME} v${VERSION}"
while getopts ":hc:t" opt; do
    case ${opt} in
        h)
            usage
            exit 0
            ;;
        c)
            config_file=${OPTARG:?}
            ;;
        t)
            MAKE_TAR=1
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

############
# Packages #
############

info "Package info:"

printf 'Package,Version,Architecture\n' > "${output_dir}/packages.csv"
while IFS=" " read -r pkg version arch source; do
    printf "%s,%s,%s,%s\n" "${pkg}" "${version}" "${arch}" "${source}" >> \
        "${output_dir}/packages.csv"
done < <(dpkg-query -Wf '${Package} ${Version} ${Architecture} ${Source}\n')

info "Packages found on the system:"
column -t -s, "${output_dir}/packages.csv"

######################################
# Disks, partitions and mount points #
######################################

info "Disk info:"
printf 'Disk,Size,Bytes,Sectors\n' > "${output_dir}/disk_info.csv"
fdisk -l | \
    grep 'Disk /' | \
    sed -e 's/Disk //;s/:/,/;s/GiB//;s/bytes//;s/sectors//;s/ //g' >> \
        "${output_dir}/disk_info.csv"
column -s, -t "${output_dir}/disk_info.csv"

info "Partitions:"
printf 'Device,Boot,Start,End,Sectors,Size,ID,Type\n' > "${output_dir}/partitions.csv"
while IFS=',' read -r disk boot start end sectors size id type; do
    type="$(printf '%s' "${type}" | sed 's/,/ /g')"

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "${disk}" "${boot}" "${start}" "${end}" \
        "${sectors}" "${size}" "${id}" "${type}" >> \
        "${output_dir}/partitions.csv"
done < <(fdisk -l | grep -E '^/dev/' | tr -s '[:space:]' | sed 's/ /,/g')

column -s, -t "${output_dir}/partitions.csv"

info 'Used filesystems:'
printf 'Filesystem,IsUsed\n' > "${output_dir}/used_filesystems.csv"
while read -r is_used fs; do
    if [[ "${is_used}" == "nodev" ]]; then
        is_used="false"
    else
        # We need to swap the values, because when the first
        # column within `/proc/filesystems` is empty, the second
        # column is used to set `$is_used`.
        fs="${is_used}"
        is_used="true"
    fi

    printf '%s,%s\n' "${fs}" "${is_used}" >> \
        "${output_dir}/used_filesystems.csv"
done < /proc/filesystems

column -s, -t "${output_dir}/used_filesystems.csv"

info "Mount points:"
printf 'Device,MountPoint,FSType,Options\n' > \
    "${output_dir}/mount_points.csv"
while read -r line; do
    printf '%s\n' "${line}" | \
        sed 's/,/:/g' | \
        sed 's/ /,/g' | \
        sed 's/:/ /g' >> \
        "${output_dir}/mount_points.csv"
done < /proc/mounts

[[ ${MAKE_TAR} -eq 1 ]] && {
    info "Creating tarball..."
    tar -cvf "${output_dir}.tar.gz" "${output_dir}" &> /dev/null && \
        rm -rf "${output_dir}"
}
