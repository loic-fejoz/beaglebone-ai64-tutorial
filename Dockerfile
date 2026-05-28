# syntax=docker/dockerfile:1
FROM --platform=linux/arm64 debian:bullseye

# Install base packages
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    ca-certificates \
    make \
    device-tree-compiler \
    && rm -rf /var/lib/apt/lists/*

# Add BeagleBoard Debian repositories and import signing key
RUN echo "deb [arch=arm64] http://repos.rcn-ee.com/debian-arm64/ bullseye main" > /etc/apt/sources.list.d/rcn-ee.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-key D284E608A4C46402

# Install official TI compilers and support libraries (same versions as board)
RUN apt-get update && apt-get install -y \
    ti-c7000-cgt-v2.1 \
    ti-c6000-cgt-v8.3 \
    ti-pru-cgt-v2.3 \
    ti-pru-software \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
