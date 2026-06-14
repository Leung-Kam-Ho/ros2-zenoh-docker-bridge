# jazzy-docker-cross

ROS 2 Jazzy in a Docker container, cross-device communication ready (macOS + Windows).

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Builds the `r2_jazzy` image from `osrf/ros:jazzy-desktop` |
| `run_r2_jazzy.sh` / `.bat` | Launches a container with name, domain ID, and optional discovery server |
| `run_r2_jazzy_discovery_server.sh` / `.bat` | Starts a Fast DDS discovery server for cross-device communication |

## Dockerfile

- **Base:** `osrf/ros:jazzy-desktop`
- **Adds:** `net-tools`, `neofetch`, `iputils-ping`

## Usage

### Build

```bash
docker build -t r2_jazzy .
```

### Local — multiple containers on the same machine

Create the shared network once:

```bash
docker network create r2_jazzy_net
```

Launch containers:

```bash
./run_r2_jazzy.sh talker 42
./run_r2_jazzy.sh listener 42
```

Containers discover each other via the bridge network. Use the same `ROS_DOMAIN_ID` to share topics; different IDs isolate them.

### Cross-device — containers on different machines

Start the discovery server on one machine:

```bash
./run_r2_jazzy_discovery_server.sh
```

Connect containers from any machine on the LAN:

```bash
./run_r2_jazzy.sh talker 42 192.168.1.100
./run_r2_jazzy.sh listener 42 192.168.1.100
```

The discovery server relays discovery traffic, so DDS multicast is not required.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   macOS / Windows                    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │          Docker Bridge Network                │    │
│  │              r2_jazzy_net                     │    │
│  │                                              │    │
│  │  ┌──────────────┐     ┌──────────────┐       │    │
│  │  │  r2_jazzy_A   │     │  r2_jazzy_B   │       │    │
│  │  │ DOMAIN_ID=42  │◄───►│ DOMAIN_ID=42  │       │    │
│  │  │ UDPv4 only    │     │ UDPv4 only    │       │    │
│  │  └──────────────┘     └──────────────┘       │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────────────────────────────────────┐    │
│  │  Cross-Device (optional):                     │    │
│  │                                              │    │
│  │  ┌──────────────────┐  UDP :11811             │    │
│  │  │ Discovery Server │◄────────               │    │
│  │  │ (fastdds)        │                         │    │
│  │  └──────────────────┘                         │    │
│  └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
         ▲                    ▲
         │ UDP :11811         │ UDP :11811
         │                    │
  ┌──────────────┐    ┌──────────────┐
  │ Other Device  │    │ Other Device  │
  │ r2_jazzy_C    │    │ r2_jazzy_D    │
  │ DOMAIN_ID=42  │    │ DOMAIN_ID=42  │
  └──────────────┘    └──────────────┘
```
