FROM osrf/ros:jazzy-desktop

RUN apt-get update && apt-get install -y \
    net-tools \
    neofetch \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

RUN echo 'export DISPLAY=host.docker.internal:0' >> ~/.bashrc && \
    echo 'export ROS_DOMAIN_ID=0' >> ~/.bashrc

