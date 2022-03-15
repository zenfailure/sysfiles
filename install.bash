#!/usr/bin/env bash

set -eu

function failwith
{
    echo "$@"
    exit 1
}

DOTDIR="$HOME/.dotfiles"
SYSDIR="$HOME/.sysfiles"

DOTGIT="https://github.com/zenfailure/dotfiles"
SYSGIT="https://github.com/zenfailure/sysfiles"

DOTURL=\
"https://raw.githubusercontent.com/zenfailure/dotfiles/master/install.bash"
SYSURL=\
"https://raw.githubusercontent.com/zenfailure/sysfiles/master/install.bash"

ARCHIVE="$SYSDIR/archive.tar.gz.gpg"

if [[ ! -d "$SYSDIR" ]]; then
    git clone "$SYSGIT" "$SYSDIR"
fi

read -r -d '' -a PACKAGES < <(sed -rn '/^[^#]/p' "$SYSDIR/packages") || true

sudo xbps-install -Syu "${PACKAGES[@]}"

if [[ $? -ne 0 ]]; then
    failwith "Packages were not successfully installed"
fi

if [[ -z "$PASSPHRASE" ]]; then
    failwith "Decryption passphrase 'PASSPHRASE' is not defined"
fi

if [[ ! -d "$DOTDIR" ]]; then
    curl "$DOTURL" | bash
fi

cd "$SYSDIR"

git config --local core.hooksPath .githooks

gpg --decrypt --batch --pinentry-mode=loopback --passphrase="$PASSPHRASE" \
    "$ARCHIVE" | tar xzf - --preserve-permissions --no-same-owner \
        --unlink-first --recursive-unlink

source "copy.bash"

groups=()
groups+=(wheel bluetooth wireshark)
groups+=(audio video input)
groups+=(tor lxd kvm)
groups+=(vpn log users)

# sudo mount /tmp
# sudo mount -t cgroup2 -o nsdelegate cgroup2 /sys/fs/cgroup

# maybe mount cgroups in virtualized environment?

sudo rm /etc/runit/runsvdir/default/*

sudo rsync -archive --no-super --no-g --no-t --no-d --no-o --backup --relative \
    --exclude=etc/sudoers files/./ /

# lm_sensors inital setup

sudo useradd --system --no-create-home --no-log-init vpn
sudo useradd --system --no-create-home --no-log-init log
sudo groupadd --system users

for group in "${groups[@]}"; do
    sudo gpasswd -a maiz "$group"
done

sudo resolvconf -u

sudo cat files/etc/sudoers | sudo EDITOR=tee visudo

pypackages=(flexget aria2p spotdl)

for pypackage in "${pypackages[@]}"; do
    pipx install "$pypackage"
done

xbpsbuilds=(spotify discord)

pip install --user jsonpickle



cd -

#void-small-builder

# FLATPAKREPO=https://flathub.org/repo/flathub.flatpakrepo
# FLATPAKSTEAM=com.valveSoftware.Steam

# flatpak remote-add --if-not-exists flathub FLATPAKREPO
# flatpak install FLATPAKSTEAM
