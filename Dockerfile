FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl openssl python3 qemu-system-x86 qemu-utils cloud-image-utils supervisor novnc websockify && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/guest-images /data /etc/supervisor/conf.d \
 && curl -fL --retry 3 https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2 -o /opt/guest-images/debian11.qcow2 \
 && curl -fL --retry 3 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o /opt/guest-images/ubuntu2204.qcow2
COPY entrypoint.sh /usr/local/bin/lapioplays-entrypoint
COPY supervisor.conf /etc/supervisor/conf.d/lapioplays.conf
RUN chmod +x /usr/local/bin/lapioplays-entrypoint
VOLUME ["/data"]
EXPOSE 2222 3389 6080
ENTRYPOINT ["/usr/bin/supervisord", "-n"]
