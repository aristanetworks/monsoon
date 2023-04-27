# Build ipxe from source

FROM debian:10

RUN apt-get update && apt-get install -y build-essential git gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu lzma-dev liblzma-dev gawk

ARG IPXE_VERSION=988d2c13cdf0f0b4140685af35ced70ac5b3283c
RUN git clone https://github.com/ipxe/ipxe /ipxe --single-branch && git -C /ipxe checkout ${IPXE_VERSION}

WORKDIR /ipxe/src

RUN sed -i 's://#define NSLOOKUP_CMD:#define NSLOOKUP_CMD:' config/general.h
RUN sed -i 's://#define CONSOLE_CMD:#define CONSOLE_CMD:' config/general.h
RUN sed -i 's://#define REBOOT_CMD:#define REBOOT_CMD:' config/general.h
RUN sed -i 's:#undef\tDOWNLOAD_PROTO_HTTPS:#define DOWNLOAD_PROTO_HTTPS:' config/general.h
RUN sed -i 's://#define CONSOLE_FRAMEBUFFER:#define CONSOLE_FRAMEBUFFER:' config/console.h

COPY embed.ipxe /ipxe/src

# x86_64

RUN make -j$(nproc) bin-x86_64-efi/snponly.efi EMBED=embed.ipxe
RUN make -j$(nproc) EXTRA_CFLAGS="-fno-pie" bin-x86_64-pcbios/undionly.kpxe EMBED=embed.ipxe

# AArch64

ENV CROSS=aarch64-linux-gnu-
RUN make -j$(nproc) bin-arm64-efi/snponly.efi EMBED=embed.ipxe
