# Lapioplays VM Docker image

QEMU VM container with interactive OS choice (Debian 11 or Ubuntu 22.04), RAM/CPU/disk settings, root password, SSH, RDP and noVNC web console.

## Build and run
```bash
docker build -t lapioplays/vm:1.0 .
chmod +x run-lapioplays.sh
./run-lapioplays.sh
```
The build downloads official guest cloud images and needs internet access and disk space. KVM (`/dev/kvm`) is strongly recommended; without it, software emulation is much slower.

Default host ports: SSH 2022, RDP 3391, browser console 6081. Replace `YOUR_SERVER_IP` with your server IP and configure firewall rules as needed. Do not expose root-password SSH login to the whole internet unless you understand the risk; restrict access and use a strong unique password.

VM data is stored in `./lapioplays-data`; deleting it deletes the guest disk. OS selection applies when creating a new VM disk. Use a different container name and data directory for another VM. First boot installs OpenSSH, xrdp and XFCE and can take several minutes.

Browser console: `http://YOUR_SERVER_IP:6081/vnc.html`. This builds locally; it does not publish to Docker Hub automatically.
