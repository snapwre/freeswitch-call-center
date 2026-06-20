# FreeSWITCH Call Center base image — FreeSWITCH 1.10 plus Call Center & Queue modules
# Built from SignalWire's token-gated Debian packages.
#
# The SignalWire token is supplied as a BuildKit secret (id=signalwire_token):
# read from a tmpfs mount, its only on-disk copy (apt auth.conf) is deleted in
# the same layer, so it never persists in the final image.
#
#   DOCKER_BUILDKIT=1 docker build \
#     --secret id=signalwire_token,env=SIGNALWIRE_TOKEN \
#     -t ghcr.io/snapwre/freeswitch-call-center:latest .
FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=secret,id=signalwire_token \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends gnupg2 wget ca-certificates \
      unixodbc odbc-postgresql; \
    TOKEN="$(cat /run/secrets/signalwire_token)"; \
    wget --http-user=signalwire --http-password="$TOKEN" \
      -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
      https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg; \
    printf 'machine freeswitch.signalwire.com login signalwire password %s\n' "$TOKEN" \
      > /etc/apt/auth.conf; \
    chmod 600 /etc/apt/auth.conf; \
    echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" \
      > /etc/apt/sources.list.d/freeswitch.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      freeswitch \
      freeswitch-mod-event-socket freeswitch-mod-sofia freeswitch-mod-console \
      freeswitch-mod-commands freeswitch-mod-dptools freeswitch-mod-dialplan-xml \
      freeswitch-mod-sndfile freeswitch-mod-native-file freeswitch-mod-tone-stream \
      freeswitch-mod-lua freeswitch-mod-curl freeswitch-mod-say-en \
      freeswitch-mod-expr freeswitch-mod-hash freeswitch-mod-amr freeswitch-mod-spandsp \
      freeswitch-mod-logfile \
      freeswitch-mod-httapi freeswitch-mod-xml-cdr freeswitch-mod-json-cdr freeswitch-mod-xml-curl \
      freeswitch-mod-timerfd \
      # Call Center Specific Modules
      freeswitch-mod-callcenter \
      freeswitch-mod-fifo \
      freeswitch-mod-conference \
      freeswitch-mod-valet-parking \
      freeswitch-mod-db \
      freeswitch-mod-cidlookup \
      freeswitch-mod-shout \
      freeswitch-mod-http-cache \
      freeswitch-mod-voicemail \
      # WebRTC & Verto Modules
      freeswitch-mod-verto \
      freeswitch-mod-rtc; \
    # Build and install mod_audio_stream from source
    apt-get install -y --no-install-recommends \
      git cmake make gcc g++ pkg-config \
      libfreeswitch-dev libssl-dev zlib1g-dev libevent-dev libspeexdsp-dev; \
    git clone https://github.com/amigniter/mod_audio_stream.git /tmp/mod_audio_stream; \
    cd /tmp/mod_audio_stream; \
    git submodule init; \
    git submodule update; \
    mkdir build; \
    cd build; \
    cmake -DCMAKE_BUILD_TYPE=Release -DUSE_TLS=ON ..; \
    make -j$(nproc); \
    make install; \
    cd /; \
    rm -rf /tmp/mod_audio_stream; \
    # Purge compilation tools and development packages
    apt-get purge -y --auto-remove \
      git cmake make gcc g++ pkg-config \
      libfreeswitch-dev libssl-dev zlib1g-dev libevent-dev libspeexdsp-dev; \
    apt-get purge -y --auto-remove wget gnupg2; \
    rm -f /etc/apt/auth.conf /etc/apt/sources.list.d/freeswitch.list \
          /usr/share/keyrings/signalwire-freeswitch-repo.gpg; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /usr/share/freeswitch/sounds/custom

# Exposing 5060/udp (SIP), 5080/udp (alternative SIP / carrier), ESL on 8021/tcp,
# and WebRTC WebSocket/Verto ports (8081/tcp WS, 8082/tcp WSS).
EXPOSE 5060/udp 5080/udp 8021/tcp 8081/tcp 8082/tcp
CMD ["freeswitch", "-nonat", "-nf", "-c"]
