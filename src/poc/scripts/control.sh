#!/usr/bin/env bash

set -o errexit  # Abort on nonzero exit code.
set -o nounset  # Abort on unbound variable.
set -o pipefail # Don't hide errors within pipes.
# set -o xtrace # Enable for debugging.

export UBUNTU_CODENAME=jammy

apt update
apt install gnupg2 -y

wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | \
    gpg --dearmour -o /usr/share/keyrings/ansible-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | \
    tee /etc/apt/sources.list.d/ansible.list

apt update
apt install ansible -y

sudo --login --non-interactive --user=vagrant -- \
    ansible-galaxy install -r /vagrant/ansible/requirements.yml

sudo --login --non-interactive --user=vagrant -- \
    ansible-playbook -i /vagrant/ansible/inventory.yml /vagrant/ansible/main.yml
