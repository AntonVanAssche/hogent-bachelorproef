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
VERSION="0.6-devel"
NAME="ConfiScan"
SCRIPT_NAME="${0##*/}"
HOSTNAME="$(cat "/proc/sys/kernel/hostname")"
APP_CONFIGS=()
REPLY=""
MAKE_TAR=0

error() {
    printf '%b' "${BRED}Error: ${DEFAULT}${1}\n" >&2
    exit "${2}"
}

warn() {
    printf '%b' "${BYELLOW}Warning: ${DEFAULT}${1}\n" >&2
}

info() {
    printf '%b' "${BBLUE}Info: ${DEFAULT}${1}\n"
}

usage() {
    printf '%b' "${BBLUE}Usage: ${SCRIPT_NAME} [OPTION] [CONFIG_FILES]${DEFAULT}

Options:
    -h   Display help
    -t   Create tarball of output directory

Note:
    Shell globbing is supported for [CONFIG_FILES]. They can be files or directories.

Examples:
    ${SCRIPT_NAME} -h
    ${SCRIPT_NAME} /etc/sysctl.conf
    ${SCRIPT_NAME} /etc/apache2/ /etc/sysctl.conf
    ${SCRIPT_NAME} -t /etc/bash{.bashrc,_completion}
    ${SCRIPT_NAME} -t
"
}

info "You are running: ${NAME} v${VERSION}"
while getopts ":ht" opt; do
    case ${opt} in
        h)
            usage
            exit 0
            ;;
        t)
            MAKE_TAR=1
            ;;
        \?)
            error "Invalid option: ${OPTARG}" 1
            ;;
    esac
done
shift $((OPTIND -1))

APP_CONFIGS+=("${@}")

if [[ -f "/etc/os-release" ]]; then
    # source=/etc/os-release doesn't work for som benign reason.
    # shellcheck source=/dev/null
    . /etc/os-release
else
    error "OS release file not found." 1
fi

[[ "${ID}" != "debian" ]] && error "Only Debian is supported." 1
[[ "${UID}" -ne 0 ]] && error "Please run as root." 1

required_packages=(iproute2 net-tools dmidecode)
for package in "${required_packages[@]}"; do
    apt list --installed 2> /dev/null | \
        grep -q "${package}" || \
        error "Package: '${package}' is required." 1
done

if [[ -z ${APP_CONFIGS:-} ]]; then
    warn "No config(s) specified, using default: '/etc/'."
    APP_CONFIGS+=("/etc/")
else
    info "Using config file(s): ${APP_CONFIGS[*]}"
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

#################
# Hardware info #
#################

info "Hardware Information:"
[[ -d "${output_dir}/hardware" ]] || mkdir -p "${output_dir}/hardware"

info "System Information:"
dmidecode -t system | tee -a "${output_dir}/hardware/system_info.txt"

info "Processor Information:"
dmidecode -t processor | tee -a "${output_dir}/hardware/cpu_info.txt"

info "Memory Information:"
dmidecode -t memory | tee -a "${output_dir}/hardware/memory_info.txt"

info "BIOS Information:"
dmidecode -t bios | tee -a "${output_dir}/hardware/bios_info.txt"

####################
# Operating System #
####################

info "OS Information:"
printf 'Hostname,OperatingSystem,Name,Version,Version_ID,Codename,Kernel\n' > \
    "${output_dir}/os_info.csv"
printf '%s,%s,%s,%s,%s,%s,%s\n' \
    "${HOSTNAME}" \
    "$(uname -o)" \
    "${PRETTY_NAME}" \
    "${VERSION_ID}" \
    "${VERSION}" \
    "${VERSION_CODENAME}" \
    "$(uname -r)" >> \
    "${output_dir}/os_info.csv"

column -s, -t "${output_dir}/os_info.csv"

info "Boot parameters:"
tr ' ' '\n' < /proc/cmdline | tee -a "${output_dir}/boot_parameters.txt"

column -s, -t "${output_dir}/boot_parameters.txt"

info "Kernel modules:"
printf 'Module,Size,UsedBy\n' > "${output_dir}/kernel_modules.csv"
sed -e 's/,/:/g;s/ /,/g;s/:/ /g;s/,Live.*$//g;s/,\([^,]*\)$/ \1/' < /proc/modules >> \
    "${output_dir}/kernel_modules.csv"

column -t -s, "${output_dir}/kernel_modules.csv"

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
    <(cut -d: -f4 ${passwd_file}) \
    <(cut -d: -f7 ${passwd_file}) \
    <(cut -d: -f6 ${passwd_file}) | \
    sort -t, -n -k 2 >> \
    "${output_dir}/users/users.csv"

info "Users found on the system:"
column -t -s, "${output_dir}/users/users.csv"

info "Privileged users:"
while IFS=':' read -r group _ _ user; do
    case "${group}" in
        wheel|sudo)
            printf "%s\n" "${user}"
    esac
done < "${groups_file}"

info "Custom sudo rules for each user:"
printf 'Username,Privilege\n' > "${output_dir}/users/sudoers.csv"
while read -r user; do
    while read -r priv; do
        printf "%s,%s\n" "${user}" "${priv}" >> \
            "${output_dir}/users/sudoers.csv"
    done < <(sudo -U "${user}" -l | sed -n '/User/,$p' | sed 's/    //g' | tail -n +2)
done < <(cut -d: -f1 ${passwd_file})

column -t -s, "${output_dir}/users/sudoers.csv"

printf 'Groupname,GID,Members\n' > "${output_dir}/groups/groups.csv"
cut -d: -f1 "${groups_file}" | paste -d, - \
    <(cut -d: -f3 "${groups_file}") \
    <(cut -d: -f4 "${groups_file}" | sed 's/,/ /g') >> \
    "${output_dir}/groups/groups.csv"

info "Groups found on the system:"
column -t -s, "${output_dir}/groups/groups.csv"

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

[[ -f /etc/apt/sources.list ]] || error "No sources.list file found." 2
[[ -d /etc/apt/sources.list.d ]] || error "No sources.list.d directory found." 2

info "Package repositories:"
grep -E '^[a-zA-Z]' /etc/apt/sources.list /etc/apt/sources.list.d/* 2> /dev/null | \
    sed 's/^[^:]*://' | \
    tee "${output_dir}/repositories.txt" || :

###########
# Network #
###########

[[ -d "${output_dir}/network" ]] || mkdir -p "${output_dir}/network"

info "Network devices:"
printf 'Device,IPv4,Netmask,Broadcast,IPv6,Prefix,DHCP,DHCPServer\n' > \
    "${output_dir}/network/network.csv"
while read -r device; do
    inet4="$(ifconfig "${device}" | awk '/inet / {print $2,$4,$6}' | sed 's/ ,/,/g;s/,,/,/g')"
    inet6="$(ifconfig "${device}" | awk '/inet6 / {print $2,$4}' | sed 's/ ,/,/g;s/,,/,/g')"

    IFS=' ' read -r ipv4 netmask broadcast <<< "${inet4}"
    IFS=' ' read -r ipv6 prefix <<< "${inet6}"

    [[ -z "${ipv4}" ]] && ipv4="N/A"
    [[ -z "${netmask}" ]] && netmask="N/A"
    [[ -z "${broadcast}" ]] && broadcast="N/A"
    [[ -z "${ipv6}" ]] && ipv6="N/A"
    [[ -z "${prefix}" ]] && prefix="N/A"

    if [[ "$(grep "iface ${device} inet" "/etc/network/interfaces")" =~ "dhcp" ]]; then
        dhcp="true"

        # || : is used to prevent the script from exiting when no lease file is found.
        lease_file="/var/lib/dhcp/dhclient.${device}.leases"
        dhcp_server="N/A"
        [[ -f "${lease_file}" ]] && {
            dhcp_server="$(awk '/dhcp-server-identifier/ {print $3}' "${lease_file}" | \
                tail -n1 | \
                sed 's/;//g'
            )" || :
        }
    else
        dhcp="false"
        dhcp_server="N/A"
    fi

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "${device}" "${ipv4}" "${netmask}" "${broadcast}" \
        "${ipv6}" "${prefix}" "${dhcp}" "${dhcp_server}" >> \
        "${output_dir}/network/network.csv"
done < <(ip -o link show | awk -F': ' '{print $2}')

column -t -s, "${output_dir}/network/network.csv"

info "Routing table:"
printf 'Destination,Gateway,Genmask,Flags,Metric,Ref,Use,Iface\n' > \
    "${output_dir}/network/routing.csv"

while read -r line; do
    printf '%s\n' "${line}" | \
        awk '{print $1,$2,$3,$4,$5,$6,$7,$8}' | \
        sed 's/ /\,/g' >> \
        "${output_dir}/network/routing.csv"
done < <(route -n | tail -n +3)

column -t -s, "${output_dir}/network/routing.csv"

info "Nameservers:"
printf 'Nameserver\n' > "${output_dir}/network/nameservers.csv"
while read -r nameserver; do
    printf '%s\n' "${nameserver}" >> "${output_dir}/network/nameservers.csv"
done < <(grep 'nameserver' /etc/resolv.conf | sed 's/nameserver //g')

column -t -s, "${output_dir}/network/nameservers.csv"

info "Firewall rules:"
iptables -L -n -v | tee "${output_dir}/network/iptables.txt"

info "Listening ports (TCP):"
ss -tlpn | sed -e 's/ \{1,\}/,/g' > "${output_dir}/network/tcp_ports.csv"
column -t -s, "${output_dir}/network/tcp_ports.csv"

info "Listening ports (UDP):"
ss -ulpn | sed -e 's/ \{1,\}/,/g' > "${output_dir}/network/udp_ports.csv"
column -t -s, "${output_dir}/network/udp_ports.csv"

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
        sed 's/,/:/g;s/ /,/g;s/:/ /g' >> \
            "${output_dir}/mount_points.csv"
done < /proc/mounts

column -t -s, "${output_dir}/mount_points.csv"

##################################################
# Appplication specific config files/directories #
##################################################

for c in "${APP_CONFIGS[@]}"; do
    info "Getting config: ${c}"

    [[ -f "${c}" ]] || [[ -d "${c}" ]] || \
        error "${c} no such file or directory." 2

    mkdir -p "${output_dir}/$(dirname "${c}")"
    cp -r "${c}" "${output_dir}/$(dirname "${c}")"
done

# File Integrity Check of original files, excluding ./original.sha256
find "${output_dir}" -type f -not -name "original.sha256" -exec sha256sum {} + | sort > \
    "${output_dir}/original.sha256"

[[ ${MAKE_TAR} -eq 1 ]] && {
    info "Creating tarball..."
    tar -cvf "${output_dir}.tar.gz" "${output_dir}" &> /dev/null && \
        rm -rf "${output_dir}"
}
