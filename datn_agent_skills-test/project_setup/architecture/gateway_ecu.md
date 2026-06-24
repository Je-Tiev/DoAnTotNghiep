# Gateway ECU — STM32-2nd (`STM32_Gateway_CAN`)

> **Last updated:** 2026-06-22 (thêm `W5500_PhyLinkUp`/`W5500_LogPhyLive`: chờ PHY link UP rồi đo speed/duplex SỐNG trong `Eth_SendTask` + re-log định kỳ — `W5500_LogDiag` cũ chỉ chụp lúc boot khi link=OFF nên số đo rác; dùng phân biệt "nguồn 3.3V W5500 yếu/PHY chết" vs "lệch duplex với Pi". · D-022: bật CAN RX trong `Eth_SendTask` (sau khi queue tạo) để tránh treo `configASSERT` khi `xQueueSendFromISR` vào queue NULL; UART log fix: tách rate-limit eth/decode riêng + in ngay lỗi đầu đợt; thêm đường `DEBUG_FATAL`/`Debug_PrintfRaw` ghi UART trực tiếp không qua mutex cho log fatal/pre-scheduler)
> **Role: PROTOCOL TRANSLATOR ONLY.** Receives CAN, reconstructs `VehicleState_t`, forwards it over TCP. It must NOT originate or modify vehicle logic — it only re-frames data.

## 1. Hardware

- MCU: **STM32F103C8Tx**, STM32CubeIDE project `STM32_Gateway_CAN.ioc`.
- CAN1: PA11 (RX) / PA12 (TX) → MCP2551, 250 kbps (RX is the active direction).
- W5500 Ethernet over **SPI1**, chip-select **PB12**; WIZnet ioLibrary (`socket.h`, `wizchip_conf.h`).
  > **Build note:** Gateway cần 2 include path `Drivers/Ethernet_W5500` và `Drivers/Ethernet_W5500/W5500` (cả Debug + Release). Repo `STM32-2nd/.cproject` ĐÃ có sẵn 2 path này. Nếu vẫn fail `wizchip_conf.h / w5500.h / socket.h: No such file` → **nguyên nhân thật: CubeIDE mở một BẢN COPY của project ở workspace riêng, KHÔNG phải thư mục repo này** (xem [DECISIONS.md](DECISIONS.md) D-017). Sửa `.cproject` trong repo vô tác dụng vì IDE đọc file khác. Fix: thêm 2 include path qua **GUI Properties → C/C++ General → Paths and Symbols → Includes** (Configuration = All) **trong project mà CubeIDE thật sự build**, rồi Clean + Build. GUI cũng tránh mọi vấn đề cache. Kiểm chứng: `Debug/Drivers/Ethernet_W5500/subdir.mk` phải có `-I../Drivers/Ethernet_W5500` + `-I../Drivers/Ethernet_W5500/W5500`. Tốt nhất: mở thẳng thư mục repo trong CubeIDE để chỉ còn một bản single-source.
- Debug: **USART1** (PA9 TX / PA10 RX, 115200 8N1) — debug log chiều RX qua `debug_uart.c` (`Debug_Printf`/`DEBUG_LOG`, gated `DEBUG_ENABLE`). `DEBUG_LOG` lấy `uartMutex` (chỉ gọi từ task context). Đường fatal/pre-scheduler dùng `DEBUG_FATAL`/`Debug_PrintfRaw` ghi UART **trực tiếp, không mutex** (vì `[FATAL] Task creation failed` chạy trước scheduler và `vApplicationMallocFailedHook` chạy khi heap cạn — `osMutexAcquire` không đáng tin ở đó nên có thể nuốt mất thông điệp).

## 2. FreeRTOS tasks (`Core/Src/freertos.c`)

| Task | Priority | Stack | Responsibility |
|------|----------|-------|----------------|
| `Eth_SendTask_Entry` | Normal | 512×4 | Drain `canToEthQueue` → validate → `decodeCAN` accumulate → ensure socket → send 18-byte struct |
| `StartDefaultTask` | Normal | 128×4 | Idle (`osDelay(1)`) |

- **Queue** `canToEthQueue` (16 × `CAN_Message_t`): filled by the CAN RX FIFO0 interrupt (`USB_LP_CAN1_RX0_IRQn`, NVIC prio 5; callback `HAL_CAN_RxFifo0MsgPendingCallback` in `Core/Src/main.c`); drained by `Eth_SendTask`.
- **CAN RX bật MUỘN — thứ tự khởi tạo (D-022):** `HAL_CAN_Start` + `HAL_CAN_ActivateNotification` gọi ở **đầu `Eth_SendTask`** (sau `MX_FREERTOS_Init` tạo queue + scheduler chạy), KHÔNG ở `main()` trước scheduler. Bật sớm + dây SPI tốt → `W5500_Init()` (`wizchip_sw_reset`) chiếm thời gian, frame CAN chen vào kích ISR `xQueueSendFromISR(canToEthQueueHandle=NULL)` → `configASSERT` → MCU treo trước cả khi in `[BOOT]` (UART câm). Callback còn guard `canToEthQueueHandle != NULL` phòng vệ. Filter config vẫn ở `main()` (không sinh ngắt).
- **Heap:** `configTOTAL_HEAP_SIZE = 8196` (`FreeRTOSConfig.h`). Must hold all task stacks (Eth_SendTask 2 KB + timer 1 KB + idle + TCBs + newlib reentrant) — the earlier 3072 was too small, so `osThreadNew(Eth_SendTask)` failed silently and the scheduler never ran (no `[BOOT]` log; CAN now started inside the task per D-022, so no ACK before scheduler either). `configUSE_MALLOC_FAILED_HOOK=1` + `vApplicationMallocFailedHook` now make heap exhaustion loud. Linked RAM ≈14.4/20 KB.

## 3. Receive + decode pipeline

1. `osMessageQueueGet(canToEthQueue)` → raw `CAN_Message_t`.
2. `CAN_ValidateFrame()` (`can.c`): ID ≤ 0x7FF, DLC ≤ 8 → else `rx_error++`.
3. `decodeCAN(msg, &state)` (`can_decode.c`):
   - **0x100**: DLC ≥ 4, CRC8 over bytes 0–2 == byte 3, unpack control bits into `state.control`, track control sequence.
   - **0x200**: DLC ≥ 8, CRC8 over bytes 0–6 == byte 7, unpack big-endian speed/fuel/rpm into `state.sensor`, track sensor sequence.
   - Diagnostics in `canDecodeDiag` (`decode_ok`, `crc_error`, `seq_gap`, `seq_duplicate`).
4. **Hybrid accumulation:** a single persistent `VehicleState_t state` keeps the latest control AND latest sensor; any valid frame triggers a send of the *full* snapshot.
5. **UART debug log** (in `Eth_SendTask`, task context only — never in the RX ISR): `[CAN RX] 0x200 spd/fuel/rpm` (rate-limited ~1 Hz), `[CAN RX] 0x100 gear/mode/turn` per control frame, `[DIAG] rx/ok/err + crc/gap/dup` every ~50 frames, and `[CAN RX] DECODE FAIL` / `[ETH] socket not ready` on errors (rate-limited). Hai đường lỗi đếm RIÊNG (`eth_fail_cnt` vs `decode_fail_cnt`) để không che lấp nhau; mỗi bộ đếm in **ngay lỗi đầu đợt** (`cnt++ % 20 == 0`) rồi mỗi 20 frame, và reset khi đường đó trở lại bình thường (decode OK / socket sẵn sàng).

## 4. W5500 TCP client (`Core/Src/w5500_port.c`, `Core/Inc/w5500_config.h`)

- `W5500_Init()`: registers SPI/CS callbacks, `wizchip_init`, static net info (IP `192.168.10.50`, MAC `00:08:DC:...`, GW `192.168.10.1`/SN, `NETINFO_STATIC`). Subnet riêng `192.168.10.0/24` cho link eth trực tiếp, tách WiFi `192.168.1.x` (D-021).
- `W5500_EnsureSocket()` — non-blocking TCP-client state machine on socket 0:

| `getSn_SR` status | Action | Returns |
|-------------------|--------|---------|
| `SOCK_ESTABLISHED` | ready | 1 |
| `SOCK_CLOSED` | `socket(0, TCP, local_port++, SF_IO_NONBLOCK)` (50000–60000) | 0 |
| `SOCK_INIT` | `connect(0, APP_IP, APP_PORT)` → `192.168.10.104:5000` (eth0 Pi; non-block: returns `SOCK_BUSY`) | 0 |
| `SOCK_SYNSENT` | chờ handshake (không gọi lại `connect`) | 0 |
| `SOCK_CLOSE_WAIT` | `disconnect(0)` | 0 |

- **Non-blocking socket (SF_IO_NONBLOCK):** `connect()` trả `SOCK_BUSY` ngay, SR tự tiến `INIT→SYNSENT→ESTABLISHED`; nếu `Sn_IR_TIMEOUT` → chip tự đóng → `SOCK_CLOSED` → reopen. Mục đích: `connect()` KHÔNG block `Eth_SendTask` nên `canToEthQueue` không tràn khi App chưa sẵn sàng (xem [DECISIONS.md](DECISIONS.md) D-018). `APP_IP` **phải khớp IP của interface thật mang gói** = **eth0** của Pi (`192.168.10.104`), KHÔNG phải IP WiFi/wlan0; sai thì socket kẹt `SYNSENT` → `socket not ready` (nguyên nhân #1 — xem [integration.md](integration.md) §5).
- **Diagnostic log** (`W5500_LogDiag()`, gọi 1 lần đầu `Eth_SendTask`, task context vì `Debug_Printf` cần `uartMutex`): `[ETH] VERSIONR=0x04` (SPI/chip sống), `[ETH] PHY link=ON/OFF` + `PHY 10/100Mbps half/full-duplex` (cáp/auto-neg), `[ETH] wizchip_init OK/FAIL` (nếu FAIL → net info chưa ghi), và **readback từ thanh ghi chip** `IP/SUB/GW/MAC` + `dest` (APP_IP:APP_PORT). ⚠️ Số speed/duplex trong `W5500_LogDiag` chụp **lúc boot khi link còn OFF → là giá trị rác**; dùng `W5500_LogPhyLive()` để đọc SỐNG.
- **PHY live probe** (`W5500_PhyLinkUp()` / `W5500_LogPhyLive()`, `w5500_port.c`): `Eth_SendTask` **chờ PHY link UP tối đa ~3s** (`[ETH] PHY link wait = N ms`) rồi log `[ETH] PHY now: link=ON/OFF NMbps X-duplex` thật, và re-log mỗi ~200 frame. Đọc số liệu: vẫn `OFF` sau timeout ⇒ **module W5500 không lên link dù cáp/đối tác tốt → nghi nguồn 3.3V W5500 sụt dòng (PHY ~130 mA brownout trong khi SPI vẫn chạy) hoặc PHY hỏng**; `ON` nhưng `half` khi Pi `full` ⇒ **lệch duplex** → ép mode. (Triệu chứng kinh điển: SPI/VERSIONR/net readback đúng nhưng W5500 không trả lời ARP — `ip neigh` rỗng phía Pi — và `connect TIMEOUT`.) IP readback = `0.0.0.0` ⇒ chip không trả lời ARP/ICMP → đó là lý do `ping` fail (không phải lỗi cáp). `W5500_Init()` lưu `s_initRet` (chạy pre-scheduler nên không log tại chỗ). `W5500_EnsureSocket` log SR **chỉ khi đổi trạng thái** (kèm tên qua `sr_name()`), `connect -> dest:port ret`, `socket ESTABLISHED` (1 lần), và `connect TIMEOUT (no SYN-ACK)` khi `Sn_IR_TIMEOUT` → phân biệt link-down vs sai IP đích vs established.
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
