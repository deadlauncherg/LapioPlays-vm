#!/usr/bin/env bash
set -Eeuo pipefail
IMAGE="${IMAGE:-lapioplays/vm:1.0}"; NAME="${NAME:-lapioplays-vm}"
echo '=== Lapioplays VM Launcher ==='; echo '1) Debian 11'; echo '2) Ubuntu 22.04'
read -r -p 'Choose OS [1]: ' choice; choice="${choice:-1}"
case "$choice" in 1) VM_OS=debian11;; 2) VM_OS=ubuntu2204;; *) echo 'Invalid OS choice'; exit 2;; esac
read -r -p 'RAM in MB [2048]: ' VM_RAM; VM_RAM="${VM_RAM:-2048}"
read -r -p 'CPU cores [2]: ' VM_CPU; VM_CPU="${VM_CPU:-2}"
read -r -p 'Disk size [20G]: ' VM_DISK; VM_DISK="${VM_DISK:-20G}"
read -r -p 'VM hostname [lapioplays]: ' VM_HOSTNAME; VM_HOSTNAME="${VM_HOSTNAME:-lapioplays}"
read -r -s -p 'Guest root password (strong and unique): ' VM_PASSWORD; echo
[[ -n "$VM_PASSWORD" ]] || { echo 'Password cannot be empty'; exit 2; }
read -r -p 'Host SSH port [2022]: ' SSH_PORT; SSH_PORT="${SSH_PORT:-2022}"
read -r -p 'Host RDP port [3391]: ' RDP_PORT; RDP_PORT="${RDP_PORT:-3391}"
read -r -p 'Host web-console port [6081]: ' WEB_PORT; WEB_PORT="${WEB_PORT:-6081}"
if docker container inspect "$NAME" >/dev/null 2>&1; then echo "Container $NAME already exists; change NAME or remove it deliberately."; exit 2; fi
mkdir -p "$(pwd)/lapioplays-data"
docker run -d --name "$NAME" --restart unless-stopped \
  -p "${SSH_PORT}:2222" -p "${RDP_PORT}:3389" -p "${WEB_PORT}:6080" \
  -v "$(pwd)/lapioplays-data:/data" \
  -e VM_OS="$VM_OS" -e VM_RAM="$VM_RAM" -e VM_CPU="$VM_CPU" \
  -e VM_DISK="$VM_DISK" -e VM_PASSWORD="$VM_PASSWORD" -e VM_HOSTNAME="$VM_HOSTNAME" "$IMAGE"
unset VM_PASSWORD
echo "SSH: ssh -p $SSH_PORT root@YOUR_SERVER_IP"; echo "RDP: YOUR_SERVER_IP:$RDP_PORT"; echo "Web console: http://YOUR_SERVER_IP:$WEB_PORT/vnc.html"
echo "First boot can take several minutes. Logs: docker logs -f $NAME"
