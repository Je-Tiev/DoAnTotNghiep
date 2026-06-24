# Vehicle State Model

> **Last updated:** 2026-06-22 (Android scale: chia full-scale ADC 12-bit = 4095, không phải 65535)
> Every vehicle-state field, traced from producer to consumer. Structs: `STM32-1st/Core/Inc/can_msg.h`, `STM32-2nd/Core/Inc/can_msg.h` (identical), `ClusterApp/.../model/VehicleState.java`.

## 1. Structures

```c
// ControlData_t — 12 bytes (all uint8_t)
turnL, turnR, hazard, highBeam, lowBeam, door, seatbelt,   // bytes 0..6
gear, mode, heat, steer, wind                              // bytes 7..11

// SensorData_t — 6 bytes
uint16_t speed, fuel, rpm                                  // bytes 12..17 (LE in struct)

// VehicleState_t = { ControlData_t control; SensorData_t sensor; }  → 18 bytes total
```

The Gateway memcpy's `VehicleState_t` directly to the wire, so **TCP byte offset == struct offset** (no padding: 12 uint8 then uint16 at the aligned offset 12).

## 2. Field trace table

| TCP byte | Struct field | Producer (CAN) | Gateway field | Android field | Consumer / use |
|----------|--------------|----------------|---------------|---------------|----------------|
| 0 | control.turnL | 0x100 b0 bit0 | `state.control.turnL` | `leftTurnOn` (∥hazard) | turn-signal icon |
| 1 | control.turnR | 0x100 b0 bit1 | turnR | `rightTurnOn` (∥hazard) | turn-signal icon |
| 2 | control.hazard | 0x100 b0 bit2 | hazard | `hazardOn` | hazard, forces both turns |
| 3 | control.highBeam | 0x100 b0 bit3 | highBeam | `highBeamOn` | beam icon |
| 4 | control.lowBeam | 0x100 b0 bit4 | lowBeam | `lowBeamOn` | beam icon |
| 5 | control.door | 0x100 b0 bit5 | door | `doorOpenOn` | door warning |
| 6 | control.seatbelt | 0x100 b0 bit6 | seatbelt | `seatBeltOn` | seatbelt warning |
| 7 | control.gear | 0x100 b1 bits0-1 | gear | `gear` (P/R/N/D) | gear label |
| 8 | control.mode | 0x100 b1 bits2-3 | mode | `driveMode` (ECO/SPORT/COMFORT/NORMAL) | mode label/color |
| 9 | control.heat | 0x100 b0 bit7 | heat | `defrostOn` | defrost icon |
| 10 | control.steer | 0x100 b1 bit4 | steer | `steerOn` | comfort icon |
| 11 | control.wind | 0x100 b1 bit5 | wind | `windOn` | comfort icon |
| 12–13 | sensor.speed | 0x200 b0-1 (BE) | speed (u16) | `speedKph` = `/4095*240` | speed gauge |
| 14–15 | sensor.fuel | 0x200 b2-3 (BE) | fuel (u16) | `fuelLevel` = `/4095` | fuel gauge, `fuelLowOn<0.15` |
| 16–17 | sensor.rpm | 0x200 b4-5 (BE) | rpm (u16) | `rpmValue` = `/4095*8000` | rpm gauge |

> **Scale full-range (D-023):** Sensor ECU (`freertos.c::StartADCTask`) nạp THẲNG giá trị ADC 12-bit `adcBuffer[]` (0..4095) vào `SensorData_t` rồi gửi nguyên qua CAN/TCP — KHÔNG scale lên 16-bit. Vì vậy Android phải chia full-scale **4095**, không phải 65535; chia 65535 chỉ dùng 1/16 dải (max biến trở ≈ 15 km/h). Constant `ClusterController.ADC_FULL_SCALE`.

## 3. Fields that are NOT on the wire (consumer-only)

These exist only in `VehicleState.java` and are **derived in the app**, never produced by firmware:
`breakOn`, `engineCheckOn`, `oilPressureOn`, `temperatureOn` (see [android_app.md](android_app.md) §3), plus `odoKm`/`tripKm`/`seatOn` (UI bookkeeping).

> Note: the Sensor ECU computes its own `g_warnings.fuel_low` / `engine_warning` for **local LEDs only** (`THRESHOLD_FUEL_LOW=500`, `THRESHOLD_RPM_HIGH=3500`). These are not transmitted; the cluster's warnings are independent.

## 4. Endianness summary (important)

- CAN `0x200` carries speed/fuel/rpm **big-endian**.
- Gateway `decodeCAN` reconstructs them to native `uint16` (`data[0]<<8 | data[1]`).
- The struct is memcpy'd to TCP as native **little-endian**, and Android reads little-endian.
- Net effect: values are preserved end-to-end. Do **not** "fix" either side — they are paired. Full path in [integration.md](integration.md).
