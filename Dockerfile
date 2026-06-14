FROM osrf/ros:jazzy-desktop
RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard-tools \
    openresolv \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*
RUN echo 'export DISPLAY=host.docker.internal:0' >> ~/.bashrc
