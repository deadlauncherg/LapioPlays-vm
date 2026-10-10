
#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Install Docker first."
  exit 1
fi

echo "================================"
echo "       LapioPlays VM Setup"
echo "================================"
echo "1) Debian 11"
echo "2) Ubuntu 22.04"

read -rp "Choose OS [1/2]: " OS_CHOICE
case "$OS_CHOICE" in
  1) VM_OS="debian11"; CONTAINER="lapioplays-debian11" ;;
  2) VM_OS="ubuntu2204"; CONTAINER="lapioplays-ubuntu2204" ;;
  *) echo "Invalid OS choice."; exit 1 ;;
esac

read -rp "RAM in GB [2]: " RAM_GB
RAM_GB="${RAM_GB:-2}"
[[ "$RAM_GB" =~ ^[1-9][0-9]*$ ]] || { echo "RAM must be a positive whole number."; exit 1; }
VM_RAM=$((RAM_GB * 1024))

read -rp "CPU cores [2]: " VM_CPU
VM_CPU="${VM_CPU:-2}"
[[ "$VM_CPU" =~ ^[1-9][0-9]*$ ]] || { echo "CPU must be a positive whole number."; exit 1; }

read -rp "Disk size in GB [20]: " DISK_GB
DISK_GB="${DISK_GB:-20}"
[[ "$DISK_GB" =~ ^[1-9][0-9]*$ ]] || { echo "Disk must be a positive whole number."; exit 1; }
VM_DISK="${DISK_GB}G"

read -rp "SSH host port [6969]: " SSH_PORT
SSH_PORT="${SSH_PORT:-6969}"
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || {
  echo "SSH port must be between 1 and 65535."
  exit 1
}

read -rp "Hostname [lapioplays]: " VM_HOSTNAME
VM_HOSTNAME="${VM_HOSTNAME:-lapioplays}"

read -rsp "Root password [press Enter for lapio]: " VM_PASSWORD
echo
VM_PASSWORD="${VM_PASSWORD:-lapio}"

IMAGE="lapioplays/vm:1.0"
DATA_DIR="$PWD/vmdata/$VM_OS"
mkdir -p "$DATA_DIR"

if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Container $CONTAINER already exists."
  echo "Stop/remove it first if you want to recreate it."
  exit 1
fi

# QEMU needs extra container memory beyond the guest's configured RAM.
CONTAINER_RAM_GB=$((RAM_GB + 1))

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --memory "${CONTAINER_RAM_GB}g" \
  --cpus "$VM_CPU" \
  -p "${SSH_PORT}:2222" \
  -v "$DATA_DIR:/data" \
  -e VM_OS="$VM_OS" \
  -e VM_RAM="$VM_RAM" \
  -e VM_CPU="$VM_CPU" \
  -e VM_DISK="$VM_DISK" \
  -e VM_HOSTNAME="$VM_HOSTNAME" \
  -e VM_PASSWORD="$VM_PASSWORD" \
  "$IMAGE"

echo
echo "Container created: $CONTAINER"
echo "Follow startup logs with:"
echo "docker logs -f $CONTAINER"
echo
echo "Connect after the guest OS finishes booting:"
echo "ssh root@YOUR_VPS_IP -p $SSH_PORT"
echo "Default password if you left it blank: lapio"
echo
echo "VM files are persisted in: $DATA_DIR"
