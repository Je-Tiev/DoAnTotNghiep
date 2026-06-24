# Project Map

> **Last updated:** 2026-06-21
> Navigation index: where things live and who owns what. Read this + [overview.md](overview.md) + [DECISIONS.md](DECISIONS.md) before any task. Jump straight to the `file:symbol` below instead of grepping.

## 1. Folder hierarchy

```
Đồ án tốt nghiệp/
├── STM32-1st/        → Sensor ECU firmware  (repo Je-Tiev/STM32_Sensor_CAN)
├── STM32-2nd/        → Gateway ECU firmware (repo Je-Tiev/STM32_Gateway_CAN)
├── ClusterApp/       → Android cluster app  (repo Je-Tiev/CarClusterApp)
└── datn_agent_skills-test/
    ├── project_setup/architecture/   → THIS knowledge base
    ├── .agents/   → Antigravity rules + skills
    ├── .claude/   → Claude Code adapter (CLAUDE.md, setup.ps1)
    └── tools/     → helper scripts (bundle_skills.py, gen_project_map.py)
```

## 2. Module hierarchy & key entry points

### Sensor ECU — `STM32-1st/` (source of truth)
| What | Where |
|------|-------|
| Tasks / keypad map / warnings | `Core/Src/freertos.c` (`buttonTaskEntry`, `StartADCTask`, `StartCANTask`, `process_keypad_input`) |
| CAN packing + CRC8 | `Core/Src/can_encode.c` (`CAN_Encode_Control`, `CAN_Encode_Sensor`) |
| CAN init / TX | `Core/Src/can.c` (`MX_CAN_Init`, `CAN_Send`) |
| Keypad / ADC / LEDs | `Core/Src/keypad.c`, `adc.c`, `hc595.c`, `light_manager.c` |
| Data structs | `Core/Inc/can_msg.h` |

### Gateway ECU — `STM32-2nd/` (translator only)
| What | Where |
|------|-------|
| RX→decode→send loop | `Core/Src/freertos.c` (`Eth_SendTask_Entry`) |
| Frame validate + decode + diag | `Core/Src/can_decode.c` (`decodeCAN`), `Core/Src/can.c` (`CAN_ValidateFrame`) |
| W5500 driver + socket FSM | `Core/Src/w5500_port.c` (`W5500_Init`, `W5500_EnsureSocket`, `W5500_SendData`) |
| Network config | `Core/Inc/w5500_config.h` |
| Data structs | `Core/Inc/can_msg.h` (`VehicleState_t`) |

### Android — `ClusterApp/` (display + TCP server)
| What | Where (under `app/src/main/java/com/example/carclusterapp/`) |
|------|------|
| TCP server / receive | `network/GatewayClient.java`, `network/SocketService.java` |
| Packet parse + warnings | `controller/ClusterController.java` (`applyGatewayPacket`) |
| Model | `model/VehicleState.java` |
| UI / gauges | `ui/ClusterActivity.java`, `ui/view/GaugeView.java` |
| Resilience | `receiver/BootReceiver.java`, `receiver/WatchdogReceiver.java` |

## 3. Ownership of responsibilities

| Responsibility | Owner |
|----------------|-------|
| Read inputs, hold vehicle state | Sensor ECU |
| CAN frame schema | `can_encode.c` ↔ `can_decode.c` (sync'd) |
| CAN → Ethernet translation | Gateway ECU |
| Network hosting | Raspberry Pi 4 |
| Visualization + derived warnings | Android app |

## 4. Communication paths
`Sensor —CAN 0x100/0x200 250kbps→ Gateway —TCP 18B→ Android(:5000 on RPi)`
Details: [can_database.md](can_database.md) · [integration.md](integration.md) · [system_topology.md](system_topology.md).

## 5. Per-area doc index
[overview.md](overview.md) · [system_topology.md](system_topology.md) · [sensor_ecu.md](sensor_ecu.md) · [gateway_ecu.md](gateway_ecu.md) · [raspberry_pi.md](raspberry_pi.md) · [android_app.md](android_app.md) · [vehicle_state.md](vehicle_state.md) · [can_database.md](can_database.md) · [integration.md](integration.md) · [DECISIONS.md](DECISIONS.md)
