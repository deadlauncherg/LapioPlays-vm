#!/bin/bash
set -Eeuo pipefail
: "${VM_OS:=debian11}"; : "${VM_RAM:=2048}"; : "${VM_CPU:=2}"; : "${VM_DISK:=20G}"; : "${VM_PASSWORD:=}"; : "${VM_HOSTNAME:=lapioplays}"
case "$VM_OS" in
  debian11) BASE_IMG=/opt/guest-images/debian11.qcow2; LABEL="Debian 11" ;;
  ubuntu2204) BASE_IMG=/opt/guest-images/ubuntu2204.qcow2; LABEL="Ubuntu 22.04" ;;
  *) echo 'VM_OS must be debian11 or ubuntu2204' >&2; exit 2 ;;
esac
[[ "$VM_RAM" =~ ^[0-9]+$ ]] && (( VM_RAM >= 512 && VM_RAM <= 131072 )) || { echo 'VM_RAM must be 512–131072 MB'; exit 2; }
[[ "$VM_CPU" =~ ^[0-9]+$ ]] && (( VM_CPU >= 1 && VM_CPU <= 64 )) || { echo 'VM_CPU must be 1–64'; exit 2; }
[[ "$VM_DISK" =~ ^[0-9]+[GgTtMm]$ ]] || { echo 'VM_DISK example: 20G or 1T'; exit 2; }
[[ -n "$VM_PASSWORD" ]] || { echo 'Set a strong VM_PASSWORD' >&2; exit 2; }
mkdir -p /data
VM_IMG="/data/${VM_OS}.qcow2"; SEED_IMG="/data/${VM_OS}-seed.iso"
if [[ ! -f "$VM_IMG" ]]; then echo "[lapioplays] Creating $LABEL disk ($VM_DISK)"; cp "$BASE_IMG" "$VM_IMG"; qemu-img resize "$VM_IMG" "$VM_DISK"; fi
if [[ ! -f "$SEED_IMG" ]]; then
  echo '[lapioplays] Preparing first-boot configuration...'
  HASH="$(openssl passwd -6 "$VM_PASSWORD")"; export VM_OS VM_HOSTNAME HASH
  python3 - <<'PYUSERDATA'
import os
from pathlib import Path
host=os.environ.get('VM_HOSTNAME','lapioplays')
if not host or len(host)>63 or not all(c.isalnum() or c in '-.' for c in host):
    raise SystemExit('Invalid hostname: use letters, digits, hyphen, dot; max 63 chars')
h=os.environ['HASH']
lines = [
'#cloud-config', f'hostname: {host}', 'manage_etc_hosts: true', 'disable_root: false', 'ssh_pwauth: true',
'users:', '  - name: root', '    lock_passwd: false', f"    passwd: '{h}'", '    shell: /bin/bash',
'packages:', '  - openssh-server', '  - xrdp', '  - xfce4', '  - dbus-x11',
'runcmd:', '  - [ bash, -lc, "echo startxfce4 > /root/.xsession" ]',
'  - [ bash, -lc, "sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config" ]',
'  - [ bash, -lc, "sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" ]',
'  - [ bash, -lc, "systemctl enable --now ssh || systemctl enable --now sshd || true" ]',
'  - [ bash, -lc, "systemctl enable --now xrdp || true" ]']
Path('/data/user-data').write_text('\n'.join(lines)+'\n')
Path('/data/meta-data').write_text(f"instance-id: lapioplays-{os.environ['VM_OS']}\nlocal-hostname: {host}\n")
PYUSERDATA
  cloud-localds "$SEED_IMG" /data/user-data /data/meta-data
fi
if [[ -e /dev/kvm ]]; then echo '[lapioplays] KVM detected'; KVM_ARGS=(-enable-kvm -cpu host); else echo '[lapioplays] No /dev/kvm; software emulation will be slower'; KVM_ARGS=(-accel tcg -cpu max); fi
echo "[lapioplays] $LABEL | RAM ${VM_RAM}MB | CPU ${VM_CPU} | Disk ${VM_DISK}"
exec qemu-system-x86_64 "${KVM_ARGS[@]}" -m "$VM_RAM" -smp "$VM_CPU" \
  -drive "file=$VM_IMG,format=qcow2,if=virtio" \
  -drive "file=$SEED_IMG,format=raw,media=cdrom,readonly=on" \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::3389-:3389 \
  -device virtio-net-pci,netdev=net0 -vnc 0.0.0.0:0
