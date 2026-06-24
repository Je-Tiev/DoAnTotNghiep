# CAN Database

> **Last updated:** 2026-06-21
> DBC-style reference for the CAN bus. Producer = **Sensor ECU** (`STM32-1st/Core/Src/can_encode.c`). Consumer = **Gateway ECU** (`STM32-2nd/Core/Src/can_decode.c`). Bus: standard 11-bit IDs, **250 kbps**, AutoRetransmission **enabled**, AutoBusOff **enabled** (auto-recovery).

## Bus parameters
| Param | Value |
|-------|-------|
| Bitrate | 250 kbps (prescaler 9, BS1 13TQ, BS2 2TQ, SJW 1TQ) |
| ID type | Standard 11-bit (`CAN_ID_STD`) |
| CRC | CRC8, polynomial **0x07**, MSB-first, init 0x00 (`CRC8_Calculate`) |
| Sequence | 4-bit counter per frame, wraps 0→15 |

---

## Frame `0x100` — CONTROL (DLC 4)
**Producer:** Sensor `buttonTask` (on keypress) · **Consumer:** Gateway `decodeCAN`
**Purpose:** driver controls / lighting / gear / mode.

| Byte | Bits | Field |
|------|------|-------|
| 0 | 0 | turnL |
| 0 | 1 | turnR |
| 0 | 2 | hazard |
| 0 | 3 | highBeam |
| 0 | 4 | lowBeam |
| 0 | 5 | door |
| 0 | 6 | seatbelt |
| 0 | 7 | heat |
| 1 | 0–1 | gear (0=P,1=R,2=N,3=D) |
| 1 | 2–3 | mode (0=ECO,1=SPORT,2=COMFORT,3=NORMAL) |
| 1 | 4 | steer |
| 1 | 5 | wind |
| 2 | 0–3 | sequence (low nibble) |
| 3 | — | CRC8 over bytes 0–2 |

**Validation (gateway):** DLC ≥ 4, CRC8(b0..b2)==b3, sequence gap/duplicate tracking.

---

## Frame `0x200` — SENSOR (DLC 8)
**Producer:** Sensor `ADCTask` @ 10 Hz · **Consumer:** Gateway `decodeCAN`
**Purpose:** analog gauges (speed/fuel/rpm). **16-bit values are big-endian.**

| Byte | Field |
|------|-------|
| 0 | speed MSB |
| 1 | speed LSB |
| 2 | fuel MSB |
| 3 | fuel LSB |
| 4 | rpm MSB |
| 5 | rpm LSB |
| 6 | sequence (high nibble, bits 4–7) |
| 7 | CRC8 over bytes 0–6 |

**Validation (gateway):** DLC ≥ 8, CRC8(b0..b6)==b7, sequence tracking.

---

## Ownership rules
- Only the **Sensor ECU** writes these frames. The Gateway is **receive-only** on CAN (its `CAN_Send` exists for API symmetry but is unused in normal operation).
- Any new signal → add to `can_encode.c` **and** `can_decode.c`, then update this file and [vehicle_state.md](vehicle_state.md).
- The frame→struct→TCP mapping continues in [integration.md](integration.md).
