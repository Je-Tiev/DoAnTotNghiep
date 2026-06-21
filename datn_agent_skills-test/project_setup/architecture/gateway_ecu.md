# Gateway ECU — STM32-2nd (`STM32_Gateway_CAN`)

> **Last updated:** 2026-06-22 (W5500 include path fix in .cproject)
> **Role: PROTOCOL TRANSLATOR ONLY.** Receives CAN, reconstructs `VehicleState_t`, forwards it over TCP. It must NOT originate or modify vehicle logic — it only re-frames data.

## 1. Hardware

- MCU: **STM32F103C8Tx**, STM32CubeIDE project `STM32_Gateway_CAN.ioc`.
- CAN1: PA11 (RX) / PA12 (TX) → MCP2551, 250 kbps (RX is the active direction).
- W5500 Ethernet over **SPI1**, chip-select **PB12**; WIZnet ioLibrary (`socket.h`, `wizchip_conf.h`).
  > **Build note (.cproject):** hai path `../Drivers/Ethernet_W5500` và `../Drivers/Ethernet_W5500/W5500` phải có trong **C Compiler + Assembler include paths** của cả Debug và Release — thiếu thì clean build fail với `wizchip_conf.h: No such file`.
- Debug: **USART1** (PA9 TX / PA10 RX, 115200 8N1) — debug log chiều RX qua `debug_uart.c` (`Debug_Printf`/`DEBUG_LOG`, gated `DEBUG_ENABLE`).

## 2. FreeRTOS tasks (`Core/Src/freertos.c`)

| Task | Priority | Stack | Responsibility |
|------|----------|-------|----------------|
| `Eth_SendTask_Entry` | Normal | 512×4 | Drain `canToEthQueue` → validate → `decodeCAN` accumulate → ensure socket → send 18-byte struct |
| `StartDefaultTask` | Normal | 128×4 | Idle (`osDelay(1)`) |

- **Queue** `canToEthQueue` (16 × `CAN_Message_t`): filled by the CAN RX FIFO0 interrupt (`USB_LP_CAN1_RX0_IRQn`, NVIC prio 5, see `Core/Src/can.c`); drained by `Eth_SendTask`.
- **Heap:** `configTOTAL_HEAP_SIZE = 8196` (`FreeRTOSConfig.h`). Must hold all task stacks (Eth_SendTask 2 KB + timer 1 KB + idle + TCBs + newlib reentrant) — the earlier 3072 was too small, so `osThreadNew(Eth_SendTask)` failed silently and the scheduler never ran (no `[BOOT]` log, yet CAN still ACK'd because `HAL_CAN_Start` runs pre-scheduler). `configUSE_MALLOC_FAILED_HOOK=1` + `vApplicationMallocFailedHook` now make heap exhaustion loud. Linked RAM ≈14.4/20 KB.

## 3. Receive + decode pipeline

1. `osMessageQueueGet(canToEthQueue)` → raw `CAN_Message_t`.
2. `CAN_ValidateFrame()` (`can.c`): ID ≤ 0x7FF, DLC ≤ 8 → else `rx_error++`.
3. `decodeCAN(msg, &state)` (`can_decode.c`):
   - **0x100**: DLC ≥ 4, CRC8 over bytes 0–2 == byte 3, unpack control bits into `state.control`, track control sequence.
   - **0x200**: DLC ≥ 8, CRC8 over bytes 0–6 == byte 7, unpack big-endian speed/fuel/rpm into `state.sensor`, track sensor sequence.
   - Diagnostics in `canDecodeDiag` (`decode_ok`, `crc_error`, `seq_gap`, `seq_duplicate`).
4. **Hybrid accumulation:** a single persistent `VehicleState_t state` keeps the latest control AND latest sensor; any valid frame triggers a send of the *full* snapshot.
5. **UART debug log** (in `Eth_SendTask`, task context only — never in the RX ISR): `[CAN RX] 0x200 spd/fuel/rpm` (rate-limited ~1 Hz), `[CAN RX] 0x100 gear/mode/turn` per control frame, `[DIAG] rx/ok/err + crc/gap/dup` every ~50 frames, and `[CAN RX] DECODE FAIL` / `[ETH]` on errors (rate-limited).

## 4. W5500 TCP client (`Core/Src/w5500_port.c`, `Core/Inc/w5500_config.h`)

- `W5500_Init()`: registers SPI/CS callbacks, `wizchip_init`, static net info (IP `192.168.1.50`, MAC `00:08:DC:...`, GW/SN, `NETINFO_STATIC`).
- `W5500_EnsureSocket()` — non-blocking TCP-client state machine on socket 0:

| `getSn_SR` status | Action | Returns |
|-------------------|--------|---------|
| `SOCK_ESTABLISHED` | ready | 1 |
| `SOCK_CLOSED` | `socket(0, TCP, local_port++)` (50000–60000) | 0 |
| `SOCK_INIT` | `connect(0, APP_IP, APP_PORT)` → `192.168.1.100:5000` | 0 |
| `SOCK_CLOSE_WAIT` | `disconnect(0)` | 0 |

- `W5500_SendData(buf, len)` → `send(SOCKET_ID, ...)`.
- In `Eth_SendTask`: `memcpy(buffer, &state, sizeof(VehicleState_t))` → `W5500_SendData(buffer, 18)`. After **5 consecutive send failures**, `close(SOCKET_ID)` forces a clean reopen.

## 5. Wire payload

`sizeof(VehicleState_t)` = **18 bytes** = `ControlData_t` (12 × uint8) + `SensorData_t` (3 × uint16). The struct is memcpy'd raw (native **little-endian**) — no framing, no CRC at the Ethernet layer (TCP guarantees ordering/integrity). Byte map: [vehicle_state.md](vehicle_state.md) / [integration.md](integration.md).

## 6. Key files

| File | Purpose |
|------|---------|
| `Core/Src/freertos.c` | `Eth_SendTask`, queue, send loop |
| `Core/Src/can_decode.c` / `Core/Inc/can_decode.h` | Frame validation, CRC8, decode, diagnostics |
| `Core/Src/can.c` | CAN init, RX IRQ → queue, `CAN_ValidateFrame` |
| `Core/Src/w5500_port.c` / `Core/Inc/w5500_port.h` | W5500 SPI driver + socket state machine |
| `Core/Inc/w5500_config.h` | IP/MAC/port/socket config |
| `Core/Inc/can_msg.h` | `ControlData_t`, `SensorData_t`, `VehicleState_t` |
| `STM32_Gateway_CAN.ioc` | CubeMX hardware config |
