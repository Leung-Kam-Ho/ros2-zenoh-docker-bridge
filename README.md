# ros2=jazzy-cross
## Goal
Enable ROS 2 communication between Docker containers on macOS (Docker Desktop, arm64 emulating amd64) and native ROS 2 on a Linux machine over LAN, fully offline.
Constraints & Preferences
- Docker Desktop for Mac — containers run inside a VM with private bridge IPs, not directly routable from the LAN
- Must work fully offline — no cloud services
- Fast DDS is the DDS implementation in ROS 2 Jazzy
- macOS on arm64 (Apple Silicon), ROS Docker image is amd64 — runs under Rosetta emulation
- Linux machine IP: 192.168.31.249, Mac LAN IP: 192.168.31.248