# PoC

## Requirements

- vagrant
- VirtualBox

## Usage

```console
$ vagrant up
```

## How to test

The website configured on `srv2` should be available on the host machine at `http://172.16.128.2`.
Each server has node exporter configured to expose metrics on `9100` port, with `srv4` as the prometheus server.
