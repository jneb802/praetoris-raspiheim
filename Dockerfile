FROM ubuntu:24.04

#Install Prereqs
RUN apt-get update -y \
&&  apt-get upgrade -y \
&&  apt-get install -y wget gpg tar unzip libatomic1 libpulse0 libpulse-dev
# Install box64 from prebuilt repository
RUN rm -f /etc/apt/sources.list.d/box64.list /etc/apt/sources.list.d/box64.sources \
&&  mkdir -p /usr/share/keyrings \
&&  wget -qO- "https://atoll6.github.io/box64-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg \
&&  echo "Types: deb\nURIs: https://atoll6.github.io/box64-debs/debian\nSuites: ./\nSigned-By: /usr/share/keyrings/box64-archive-keyring.gpg" > /etc/apt/sources.list.d/box64.sources \
&&  apt-get update \
&&  apt-get install -y box64-rpi5arm64 \
&&  apt-get clean

# Install Steam
RUN mkdir   /steamcmd \
&&  cd      /steamcmd \
&&  wget -qO- "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Install required library and scripts
COPY ./add /scripts/
RUN chmod +x /scripts/valheim.sh

# Setting Environmental Variables
ENV SERVER_NAME=Raspiheim \
    SERVER_PASS=Raspipass \
    WORLD_NAME=Raspiworld \
    SAVE_DIR=/data \
    PUBLIC=disabled \
    UPDATE=enabled \
    SAVE_INTERVAL=1800 \
    CROSSPLAY=enabled \
    BEPINEX=disabled \
    BEPINEX_VERSION=5.4.2333

EXPOSE 2456/udp 2457/udp

ENTRYPOINT ["/scripts/valheim.sh"]

LABEL org.opencontainers.image.title="Raspiheim" \
      org.opencontainers.image.description="Valheim server for Raspberry Pi" \
      org.opencontainers.image.vendor="atoll6"
