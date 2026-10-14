# TrinityCore "forever" fork — native arm64 build (server + tools)
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake \
    libboost-all-dev \
    libssl-dev \
    default-libmysqlclient-dev \
    libreadline-dev libncurses-dev \
    zlib1g-dev libbz2-dev liblzma-dev libzstd-dev \
    ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

RUN mkdir -p /build && cd /build \
    && cmake /src -DCMAKE_INSTALL_PREFIX=/trinity \
       -DCMAKE_BUILD_TYPE=RelWithDebInfo \
       -DTOOLS=1 \
    && make -j$(nproc) worldserver bnetserver mapextractor vmap4extractor vmap4assembler mmaps_generator \
    && make install

# ---- runtime ----
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-all-dev libssl3 libmysqlclient21 libreadline8 libncurses6 \
    zlib1g libbz2-1.0 liblzma5 libzstd1 mariadb-client \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /trinity /trinity
COPY --from=build /src/sql /src/sql
WORKDIR /trinity
CMD ["/trinity/bin/worldserver", "-c", "/trinity/env/worldserver.conf"]
