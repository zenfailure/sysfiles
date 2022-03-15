#!/usr/bin/env bash

files=(
    /etc/bluetooth
    /usr/local/bin
    /etc/xbps.d/
    /etc/rc.conf
    /etc/rc.local
    /etc/svd
    /root/.fbtermrc
    /etc/sudoers
    /etc/sysctl.conf
    /etc/rsyslog.conf
    /etc/modprobe.d
    /etc/modules-load.d
    /etc/security/sudo_authorized_keys
    /etc/pam.d/sudo
    /etc/pam.d/slim
    /etc/pam.d/login
    /etc/pam.d/i3lock
    /etc/X11/xorg.conf
    /etc/dnscrypt-proxy.toml
    /etc/forwarding-rules.txt
    /etc/tor
    /etc/resolv.conf
    /etc/resolvconf.conf
    /etc/openvpn
    /etc/NetworkManager
    /etc/slim.conf
    /usr/share/slim/themes/main
    /usr/share/kbd/keymaps/i386/qwerty/us-nocaps.map.gz
    /etc/cgconfig.conf
    /etc/zzz.d/
    /etc/udev/rules.d/80-net-name-slot.rules
    /etc/iproute2/rt_tables
    /etc/audit/rules.d
    /etc/ntpd.conf
    /etc/rsyslog.conf
    /etc/default/
    /etc/runit/runsvdir/default/
    /etc/runit/core-services/00-pseudofs.sh
)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sudo rsync -RrlDpgo --delete --delete-excluded --exclude='supervise' \
        "${files[@]}" files
    sudo chown -R "$USER:$USER" files
fi
