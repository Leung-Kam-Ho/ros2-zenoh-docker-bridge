# Completely Offline Cross-Platform ROS 2 (Jazzy) via Zenoh

This repository solves the problem of connecting ROS 2 nodes running in Docker on Mac/Windows to Native Linux machines over a local network, **completely offline**, without Tailscale, VPNs, or complex DDS XML configurations.

It bypasses Docker Desktop's lack of real bridge mode by tunneling DDS multicast traffic over standard TCP using `zenoh-bridge-dds`.

## System Architecture

```text
+-------------------------------------------------------------+
| Native Linux Host (ARM64 / amd64)                           |
|                                                             |
|  [ ROS 2 Listener / Talker ]                                |
|             ^                                               |
|             | (Local DDS Multicast)                         |
|             v                                               |
|  [ zenoh-bridge-dds (TCP :7447) ] <======================+  |
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
|  |  [ zenoh-bridge-dds Client Container ] ==============>===+
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
├── native_linux/         # Scripts for Native Linux
│   ├── 1_install_zenoh.sh
│   ├── ...
└── tests/                # High-frequency payload tests
```

## How It Works

1. **Native Linux** acts as the server. It runs the standalone `zenoh-bridge-dds` binary, listening on TCP port `7447`. It captures all local DDS multicast traffic and forwards it.
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

Run the following scripts from the `native_linux` folder on your Linux machine:

1. **Install Zenoh** (Downloads the correct architecture binary: amd64 or arm64):
   ```bash
   ./native_linux/1_install_zenoh.sh
   ```
2. **Start the Zenoh Bridge** (Keep this running in a terminal):
   ```bash
   ./native_linux/2_start_zenoh_bridge.sh
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
1. On Linux, run: `./native_linux/4_run_listener.sh`
2. On Mac, run: `./mac/2_run_talker.sh` (or `windows\2_run_talker.bat` on Windows)
3. You should see `Hello World` appearing on the Linux listener!

**Test 2: Linux Talker ➡️ Mac/Windows Listener**
1. On Mac, run: `./mac/3_run_listener.sh` (or `windows\3_run_listener.bat` on Windows)
2. On Linux, run: `./native_linux/3_run_talker.sh`
3. You should see `Hello World` appearing on the Mac/Windows listener!

---

## Step 5: Shutting Down

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

## Obstacles Faced & Lessons Learned

Creating a completely offline, real-time, cross-platform bridge between isolated Docker VMs and native machines came with several unique challenges:

### 1. Docker Desktop Networking Limitations
**The Problem:** Docker Desktop on Mac and Windows runs containers inside a hidden lightweight VM. Unlike native Linux, Docker Desktop does not support true `--network="host"`. DDS relies entirely on UDP Multicast for node discovery, which simply does not pass through the VM's NAT boundary.
**The Solution:** Using `zenoh-bridge-dds`. By deploying a Zenoh bridge sidecar container *inside* the Docker VM and sharing the VM's network namespace, we captured the DDS multicast traffic locally and tunneled it via standard TCP over port `7447` out to the Native Linux host.

### 2. Mixed DDS Vendors Over Zenoh
**The Problem:** Ubuntu uses FastDDS by default for ROS 2, while other distributions or Docker configurations occasionally default to CycloneDDS. When tunneling DDS packets over Zenoh, mismatched RMW implementations caused the nodes to "see" each other via Zenoh discovery but silently fail to deserialize the actual messages.
**The Solution:** Enforcing `export RMW_IMPLEMENTATION=rmw_fastrtps_cpp` across every single environment (Linux, Mac Docker, Windows Docker) guaranteed identical binary serialization.

### 3. Shell Expansion Breaking Zenoh Topics
**The Problem:** We wanted to bridge all topics dynamically using the flag `-a ".*"`. However, the `/bin/ash` shell inside the Zenoh container interpreted `.*` as a file glob and replaced it with local hidden directories (like `.` and `..`), causing Zenoh to crash with a Regex Parse Error.
**The Solution:** By overriding the `entrypoint:` in `docker-compose.yml` to use the JSON array syntax `entrypoint: ["/zenoh-bridge-dds"]`, we bypassed shell execution entirely, preserving the raw `.*` string for the application.

### 4. Zenoh Binary Architecture Mismatches
**The Problem:** Native Linux often runs on ARM processors (like inside UTM VMs on Apple Silicon), while Windows runs on `x86_64`.
**The Solution:** Added an architecture detection mechanism (`uname -m`) in the Linux installation script that dynamically fetches the correct standalone binary (`aarch64` vs `x86_64`) from Eclipse Zenoh's GitHub releases.

### 5. Windows Docker Credential Bug
**The Problem:** Windows Docker Desktop frequently fails to pull images due to a bug where the Windows Credential Manager authentication session expires, throwing the error: `A specified logon session does not exist. It may already have been terminated.`
**The Solution:** Running `docker logout` in PowerShell clears the corrupt credential state, allowing the user to pull the public `eclipse/zenoh-bridge-dds` image seamlessly.

## Roadmap / Future Work

### 1. Direct Mac Docker ↔ Windows Docker Communication
Currently, the Native Linux host acts as the central router/listener that both Mac and Windows Docker VMs connect to. The next major milestone is to enable **direct communication between Mac Docker and Windows Docker** without needing the Native Linux machine.

**Planned Technical Approach:**
- Modify `docker-compose.yml` to allow one of the Docker machines (e.g., Mac) to act as the Zenoh "Server/Listener".
- Expose the Zenoh TCP port from the Docker VM to the host operating system using Docker port mapping (`ports: ["7447:7447/tcp"]`).
- Configure the Zenoh bridge on the "Server" Docker to listen (`-l tcp/0.0.0.0:7447`) instead of connecting as a client.
- Configure the "Client" Docker (e.g., Windows) to connect directly to the Mac's local network IP address.
- Create new dedicated scripts (e.g., `mac/start_as_server.sh` and `windows/start_as_client.bat`) to manage these roles seamlessly.
