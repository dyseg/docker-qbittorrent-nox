# image for building
FROM alpine:latest AS builder

ARG QBT_VERSION

# alpine linux qbittorrent package: https://git.alpinelinux.org/aports/tree/community/qbittorrent/APKBUILD

# Check environment variables
RUN \
  if [ -z "$QBT_VERSION" ]; then \
    echo 'Missing $QBT_VERSION variable. Check your command line arguments.' && \
    exit 1 ; \
  fi

RUN \
  apk --update-cache add \
    boost-dev \
    cmake \
    g++ \
    libtorrent-rasterbar-dev \
    ninja \
    qt6-qtbase-dev \
    qt6-qttools-dev

RUN \
  if [ "$QBT_VERSION" = "devel" ]; then \
    wget https://github.com/qbittorrent/qBittorrent/archive/refs/heads/master.zip && \
    unzip master.zip && \
    cd qBittorrent-master ; \
  else \
    wget "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-${QBT_VERSION}.tar.gz" && \
    tar -xf "release-${QBT_VERSION}.tar.gz" && \
    cd "qBittorrent-release-${QBT_VERSION}" ; \
  fi && \
  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CXX_FLAGS="-flto=auto" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto=auto" \
    -DGUI=OFF \
    -DQT6=ON && \
  cmake --build build && \
  cmake --install build

# image for running
FROM alpine:latest

RUN \
  apk --no-cache add \
    doas \
    libtorrent-rasterbar \
    python3 \
    qt6-qtbase \
    tini

RUN \
  adduser \
    -D \
    -H \
    -s /sbin/nologin \
    -u 1000 \
    qbtUser && \
  echo "permit nopass :root" >> "/etc/doas.d/doas.conf"

COPY --from=builder /usr/local/bin/qbittorrent-nox /usr/bin/qbittorrent-nox

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
