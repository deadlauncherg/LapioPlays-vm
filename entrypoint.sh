#!/usr/bin/env bash
set -Eeuo pipefail

DATA_DIR="/data"
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

case "${VM_OS:-debian11}" in
  debian11)
    IMAGE_NAME="debian-11-generic-amd64.qcow2"
    IMAGE_URL="https://cloud.debian.org/images/cloud/bullseye/latest/${IMAGE_NAME}"
    SUMS_URL="https://cloud.debian.org/images/cloud/bullseye/latest/SHA512SUMS"
    SUM_TOOL="sha512sum"
    ;;
  ubuntu2204)
    IMAGE_NAME="jammy-server-cloudimg-amd64.img"
    IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/${IMAGE_NAME}"
    SUMS_URL="https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
    SUM_TOOL="sha256sum"
    ;;
  *)
    echo "ERROR: VM_OS must be debian11 or ubuntu2204"
    exit 1
    ;;
esac

BASE_IMAGE="/data/base-${VM_OS}.img"
DISK_IMAGE="/data/vm-${VM_OS}.qcow2"
SEED_IMAGE="/data/seed-${VM_OS}.iso"

# Download the official cloud image and verify its published checksum.
if [ ! -s "$BASE_IMAGE" ]; then
  echo "Downloading ${VM_OS} cloud image..."
  curl -fL --retry 5 --retry-delay 3 "$IMAGE_URL" -o "${BASE_IMAGE}.download"
  curl -fL --retry 5 --retry-delay 3 "$SUMS_URL" -o /tmp/SHA_SUMS

  if ! grep -E "[[:space:]*]${IMAGE_NAME//./\\.}$" /tmp/SHA_SUMS |
       grep -q .; then
    echo "ERROR: Image checksum was not found."
    rm -f "${BASE_IMAGE}.download"
    exit 1
  fi

  EXPECTED_LINE="$(grep -E "[[:space:]*]${IMAGE_NAME//./\\.}$" /tmp/SHA_SUMS | head -n 1)"
  printf '%s\n' "$EXPECTED_LINE" | sed "s|${IMAGE_NAME}|${BASE_IMAGE}.download|" > /tmp/image-checksum

  if ! (cd /data && $SUM_TOOL --check /tmp/image-checksum); then
    echo "ERROR: Image checksum verification failed."
    rm -f "${BASE_IMAGE}.download"
    exit 1
  fi

  mv "${BASE_IMAGE}.download" "$BASE_IMAGE"
fi

# Create a persistent writable disk only on first startup.
if [ ! -s "$DISK_IMAGE" ]; then
  echo "Creating persistent VM disk: ${VM_DISK}"
  qemu-img create -f qcow2 -F qcow2 \
    -b "$BASE_IMAGE" "$DISK_IMAGE" "$VM_DISK"
fi

# Generate cloud-init configuration for the guest.
PASSWORD_HASH="$(openssl passwd -6 "${VM_PASSWORD:-lapio}")"

cat > /tmp/user-data <<EOF
#cloud-config
hostname: ${VM_HOSTNAME:-lapioplays}
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
users:
  - default
  - name: root
    shell: /bin/bash
    lock_passwd: false
    passwd: '${PASSWORD_HASH}'
chpasswd:
  expire: false
package_update: false
write_files:
  - path: /etc/ssh/sshd_config.d/00-lapioplays.conf
    permissions: '0644'
    content: |
      PasswordAuthentication yes
      PermitRootLogin yes
runcmd:
  - [bash, -lc, "passwd -u root || true"]
  - [bash, -lc, "sshd -t && systemctl restart ssh"]
EOF

cat > /tmp/meta-data <<EOF
instance-id: lapioplays-${VM_OS}
local-hostname: ${VM_HOSTNAME:-lapioplays}
EOF

cloud-localds "$SEED_IMAGE" /tmp/user-data /tmp/meta-data

RAM="${VM_RAM:-2048}"
CPU="${VM_CPU:-2}"

echo "Starting ${VM_OS}: RAM=${RAM} MiB, CPU=${CPU}, disk=${VM_DISK}"
echo "SSH will be available on this container's port 2222."

exec qemu-system-x86_64 \
  -machine accel=tcg \
  -cpu max \
  -smp "$CPU" \
  -m "$RAM" \
  -drive "file=${DISK_IMAGE},format=qcow2,if=virtio" \
  -drive "file=${SEED_IMAGE},format=raw,if=virtio,readonly=on" \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -boot c \
  -display none \
  -serial mon:stdio \
  -no-reboot
