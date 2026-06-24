---
name: can-protocol
description: Add or change CAN frames, signals, CRC8, or sequence handling between the Sensor and Gateway ECUs. Use whenever the CAN message layout (0x100/0x200) or its encode/decode changes.
---

# CAN Protocol

Own the CAN contract between `STM32-1st` (producer) and `STM32-2nd` (consumer).

## When to use this skill
- Adding a signal/field, a new CAN ID, or changing a byte layout.
- Touching CRC8, DLC, or sequence-counter logic.
- Debugging CRC/sequence errors (`canDecodeDiag`).

## How to use it
1. **Single source of the schema:** [`can_database.md`](../../../project_setup/architecture/can_database.md). Read it first.
2. **Edit encode and decode together** — they must stay symmetric:
   - Producer: `STM32-1st/Core/Src/can_encode.c` (`CAN_Encode_Control` 0x100, `CAN_Encode_Sensor` 0x200).
   - Consumer: `STM32-2nd/Core/Src/can_decode.c` (`decodeCAN`).
3. **Preserve invariants:** CRC8 poly `0x07` over all data bytes except the last; 4-bit sequence counter per frame; 16-bit sensor values **big-endian**; standard 11-bit IDs; 250 kbps.
4. **Keep `can_msg.h` identical** in both nodes (`ControlData_t`, `SensorData_t`, `VehicleState_t`).
5. **Mind the downstream:** a layout change ripples to the 18-byte TCP struct and the Android parser — update [`vehicle_state.md`](../../../project_setup/architecture/vehicle_state.md), [`integration.md`](../../../project_setup/architecture/integration.md), and `ClusterController.applyGatewayPacket`.
6. After any change, update `can_database.md` + `vehicle_state.md` and add a `DECISIONS.md` entry if the choice is non-obvious.
