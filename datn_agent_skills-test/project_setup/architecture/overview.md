# Project Overview — Automotive ECU Network Simulation

> **Last updated:** 2026-06-22 (APP_IP → eth0 Pi 192.168.10.104, subnet riêng — D-021)
> **Read this first**, together with [DECISIONS.md](DECISIONS.md) and [PROJECT_MAP.md](PROJECT_MAP.md). These three files are enough to start a task without re-scanning the whole repo.

## 1. What this project is

A graduation project that **simulates an automotive electronic network**. Physical inputs (buttons + potentiometers) are read by a sensor microcontroller, sent over a **CAN bus**, translated to **Ethernet/TCP** by a gateway microcontroller, and visualized on an **Android digital instrument cluster** running on a Raspberry Pi 4 head unit.

## 2. The four layers (never move responsibilities between them)

| Layer | Hardware | Role | Source folder |
|-------|----------|------|---------------|
| **Sensor ECU** | STM32F103C8 | **Source of truth** for vehicle state. Reads keypad + ADC, owns `ControlData`/`SensorData`, emits CAN. | `STM32-1st/` ([sensor_ecu.md](sensor_ecu.md)) |
| **Gateway ECU** | STM32F103C8 + MCP2551 + W5500 | **Protocol translator only.** CAN → reconstruct `VehicleState` → TCP. No vehicle logic. | `STM32-2nd/` ([gateway_ecu.md](gateway_ecu.md)) |
| **Raspberry Pi 4** | RPi 4 | **Host** that runs the Android cluster app (carries the TCP server endpoint). | host only ([raspberry_pi.md](raspberry_pi.md)) |
| **Android App** | ClusterApp | **Visualization layer.** TCP server, parses packets, draws gauges/indicators. Display-only + UI-derived warnings. | `ClusterApp/` ([android_app.md](android_app.md)) |

## 3. Tech stack

| Layer | Technologies |
|-------|--------------|
| Sensor ECU | C, STM32 HAL, FreeRTOS (CMSIS-RTOS v2), STM32CubeIDE, target `STM32F103C8Tx` |
| Gateway ECU | C, STM32 HAL, FreeRTOS, WIZnet ioLibrary (W5500), STM32CubeIDE |
| Android App | Java, Android SDK (min 24 / target 36), Gradle |

## 4. End-to-end data flow (corrected to match source)

```
[Keypad 4x3] [3x Potentiometer]
        │ buttonTask          │ ADCTask (DMA)
        ▼                     ▼
   ControlData_t        SensorData_t          ← STM32-1st (Sensor ECU)
        │ CAN 0x100 (4B)      │ CAN 0x200 (8B, big-endian)
        └──────────┬──────────┘
                   ▼  CAN bus @ 250 kbps
        decodeCAN() accumulates → VehicleState_t (18 B)   ← STM32-2nd (Gateway ECU)
                   │ W5500 TCP CLIENT  (send raw 18-byte struct)
                   ▼  Ethernet / TCP, connects out to APP_IP:5000
        ServerSocket accept() on 0.0.0.0:5000              ← Android ClusterApp on RPi 4
        readFully(18) → applyGatewayPacket() (little-endian)
                   ▼
        VehicleState (POJO) → GaugeView / indicators (30 FPS)
```

### Ground-truth notes (these override older drafts/TECHNICAL_SPECS.md)
- The Ethernet payload is a **raw 18-byte `VehicleState_t` struct over TCP** — *not* a 16-byte framed packet with sync bytes / CRC16. Integrity is left to TCP.
- **Android is the TCP server** (`0.0.0.0:5000`); the **Gateway's W5500 is the TCP client** that connects out to `APP_IP` = Pi **eth0** (`192.168.10.104:5000`, KHÔNG phải IP WiFi). W5500 static IP is `192.168.10.50`; link eth điểm-điểm dùng subnet riêng `192.168.10.0/24` tách WiFi (D-021).
- CAN sensor fields (`0x200`) are **big-endian** on the wire; the gateway reconstructs them to native `uint16` and the 18-byte struct is read **little-endian** by Android. The transform is consistent end-to-end — see [integration.md](integration.md).

## 5. Repository layout

| Path | Submodule repo | Contents |
|------|----------------|----------|
| `STM32-1st/` | `Je-Tiev/STM32_Sensor_CAN` | Sensor ECU firmware |
| `STM32-2nd/` | `Je-Tiev/STM32_Gateway_CAN` | Gateway ECU firmware |
| `ClusterApp/` | `Je-Tiev/CarClusterApp` | Android cluster app |
| `datn_agent_skills-test/` | (this folder) | Architecture knowledge base + AI-agent config (Antigravity `.agents/`, Claude Code `.claude/`) |
