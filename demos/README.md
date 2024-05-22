# Demos

This directory contains various demo files related to the Bachelor Thesis.
Below is a detailed description of the contents and structure of the directory.

## Directory Structure

```
demos/
├── confiscan
│   ├── automated
│   │   ├── confiscan-ansible.console
│   │   └── confiscan-ansible.mp4
│   └── manual
│       ├── confiscan-srv1.console
│       └── confiscan-srv1.mp4
├── env
│   └── vagrant-ansible.console
├── linpeas
│   └── linpeas-ng.console
└── nmap
    └── nmap.console
```

## Contents

### confiscan

This directory contains demos for ConfiScan, the bash script developed as part of this Bachelor Thesis.

- `automated`: Contains a video demo, and console recorfing, of how the `poc.yml` playbook is executed to run `confiscan.sh` on each target machine.
- `manual`: Contains a video demo, and console recording, of the manual execution of `confiscan.sh` on `srv1`.

### env

This directory contains a console recording of the Vagrant and Ansible setup process.

### linpeas

This directory contains a console recording of the LinPEAS script execution on `srv1`.

### nmap

This directory contains a console recording of the Nmap scan execution on `srv1`.
