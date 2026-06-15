# Completely Offline Cross-Platform ROS 2 (Jazzy) via Zenoh

This repository solves the problem of connecting ROS 2 nodes running in Docker on Mac/Windows to Native Linux machines over a local network, **completely offline**, without Tailscale, VPNs, or complex DDS XML configurations.

It bypasses Docker Desktop's lack of real bridge mode by tunneling DDS multicast traffic over standard TCP using `zenoh-bridge-ros2dds`.

## System Architecture

## Why This Zenoh Solution is Better

If you have researched this problem online, you likely found the standard workarounds: writing complex `fastdds.xml` profiles, hardcoding IP addresses for Discovery Servers, or relying on Windows 11's WSL Mirrored Mode (which doesn't work on Mac && you will face some issues with ros2 daemon). 

What we have built in this repository is significantly more elegant than the standard community workarounds:

1. **Zero XML Configuration:** No messing with `fastdds.xml` or custom ROS 2 profiles.
2. **True Plug-and-Play:** You don't have to change how ROS 2 behaves. It still uses standard UDP multicast *inside* the local environments. Zenoh just silently grabs it and moves it across the network.
3. **Cross-Platform Parity:** It works exactly the same way on Mac, Windows, and Linux. No platform-specific hacks required.
4. **TCP Reliability:** Instead of relying on UDP packets making it across a noisy WiFi network, the bridge uses a solid TCP tunnel (`tcp/0.0.0.0:7447`) to guarantee message delivery.
5. **Modern ROS 2 Support:** Uses the newer `zenoh-bridge-ros2dds` which is optimized specifically for ROS 2 discovery and traffic.

```text
+-------------------------------------------------------------+
| Native Linux Host (ARM64 / amd64)                           |
|                                                             |
|  [ ROS 2 Listener / Talker ]                                |
|             ^                                               |
|             | (Local DDS Multicast)                         |
|             v                                               |
|  [ zenoh-bridge-ros2dds (TCP :7447) ] <==================+  |
+----------------------------------------------------------|--+
                                                           |
                      (TCP Tunnel bypasses Docker Network Isolation)
                                                           |
+----------------------------------------------------------|--+
| Mac / Windows Host                                       |  |
|                                                          |  |
|  +----------------------------------------------------+  |  |
|  | Docker Desktop Lightweight VM                      |  |  |
|  | (Shared Network Namespace via network_mode: host)  |  |  |
|  |                                                    |  |  |
|  |  [ ROS 2 Container ]                               |  |  |
|  |          ^                                         |  |  |
|  |          | (Local DDS Multicast)                   |  |  |
|  |          v                                         |  |  |
|  |  [ zenoh-bridge-ros2dds Client Container ] =========>===+
|  +----------------------------------------------------+  |
+-------------------------------------------------------------+
```

## Project Structure

We've organized the workflow into simple scripts for each platform:

```text
├── .env                  # Configuration (Linux IP, Domain ID)
├── docker-compose.yml    # Docker setup for Mac/Windows
├── Dockerfile            # ROS 2 Jazzy image definition
├── mac/                  # Scripts for MacOS
│   ├── 1_start_docker_env.sh
│   ├── ...
├── windows/              # Scripts for Windows
│   ├── 1_start_docker_env.bat
│   ├── ...
├── linux/         # Scripts for Native Linux
│   ├── 1_install_zenoh.sh
│   ├── ...
└── tests/                # High-frequency payload tests
    ├── blob_talker.py    # Custom throughput benchmark
    └── ...
```

## How It Works

1. **Native Linux** acts as the server. It runs the standalone `zenoh-bridge-ros2dds` binary, listening on TCP port `7447`. It captures all local DDS multicast traffic and forwards it.
2. **Mac / Windows Docker** acts as the client. Docker Compose starts a ROS 2 container (`network_mode: "host"`) alongside a Zenoh Bridge container. The bridge connects *out* of the Docker VM to the Linux machine's IP, tunneling the DDS traffic.
3. Both sides are forced to use `RMW_IMPLEMENTATION=rmw_fastrtps_cpp` to ensure 100% vendor compatibility.

---

## Step 1: Initial Setup (All Platforms)

1. Clone this repository.
2. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` and replace `192.168.x.x` with the actual **Local IPv4 Address of your Native Linux machine**.

---

## Step 2: Native Linux Setup

Run the following scripts from the `linux` folder on your Linux machine:

1. **Install Zenoh** (Downloads the correct architecture binary: amd64 or arm64):
   ```bash
   ./linux/1_install_zenoh.sh
   ```
2. **Start the Zenoh Bridge** (Keep this running in a terminal):
   ```bash
   ./linux/2_start_zenoh_bridge.sh
   ```

---

## Step 3: Mac or Windows Setup

Open a terminal (Mac) or Command Prompt/PowerShell (Windows) and run the scripts in your respective folder.

### On Mac:
1. Start the Docker environment:
   ```bash
   ./mac/1_start_docker_env.sh
   ```

### On Windows:
1. Start the Docker environment:
   ```cmd
   windows\1_start_docker_env.bat
   ```

---

## Step 4: Testing Bidirectional Communication

You can test communication in both directions using the provided scripts.

**Test 1: Mac/Windows Talker ➡️ Linux Listener**
1. On Linux, run: `./linux/4_run_listener.sh`
2. On Mac, run: `./mac/2_run_talker.sh` (or `windows\2_run_talker.bat` on Windows)
3. You should see `Hello World` appearing on the Linux listener!

**Test 2: Linux Talker ➡️ Mac/Windows Listener**
1. On Mac, run: `./mac/3_run_listener.sh` (or `windows\3_run_listener.bat` on Windows)
2. On Linux, run: `./linux/3_run_talker.sh`
3. You should see `Hello World` appearing on the Mac/Windows listener!

---

## Step 5: Throughput Benchmarking

To measure actual bandwidth and latency:

1. **On Linux**, start the bandwidth monitor:
   ```bash
   ./tests/2_linux_speed_listener.sh
   ```
2. **On Mac/Windows**, start the 1MB @ 50Hz talker:
   ```bash
   ./tests/1_mac_speed_talker.sh
   ```

---

## Step 6: Shutting Down

When you are finished, gracefully stop your Docker containers.

**On Mac:**
```bash
./mac/4_stop_docker_env.sh
```

**On Windows:**
```cmd
windows\4_stop_docker_env.bat
```

---

## Roadmap / Future Work

### 1. Direct Mac Docker ↔ Windows Docker Communication
Currently, the Native Linux host acts as the central router/listener that both Mac and Windows Docker VMs connect to. The next major milestone is to enable **direct communication between Mac Docker and Windows Docker** without needing the Native Linux machine.

**Planned Technical Approach:**
- Modify `docker-compose.yml` to allow one of the Docker machines (e.g., Mac) to act as the Zenoh "Server/Listener".
- Expose the Zenoh TCP port from the Docker VM to the host operating system using Docker port mapping (`ports: ["7447:7447/tcp"]`).
- Configure the Zenoh bridge on the "Server" Docker to listen (`-l tcp/0.0.0.0:7447`) instead of connecting as a client.
- Configure the "Client" Docker (e.g., Windows) to connect directly to the Mac's local network IP address.
- Create new dedicated scripts (e.g., `mac/start_as_server.sh` and `windows/start_as_client.bat`) to manage these roles seamlessly.
