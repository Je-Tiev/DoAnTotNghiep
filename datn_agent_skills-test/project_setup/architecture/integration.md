# Integration — End-to-End Data Flow

> **Last updated:** 2026-06-22 (eth trực tiếp → subnet riêng 192.168.10.0/24; APP_IP = eth0 Pi — D-021)
> One full trace of a value from physical input to pixel, naming every transformation and ownership boundary. Companion to [vehicle_state.md](vehicle_state.md) and [can_database.md](can_database.md).

## 1. Hop-by-hop trace

```
① Sensor ECU (STM32-1st)
   keypad/ADC → g_ctrl_data / g_sensor_data            [OWNS state]
   CAN_Encode_Control → 0x100 (4B, CRC8)
   CAN_Encode_Sensor  → 0x200 (8B, big-endian, CRC8)
   sensorQueue → CANTask → HAL_CAN_AddTxMessage
        │ CAN bus 250 kbps
        ▼
② Gateway ECU (STM32-2nd)                               [TRANSLATE only]
   CAN RX IRQ → canToEthQueue
   CAN_ValidateFrame → decodeCAN:
       0x100 → state.control.*   (bit unpack)
       0x200 → state.sensor.*    (BE → native uint16)
   ↳ persistent VehicleState_t accumulates latest control + latest sensor
   W5500_EnsureSocket (TCP client) → connect 192.168.10.104:5000 (eth0 Pi)
   memcpy(&state) → send 18 raw bytes (native little-endian)
        │ Ethernet / TCP
        ▼
③ Raspberry Pi 4                                        [HOST only]
   runs the Android app; provides the APP_IP endpoint
        ▼
④ Android ClusterApp                                    [DISPLAY only]
   ServerSocket :5000 → readFully(18)
   applyGatewayPacket: little-endian parse + scaling
       speed = u16/65535*240, fuel = u16/65535, rpm = u16/65535*8000
   derive engine/brake/oil/temp warnings (UI-side)
   VehicleState (POJO) → GaugeView + indicators @ ~30 FPS
```

## 2. Message formats at each boundary

| Boundary | Format | Integrity |
|----------|--------|-----------|
| Sensor → CAN | `0x100` 4B + `0x200` 8B | CRC8 (0x07) + 4-bit sequence per frame |
| Gateway → TCP | raw 18-byte `VehicleState_t` struct | TCP only (no app-layer CRC/sync bytes) |
| TCP → App | 18-byte fixed read (`readFully`) | length-framed by fixed size |

## 3. The endianness transform (call it out explicitly)

1. `0x200` puts speed/fuel/rpm on CAN **big-endian** (`data[0]=val>>8`).
2. Gateway `decodeCAN` rebuilds native `uint16`: `val = data[0]<<8 | data[1]`.
3. `memcpy` of the struct emits those `uint16` as **little-endian** (Cortex-M3 native) into TCP bytes 12–17.
4. Android reads **little-endian**: `(b12) | (b13<<8)`.

→ Values are preserved. The big-endian CAN choice and little-endian TCP read are **a matched pair**; changing only one side would corrupt the data. Document, don't "fix".

## 4. Ownership boundaries (do not cross)

| Concern | Owner | Everyone else |
|---------|-------|---------------|
| Vehicle state truth | Sensor ECU | reads/relays only |
| CAN frame definition | `can_encode.c` / `can_decode.c` (kept in sync) | — |
| CAN→TCP re-framing | Gateway ECU | — |
| Network endpoint hosting | Raspberry Pi | — |
| Display + derived warnings | Android app | not transmitted upstream |

## 5. Common integration failure points

- **#1: `APP_IP` ≠ IP của interface thật mang gói** → W5500 never reaches `SOCK_ESTABLISHED` → log spam `[ETH] socket not ready, drop frame`. Với cáp eth trực tiếp, gói đi qua **eth0** của Pi nên `APP_IP` phải là IP eth0 (`192.168.10.104`), KHÔNG phải IP WiFi/wlan0 (bẫy thường gặp: thấy IP WiFi "trùng" nhưng gói lại ra eth0). Link eth điểm-điểm để **subnet riêng** `192.168.10.0/24`, tách dải WiFi `192.168.1.x` (adb) — nếu để chung dải, Pi có 2 interface cùng subnet ⇒ nhập nhằng ARP/định tuyến (D-021). IP tĩnh, đổi IP thì sửa `APP_IP` + flash lại. Chẩn đoán: `W5500_LogDiag` (VERSIONR/PHY) + log SR-transition (kẹt `0x15` SYNSENT = không tới được đích) (xem [gateway_ecu.md](gateway_ecu.md) §4). ([system_topology.md](system_topology.md))
- Firewall blocking inbound TCP 5000 on the host.
- CRC8 mismatch on CAN → frame dropped, counted in `canDecodeDiag.crc_error` (check via Gateway UART / app `DebugActivity`).
- Sequence gaps (`seq_gap`) indicate CAN frame loss (AutoRetransmission is disabled by design).
