FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    for attempt in 1 2 3 4 5; do \
      apt-get update && break || { \
        if [ "$attempt" -eq 5 ]; then exit 1; fi; \
        sleep 5; \
      }; \
    done; \
    apt-get install -y --no-install-recommends \
      qemu-system-x86 \
      qemu-utils \
      cloud-image-utils \
      ca-certificates \
      curl \
      openssl \
      coreutils \
      grep \
      sed \
      openssh-client; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh

ENV VM_OS=debian11 \
    VM_RAM=2048 \
    VM_CPU=2 \
    VM_DISK=20G \
    VM_HOSTNAME=lapioplays \
    VM_PASSWORD=lapio

EXPOSE 2222

VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

