# System Topology

> **Last updated:** 2026-06-22 (link eth trực tiếp → subnet riêng 192.168.10.0/24, tách WiFi/adb — D-021)
> Physical/logical topology, addressing, and bus parameters. Source of truth: `STM32-2nd/Core/Inc/w5500_config.h`, `STM32-1st/Core/Src/can.c`, `STM32-2nd/Core/Src/can.c`.

## 1. Node map

```
┌──────────────┐   CAN bus 250kbps   ┌──────────────┐   Ethernet/TCP    ┌────────────────────┐
│  Sensor ECU  │  (twisted pair via  │  Gateway ECU │  (W5500, RJ45)    │  Raspberry Pi 4     │
│  STM32F103   │───  MCP2551 xcvr) ──▶│  STM32F103   │──────────────────▶│  + Android ClusterApp│
│ (STM32-1st)  │  ID 0x100 / 0x200   │ (STM32-2nd)  │  18-byte struct    │  TCP server :5000   │
└──────────────┘                     └──────────────┘                    └────────────────────┘
   TX only                          CAN RX + TCP client                     TCP server + display
```

## 2. CAN bus

| Parameter | Value | Evidence |
|-----------|-------|----------|
| Peripheral | CAN1, standard 11-bit IDs | `can.c` `MX_CAN_Init`, `CAN_ID_STD` |
| Bitrate | **250 kbps** | Prescaler 9, BS1 13TQ, BS2 2TQ, SJW 1TQ → 16 TQ @ 36 MHz APB1 = 4 µs/bit |
| Mode | `CAN_MODE_NORMAL`, AutoRetransmission **DISABLE** | `can.c` `hcan.Init` |
| Pins (both nodes) | PA11 = CAN_RX, PA12 = CAN_TX | `HAL_CAN_MspInit` |
| RX path (gateway) | IRQ `USB_LP_CAN1_RX0_IRQn` (NVIC prio 5) → `canToEthQueue` | `STM32-2nd/Core/Src/can.c` |
| Transceiver | MCP2551 (external) | hardware |
| Frames | `0x100` control (DLC 4), `0x200` sensor (DLC 8) | [can_database.md](can_database.md) |

## 3. Ethernet / TCP

| Item | Value | Evidence |
|------|-------|----------|
| Controller | WIZnet **W5500** over SPI1 | `w5500_port.c` (`hspi1`) |
| W5500 chip-select | **PB12** (active low) | `w5500_port.c` `W5500_Select/Unselect` |
| Gateway static IP | `192.168.10.50` | `w5500_config.h` `W5500_IP` |
| Gateway MAC | `00:08:DC:12:34:56` | `w5500_config.h` `W5500_MAC` |
| Subnet / GW | `255.255.255.0` / `192.168.10.1`, `NETINFO_STATIC` (no DHCP) | `w5500_config.h`, `W5500_Init` |
| **App endpoint (TCP server)** | `APP_IP` = `192.168.10.104` (Pi **eth0**), `APP_PORT` = `5000` | `w5500_config.h` |
| TCP roles | **Gateway = client**, **Android = server** | `w5500_port.c` `connect()`, `GatewayClient.java` `ServerSocket` |
| Gateway local port | rotates `50000`–`60000` | `w5500_port.c` `W5500_EnsureSocket` |
| Socket | `SOCKET_ID 0`, `Sn_MR_TCP`, **`SF_IO_NONBLOCK`** | `w5500_config.h`, `w5500_port.c` (D-018) |

> ⚠️ `APP_IP` must equal the IP of the **interface that actually carries the TCP packets** — với cáp eth trực tiếp đó là **eth0** của Pi (`192.168.10.104`), KHÔNG phải IP WiFi/wlan0. Sai interface → W5500 kẹt `SOCK_SYNSENT`, log `[ETH] socket not ready, drop frame`. Link eth điểm-điểm dùng subnet riêng `192.168.10.0/24` tách khỏi WiFi `192.168.1.x` (adb) để tránh 2 interface cùng dải (D-021). IP tĩnh, không DHCP fallback → đổi IP thì sửa `APP_IP` + flash lại. Chẩn đoán nhanh bằng `W5500_LogDiag` (VERSIONR/PHY link).

## 4. Addressing summary

| Node | L2/L3 identity | Listening | Connects to |
|------|----------------|-----------|-------------|
| Sensor ECU | CAN producer (0x100, 0x200) | — | CAN bus |
| Gateway ECU | IP `192.168.10.50`, MAC `00:08:DC:12:34:56` | CAN RX FIFO0 | `192.168.10.104:5000` (TCP client) |
| RPi + Android | eth0 `192.168.10.104` (data) · wlan0 `192.168.1.x` (adb) | TCP `:5000` (server, mọi interface) | — |
