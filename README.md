# Cross-Platform ROS 2 (Jazzy) over Docker via Zenoh Bridge

This repository provides a seamless, 100% offline solution for running ROS 2 natively on Linux while communicating effortlessly with ROS 2 running inside Docker on macOS and Windows. 

Because Docker on Mac and Windows runs inside a lightweight VM, DDS multicast discovery cannot escape to the physical Local Area Network (LAN). We solve this using **Zenoh**. The `zenoh-bridge-dds` plugin captures DDS traffic inside the Docker VM, funnels it through a standard TCP connection to the Linux machine, and converts it back to DDS.

## Architecture

* **Device 1 (Linux - Native):** Acts as the central hub. Runs native ROS 2 Jazzy and a Zenoh bridge listening on a TCP port (`7447`).
* **Device 2 (Mac - Docker):** Runs ROS 2 Jazzy in a container + a Zenoh bridge container that dials out to the Linux IP.
* **Device 3 (Windows - Docker):** Runs ROS 2 Jazzy in a container + a Zenoh bridge container that dials out to the Linux IP.

---

## Step 1: Set up the Native Linux Machine (The Hub)

On your physical Linux machine, you need to install the Zenoh DDS bridge and start it in "Listen" mode.

1. **Install ROS 2 Jazzy** natively (if not already installed).
2. **Install Zenoh DDS Bridge:**
   Depending on your Linux architecture, download the correct pre-compiled binary:

   **For x86_64 (Intel/AMD) Linux:**
   ```bash
   curl -L https://github.com/eclipse-zenoh/zenoh-plugin-dds/releases/latest/download/zenoh-plugin-dds-1.9.0-x86_64-unknown-linux-gnu-standalone.zip -o zenoh-bridge.zip
   unzip zenoh-bridge.zip
   sudo mv zenoh-bridge-dds /usr/local/bin/
   ```

   **For aarch64/ARM64 Linux (e.g., Ubuntu in UTM on Apple Silicon, Raspberry Pi):**
   ```bash
   curl -L https://github.com/eclipse-zenoh/zenoh-plugin-dds/releases/latest/download/zenoh-plugin-dds-1.9.0-aarch64-unknown-linux-gnu-standalone.zip -o zenoh-bridge.zip
   unzip zenoh-bridge.zip
   sudo mv zenoh-bridge-dds /usr/local/bin/
   ```
   *(Alternatively, you can install via `cargo install zenoh-bridge-dds` if you have Rust installed).*

3.    **Start the Bridge as a Router:**
   Open a terminal and run the bridge. We use `-m router` to act as the central hub, and `-a ".*"` to ensure *all* ROS 2 topics are explicitly allowed and routed.
   ```bash
   export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
   zenoh-bridge-dds -m router -l tcp/0.0.0.0:7447 -a ".*"
   ```

4. **Find the Linux Machine's LAN IP:**
   ```bash
   ip addr
   ```
   *Note this IP down (e.g., `192.168.1.100`). You will need it for the Mac and Windows setups.*

---

## Step 2: Set up Mac and Windows (Docker)

On both your Mac and Windows machines, you will use the provided `docker-compose.yml` file.

1. **Clone/Copy this repository** to your Mac and Windows machines.
2. **Configure the IP Address:**
   Rename `.env.example` to `.env` and insert your Linux machine's IP address.
   ```bash
   cp .env.example .env
   ```
   Edit `.env` (using VS Code, nano, notepad, etc.):
   ```env
   LINUX_IP=192.168.1.100  # <--- Change this to your Linux IP!
   ROS_DOMAIN_ID=0
   ```

3. **Start the Docker Containers:**
   In the directory containing `docker-compose.yml`, run:
   ```bash
   docker compose up -d
   ```
   *This starts the `ros2_jazzy_node` container in the background alongside the `ros2_zenoh_bridge` sidecar.*

---

## Step 3: Test the Communication!

Now let's verify that a ROS 2 Topic is visible across all three operating systems.

### 1. Start a Talker on Linux (Native)
Open a new terminal on your Linux machine, source ROS 2, and start publishing:
```bash
source /opt/ros/jazzy/setup.bash
ros2 run demo_nodes_cpp talker
```

### 2. Check the Mac (Docker)
Open a terminal on your Mac, drop into the running ROS 2 container, and look for the topic:
```bash
# Exec into the running ROS 2 container
docker exec -it ros2_jazzy_node bash

# Inside the container, source ROS 2
source /opt/ros/jazzy/setup.bash

# List the topics to prove discovery works!
ros2 topic list

# Listen to the messages
ros2 run demo_nodes_cpp listener
```
*You should see "I heard: [Hello World: X]" pouring in from the Linux machine.*

### 3. Check the Windows (Docker)
Repeat the exact same steps on Windows:
```powershell
docker exec -it ros2_jazzy_node bash
source /opt/ros/jazzy/setup.bash
ros2 run demo_nodes_cpp listener
```

## Bonus: Bidirectional Communication
Because the Zenoh bridge maps the DDS layer perfectly, this works in **any** direction. 
Try stopping the talker on Linux, and start it inside the Mac Docker container instead (`ros2 run demo_nodes_cpp talker`). Then run the `listener` on Linux and Windows. It will work flawlessly without any routing/NAT configuration!
