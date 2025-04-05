#!/bin/sh
#
# Script aimed to disable ipv6 inside Proxmox LXC container
# g777 - 2025
#

# [ VARIABLES ]
SYSCTL_PATH="/etc/sysctl.d"
SYSCTL_FILE="99-ipv6-disable.conf"
SYSCTL_IPV6="net.ipv6.conf.all.disable_ipv6=1\nnet.ipv6.conf.default.disable_ipv6=1\nnet.ipv6.conf.lo.disable_ipv6=1"

#
# given file path $1 return file size
# $1 - str: mandatory
# return: str, status code
#
file_size () {
        [ -z "$1" ] && printf "file_size: No argument given!\n" && return 1
        stat --printf="%i" "$1"
        return 0
}

#
# given file path $1 and pattern $2 comment matching lines and return text
# $1 - str: mandatory
# $2 - str: mandatory
# return: str
#
comment () {
        [ -z "$1" -o -z "$2" ] && return 1
        sed -e "/$2/ s/^#*/#/" "$1"
        return 0
}

# create new file restricting IPv6 in sysctl
printf " @ Disable IPv6 using sysctl.\n"
SYSCTL_FULL_PATH="$SYSCTL_PATH/$SYSCTL_FILE"
if [ ! -f "$SYSCTL_FULL_PATH" ]; then
        cat "$SYSCTL_IPV6" > "$SYSCTL_FULL_PATH"
else
        SYSCTL_FSIZE=$(file_size "$SYSCTL_FULL_PATH")
        [ $? -eq 1 ] && pritnf "Failed to detremine file size!\n" && exit 1
        [ $SYSCTL_FSIZE -lt 100 ] && cat "$SYSCTL_IPV6" > "$SYSCTL_FULL_PATH"
fi

# make /etc/hosts proper
printf " @ Comment out all IPv6 in /etc/hosts and tell Proxmox not to alter it.\n"
touch /etc/.pve-ignore.hosts
IPV6_PATTERN="[a-fA-F]*\d*::\d*"
HOSTS_FILE="/etc/hosts"
printf "$(comment "$HOSTS_FILE" "$IPV6_PATTERN")\n" > "$HOSTS_FILE"

# add some lines to /etc/systemd/network/<NIC>.network
NIC_NAME="eth0"
printf " @ Add LinkLocalAddressing to ${NIC_NAME} and tell Proxmox not to alter it.\n"
NIC_PATH="/etc/systemd/network/${NIC_NAME}.network"
[ ! -f "$NIC_PATH" ] && printf "Error! File ${NIC_PATH} not found!" && exit 1
[ -z "$(grep ^LinkLocalAddressing ${NIC_PATH} | grep -i "no")" ] && printf "%b" "LinkLocalAddressing = no\n" >> ${NIC_PATH}
touch /etc/systemd/network/.pve-ignore.${NIC_NAME}.network

[ -z "$(ip a | grep inet6)" ] && printf " IPv6 appears to be disabled!\n"
