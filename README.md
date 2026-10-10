
# LapioPlays VM

A Docker-based QEMU virtual machine launcher for Debian 11 and Ubuntu 22.04.

## Features

- Select Debian 11 or Ubuntu 22.04
- Configure guest RAM, CPU cores and virtual disk size
- SSH access through a configurable host port
- Persistent virtual machine disk
- Custom hostname and root password
- Official cloud images with checksum verification

## Requirements

- Linux VPS with Docker installed
- CPU virtualization support is recommended
- Enough free RAM and disk space
- A host port available for SSH

This project uses QEMU TCG emulation, which can be slower than hardware acceleration.

## Build

```bash
docker build -t lapioplays/vm:1.0 .
```

## Run the setup wizard

```bash
chmod +x run-vm.sh
./run-vm.sh
```

## Connect over SSH

```bash
ssh root@YOUR_VPS_IP -p 6969
```

Use the SSH port selected during setup.

## Persistent storage

The launcher stores VM files in `vmdata/` under the selected OS directory.
Do not delete this directory if you want to keep the VM's data.

## Docker Hub

```bash
docker login
docker tag lapioplays/vm:1.0 YOUR_DOCKERHUB_USERNAME/lapioplays-vm:1.0
docker push YOUR_DOCKERHUB_USERNAME/lapioplays-vm:1.0
```

## Security

- Change the default root password.
- Do not expose SSH to the public internet without firewall restrictions.
- Do not store passwords or access tokens in a public repository.
- Debian 11 is past its regular LTS support period as of 2026; consider a supported OS for production use.

## License

Choose a license before publishing or accepting contributions.
