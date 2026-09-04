FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openjdk-21-jre-headless \
        python3 \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/sf \
    && wget -q https://developer.salesforce.com/media/salesforce-cli/sf/channels/stable/sf-linux-x64.tar.xz -O /tmp/sf-linux-x64.tar.xz \
    && tar xJf /tmp/sf-linux-x64.tar.xz -C /opt/sf --strip-components=1 \
    && rm /tmp/sf-linux-x64.tar.xz

ENV PATH="/opt/sf/bin:${PATH}"

RUN useradd -m -s /bin/bash ubuntu || true
USER ubuntu
WORKDIR /workspace
