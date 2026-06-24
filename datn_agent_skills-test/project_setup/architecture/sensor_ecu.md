# Sensor ECU — STM32-1st (`STM32_Sensor_CAN`)

> **Last updated:** 2026-06-21 (ADC sampling time + stack sizes updated)
> **Role: SOURCE OF TRUTH for vehicle state.** Reads inputs, owns `ControlData_t` / `SensorData_t`, encodes and transmits CAN. It must NOT receive vehicle state from anyone.

## 1. Hardware

- MCU: **STM32F103C8Tx** (`STM32F103C8TX_FLASH.ld`), STM32CubeIDE project `STM32_Sensor_CAN.ioc`.
- CAN1: PA11 (RX) / PA12 (TX) → MCP2551 transceiver, 250 kbps.
- Inputs: 4×3 matrix keypad, 3× potentiometer (ADC via DMA).
- Outputs: 8 status LEDs via 74HC595 shift register (SPI).
- Debug: USART1 @ 115200 with a small command parser.

## 2. FreeRTOS tasks (`Core/Src/freertos.c`)

| Task | Priority | Stack | Period | Responsibility |
|------|----------|-------|--------|----------------|
| `buttonTaskEntry` | Low | 256×4 | ~20 ms (`osDelay(20)`) | Scan keypad, toggle `g_ctrl_data`, compute warnings, drive LEDs, encode `0x100` on keypress |
| `StartADCTask` | BelowNormal | 256×4 | 100 ms (10 Hz) | Copy `adcBuffer[0..2]`→`g_sensor_data`, encode `0x200`, enqueue |
| `StartCANTask` | High | 256×4 | event (blocks on queue) | Dequeue `CAN_Message_t`, `CAN_Send()` (HAL_CAN_AddTxMessage) |
| `StartDefaultTask` | Normal | 256×4 | event | UART command parser: `PING`/`GET_STATUS`/`CLR_WARN`/`SET_GEAR:n` |

- **Shared queue** `sensorQueue` (16 × `CAN_Message_t`): producers = `ADCTask` (0x200) and `buttonTask` (0x100); consumer = `CANTask`. This serializes all CAN TX through one task.
- `blinkTimer` (periodic 20 ms) toggles `blink_state` every 25 ticks → ~500 ms blink cadence for turn signals/LEDs.
- `uartMutex` guards UART TX between `defaultTask` and debug logging.

## 3. Inputs

### Keypad (`Core/Src/keypad.c`, mapping in `freertos.c::process_keypad_input`)
Each key **toggles** a field in `g_ctrl_data` (with interlocks):

| Key | Action | Interlock |
|-----|--------|-----------|
| `1` | turnL | clears turnR, hazard |
| `2` | hazard | clears turnL, turnR |
| `3` | turnR | clears turnL, hazard |
| `4` | highBeam | clears lowBeam |
| `5` | gear (cycle P→R→N→D, `%4`) | — |
| `6` | lowBeam | clears highBeam |
| `7` | seatbelt | — |
| `8` | mode (cycle, `%4`) | — |
| `9` | door | — |
| `*` | heat | — |
| `0` | steer | — |
| `#` | wind | — |

### ADC (`Core/Src/adc.c`)
3 potentiometers read by DMA into `adcBuffer[3]` → mapped: `[0]=speed`, `[1]=fuel`, `[2]=rpm` (raw 0–4095/0–65535 range; passed through unchanged into `SensorData_t`). Sampling time: `ADC_SAMPLETIME_239CYCLES_5` (≈21 µs/kênh @ 12 MHz) — cần thiết để tránh charge-bleed giữa các kênh với biến trở trở kháng cao (xem [D-015](DECISIONS.md)).

### Warnings (computed locally, level-based, in `buttonTask`)
- `g_warnings.fuel_low = fuel < THRESHOLD_FUEL_LOW (500)`
- `g_warnings.engine_warning = rpm > THRESHOLD_RPM_HIGH (3500)`
- (These drive the local LED bitmap; the cluster derives its own warnings separately — see [android_app.md](android_app.md).)

## 4. CAN encoding (`Core/Src/can_encode.c`)

- `CAN_Encode_Control(msg, &g_ctrl_data)` → **ID 0x100, DLC 4** (byte0 bit-flags, byte1 gear/mode/steer/wind, byte2 seq low-nibble, byte3 CRC8).
- `CAN_Encode_Sensor(msg, &g_sensor_data)` → **ID 0x200, DLC 8** (bytes0–5 speed/fuel/rpm **big-endian**, byte6 seq high-nibble, byte7 CRC8 over bytes0–6).
- CRC8 polynomial **0x07**, separate sequence counters per frame (`seq_control`, `seq_sensor`, 4-bit wrap).
- Full byte layout: [can_database.md](can_database.md).

## 5. Key files

| File | Purpose |
|------|---------|
| `Core/Src/freertos.c` | Tasks, queue, keypad mapping, warnings |
| `Core/Src/can_encode.c` / `Core/Inc/can_encode.h` | Frame packing + CRC8 |
| `Core/Src/can.c` | CAN1 init + `CAN_Send` |
| `Core/Src/keypad.c` / `Core/Inc/keypad.h` | Matrix scan |
| `Core/Src/adc.c` | DMA ADC sampling |
| `Core/Src/hc595.c`, `light_manager.c` | LED bitmap output |
| `Core/Inc/can_msg.h` | `ControlData_t`, `SensorData_t` ([vehicle_state.md](vehicle_state.md)) |
| `STM32_Sensor_CAN.ioc` | CubeMX hardware config |
