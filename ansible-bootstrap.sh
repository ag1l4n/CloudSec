#!/bin/bash
echo "Starting Ansible Bootstrap and Hardening Process..."

# 1. Install Ansible and Git
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y software-properties-common git
apt-add-repository --yes --update ppa:ansible/ansible
apt-get install -y ansible

# 2. Install the DevSec Hardening Framework from Ansible Galaxy
ansible-galaxy collection install devsec.hardening

# 3. Create a local playbook file (playbook.yml)
cat << 'EOF' > /tmp/hardening-playbook.yml
---
- name: Apply DevSec OS and SSH Hardening
  hosts: localhost
  connection: local
  become: yes
  collections:
    - devsec.hardening
  roles:
    - os_hardening
    - ssh_hardening
EOF

# 4. Execute the playbook locally
ansible-playbook /tmp/hardening-playbook.yml
