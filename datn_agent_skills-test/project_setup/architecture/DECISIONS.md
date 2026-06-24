# Architecture Decisions (ADR)

> **Last updated:** 2026-06-22 (D-022 added)
> Decisions reverse-engineered from the source. Each: **decision → rationale → evidence**. Read this with [overview.md](overview.md) + [PROJECT_MAP.md](PROJECT_MAP.md) to understand *why* the system is shaped this way — then you can modify safely without re-deriving intent.

## Layering rules (binding)
> Sensor ECU = **source of truth** · Gateway ECU = **protocol translator** · Raspberry Pi = **host** · Android = **visualization**. Never move a responsibility between layers; if a change seems to require it, stop and reconsider.

---

### D-001 — Three-tier split (Sensor / Gateway / Display)
- **Decision:** Separate input acquisition, protocol bridging, and visualization into distinct nodes.
- **Rationale:** Mirrors a real automotive ECU/gateway/head-unit topology (the project's whole point) and keeps each unit single-responsibility and independently testable.
- **Evidence:** three submodules with no overlapping logic (`STM32-1st`, `STM32-2nd`, `ClusterApp`).

### D-002 — Sensor ECU owns vehicle state
- **Decision:** Only `STM32-1st` reads inputs and holds `ControlData_t`/`SensorData_t`.
- **Rationale:** A single writer = no state-merge conflicts; downstream nodes can stay stateless relays/renderers.
- **Evidence:** `freertos.c` `g_ctrl_data`/`g_sensor_data`; gateway and app never originate values.

### D-003 — Gateway translates only (no vehicle logic)
- **Decision:** `STM32-2nd` validates/decodes CAN and re-frames to TCP; it adds no behavior.
- **Rationale:** Keeps the bridge thin and deterministic; business logic stays where the state lives.
- **Evidence:** `Eth_SendTask_Entry` is decode→send; `CAN_Send` is an unused stub ("Gateway is RX only").

### D-004 — CAN as the field bus (250 kbps, standard IDs)
- **Decision:** Use CAN between Sensor and Gateway.
- **Rationale:** Automotive-standard, robust on noisy/short links, native arbitration; matches thesis scope.
- **Evidence:** `can.c` `MX_CAN_Init` (prescaler 9 → 250 kbps), MCP2551 transceiver.

### D-005 — Dual CAN frames (0x100 control + 0x200 sensor)
- **Decision:** Split control (event-ish) from analog sensors (periodic) into two IDs.
- **Rationale:** Different update rates/semantics; control sent on keypress, sensors at fixed 10 Hz; smaller frames, independent sequence/CRC.
- **Evidence:** `can_encode.c` `CAN_Encode_Control`/`CAN_Encode_Sensor`.

### D-006 — CRC8 + per-frame 4-bit sequence
- **Decision:** App-layer CRC8 (poly 0x07) and a wrapping sequence nibble on each frame.
- **Rationale:** Detect corruption and frame loss/duplication on CAN at the application layer (independent of the bxCAN error counters). See D-016 for the TX reliability config.
- **Evidence:** `can_encode.c` CRC bytes; `can_decode.c` `crc_error`/`seq_gap`/`seq_duplicate` diagnostics.

### D-007 — Big-endian 16-bit sensor values on CAN
- **Decision:** speed/fuel/rpm sent MSB-first in `0x200`.
- **Rationale:** Network/automotive byte order; eases DBC tooling and cross-platform debugging (noted in `can_decode.c`).
- **Evidence:** `can_encode.c` `data[0]=speed>>8`; `can_decode.c` `speed = data[0]<<8 | data[1]`. (Pairs with D-010.)

### D-008 — Hybrid accumulated `VehicleState_t` at the gateway
- **Decision:** Keep one persistent struct combining latest control + latest sensor; send the full snapshot on every valid frame.
- **Rationale:** The app always receives a complete, consistent state and never has to merge partial updates.
- **Evidence:** `freertos.c` persistent `VehicleState_t state`; `can_decode.c` accumulation comment block.

### D-009 — W5500 + TCP for the uplink
- **Decision:** Hardware TCP/IP offload (W5500 over SPI) instead of UDP or a software stack.
- **Rationale:** Reliable ordered delivery for free, tiny MCU footprint (no lwIP), simple `socket/connect/send` API.
- **Evidence:** `w5500_port.c`, WIZnet ioLibrary; `SOCKET_MODE Sn_MR_TCP`.

### D-010 — Raw 18-byte struct over TCP (no framing/CRC16)
- **Decision:** `memcpy` `VehicleState_t` and `send()` it; the app `readFully(18)`.
- **Rationale:** TCP already guarantees order + integrity, so sync bytes/length/CRC16 are redundant; fixed size makes parsing trivial.
- **Evidence:** `freertos.c` `memcpy(buffer,&state,18)`; `GatewayClient.java` `PACKET_SIZE=18`. *(Supersedes the older 16-byte framed-packet spec in TECHNICAL_SPECS.md.)*

### D-011 — Android app is the TCP **server**; Gateway is the client
- **Decision:** App opens `ServerSocket :5000`; the W5500 connects out to it.
- **Rationale:** The head unit is the stable, long-lived listener; the embedded node initiates and auto-reconnects, simplifying NAT/IP handling on the MCU side.
- **Evidence:** `GatewayClient.java` `ServerSocket`; `w5500_port.c` `connect(APP_IP, APP_PORT)`.

### D-012 — Raspberry Pi is host-only (no separate server process)
- **Decision:** State distribution lives inside the Android app; the RPi just runs it.
- **Rationale:** Avoids a redundant broker tier for a single-display setup; fewer moving parts.
- **Evidence:** no RPi server code in repo; `GatewayClient`/`ClusterController` hold the server + latest state. (Revisit if multi-client distribution is needed — [raspberry_pi.md](raspberry_pi.md).)

### D-013 — Display-derived warnings computed in the app
- **Decision:** engine-check/brake/oil/temperature are inferred in `ClusterController`, not sent by firmware.
- **Rationale:** Keeps the wire payload minimal and lets UX tune thresholds without firmware changes.
- **Evidence:** `ClusterController.applyDerivedWarnings`; these fields are app-only ([vehicle_state.md](vehicle_state.md) §3).

### D-014 — Single TX task fed by a queue (Sensor ECU)
- **Decision:** `ADCTask` and `buttonTask` enqueue into one `sensorQueue`; only `CANTask` transmits.
- **Rationale:** Serializes bus access, avoids concurrent `HAL_CAN_AddTxMessage`, decouples producers from TX timing.
- **Evidence:** `freertos.c` `sensorQueueHandle`, `StartCANTask`.

### D-015 — ADC sampling time 239.5 cycles cho 3 kênh potentiometer
- **Decision:** Dùng `ADC_SAMPLETIME_239CYCLES_5` (max) thay vì 55.5 cycles cho cả 3 kênh ADC1 (IN0/IN1/IN2).
- **Rationale:** Biến trở có thể có trở kháng nguồn cao (50k–100k Ω); tụ sample/hold của ADC F103 cần đủ thời gian nạp giữa các kênh trong scan mode — với 55.5 cycles bị charge-bleed, kênh sau "ăn" giá trị kênh trước. UART log không phải nguyên nhân (TX polling không tương tác với DMA hardware).
- **Evidence:** `adc.c` `sConfig.SamplingTime = ADC_SAMPLETIME_239CYCLES_5`; `.ioc` `SamplingTime-0/1/2 = ADC_SAMPLETIME_239CYCLES_5`. Ở ADCCLK=12 MHz: ~21 µs/kênh × 3 ≈ 63 µs/vòng — dư sức cho chu kỳ 10 Hz.

### D-016 — Bật AutoBusOff + AutoRetransmission cho link CAN 2 node
- **Decision:** `MX_CAN_Init` ở cả hai node đặt `AutoBusOff = ENABLE` và `AutoRetransmission = ENABLE` (trước đây cả hai DISABLE / one-shot). Thêm công tắc compile-time `CAN_BENCH_LOOPBACK` ở Sensor để test riêng (LOOPBACK self-ACK) vs chạy thật (NORMAL).
- **Rationale:** One-shot + AutoBusOff disabled khiến node vào bus-off vĩnh viễn khi thiếu ACK (mailbox TX kẹt → `tx_total` đóng băng, log "treo ở 19"). Đây là link telemetry 2 node tin cậy, không phải bus time-triggered, nên retry + tự phục hồi là đúng. Cũng sửa `CAN_Send` (Sensor) để tăng `tx_failure` khi `AddTxMessage` lỗi (trước đây luôn báo Failures:0 giả tạo).
- **Evidence:** `STM32-1st/Core/Src/can.c` (`CAN_BENCH_LOOPBACK`, `AutoBusOff/AutoRetransmission = ENABLE`, `tx_failure++`); `STM32-2nd/Core/Src/can.c` (`AutoBusOff/AutoRetransmission = ENABLE`, NORMAL). Pairs với D-006 (CRC/seq vẫn giữ cho phát hiện mất frame).

### D-017 — Gateway CubeIDE project = single source of truth (mở thẳng thư mục repo)
- **Decision:** Project `STM32_Gateway_CAN` mở trong STM32CubeIDE phải là chính thư mục submodule repo `STM32-2nd`, KHÔNG dùng bản copy ở workspace riêng. Mọi thay đổi build config (include path, symbol) sửa trong project mà IDE thật sự build, qua GUI Paths and Symbols.
- **Rationale:** Khi IDE build một bản copy tách rời, sửa `.cproject` trong repo không tới được file IDE đọc → triệu chứng "fix include W5500 mà build vẫn fail `socket.h/wizchip_conf.h/w5500.h: No such file`, kể cả sau restart". Hai bản drift là nguồn nhầm lẫn lặp lại; một bản single-source do git theo dõi loại bỏ gốc rễ.
- **Evidence:** repo `STM32-2nd/.cproject` đã có `../Drivers/Ethernet_W5500` + `../Drivers/Ethernet_W5500/W5500` (Debug+Release) nhưng build copy vẫn thiếu `-I`; xác nhận với user là CubeIDE mở bản copy ở workspace khác. Xem build note [gateway_ecu.md](gateway_ecu.md) §1.

### D-018 — Gateway TCP socket non-blocking (SF_IO_NONBLOCK) + diagnostic log
- **Decision:** Mở socket W5500 với `SF_IO_NONBLOCK` (trước là flag `0` = blocking); thêm `W5500_LogDiag()` (VERSIONR + PHY link, gọi 1 lần đầu `Eth_SendTask`) và log socket-SR chỉ khi đổi trạng thái + `connect()` ret.
- **Rationale:** Với blocking, `connect()` (socket.c) loop tới ESTABLISHED/timeout — khi App chưa sẵn sàng nó **chặn `Eth_SendTask`**, `canToEthQueue` (16) tràn ở ISR → mất frame CAN. Non-block: `connect()` trả `SOCK_BUSY` ngay, SR tự tiến, task vẫn drain queue; gặp timeout thì chip tự đóng → reopen (tự phục hồi). Log chẩn đoán thay thế spam `socket not ready` vô nghĩa: phân biệt SPI chết (VERSIONR≠0x04) / link down (PHY OFF) / sai APP_IP (kẹt SYNSENT→timeout). Phải log trong task context vì `Debug_Printf` cần `uartMutex` (chưa tồn tại khi `W5500_Init` chạy trước scheduler).
- **Evidence:** `STM32-2nd/Core/Src/w5500_port.c` (`socket(..., SF_IO_NONBLOCK)`, `W5500_LogDiag`, `last_status` transition log); `freertos.c` gọi `W5500_LogDiag()` đầu `Eth_SendTask`. Triệu chứng gốc: log `[ETH] socket not ready, drop frame` do `APP_IP` sai (đã sửa `192.168.1.100`→`192.168.1.104`). Pairs D-009/D-011.

### D-019 — ClusterApp scale gauge bằng code + server start sớm (thay vì resource qualifier / trễ splash)
- **Decision:** Bỏ kích thước dp cố định của 3 gauge; `ClusterActivity.scaleGauges()` set `LayoutParams` theo px thật của `gaugeContainer` trong `OnGlobalLayoutListener` (`base=min(H,0.42·W)`, side`=0.9·base`, overlap`=0.19·side`) + bật immersive fullscreen. `gatewayClient.start()` chuyển vào `onCreate` (bỏ `postDelayed 3500ms`).
- **Rationale:** UI thiết kế cho emulator (260/290dp) hiển thị nhỏ/lệch trên màn Pi độ phân giải khác. Scale runtime đơn giản hơn nuôi nhiều `values-*/layout-*` qualifier và đúng cho mọi màn vì GaugeView.onDraw đã vẽ theo `getWidth/Height`. Start server trễ 3.5s + chỉ khi foreground làm :5000 mở muộn/không mở → W5500 báo `socket not ready`; start sớm loại biến số này (serverLoop tự bind + accept-retry 2s, an toàn). Không phá tầng — App vẫn là TCP server, RPi vẫn host-only.
- **Evidence:** `ClusterApp/.../ui/ClusterActivity.java` (`scaleGauges`, `enableImmersive`, `onWindowFocusChanged`, `gatewayClient.start()` trong `onCreate`); `network/GatewayClient.java` (tách log bind vs accept). Pairs D-011 (vai trò server), [android_app.md](android_app.md) §5.

### D-020 — TCP server thuộc SocketService; GatewayClient = singleton phạm vi tiến trình
- **Decision:** `GatewayClient` thành singleton (`GatewayClient.get()`, ctor private) tự sở hữu 1 `ClusterController`. Vòng đời server (`start`/`stop`) chuyển từ `ClusterActivity` sang `SocketService` (`onStartCommand`→`start()`, `onDestroy`→`stop()`). `ClusterActivity.onCreate` chỉ `startForegroundService(SocketService)` rồi render từ `GatewayClient.get().getController()`; bỏ `gatewayClient.init()`/no-op keep-alive `socketLoop`.
- **Rationale:** Activity sở hữu server khiến mỗi lần tái tạo Activity (đổi cấu hình / restore) lại gọi `start()` trên instance mới → serverLoop thứ hai cùng `bind(:5000)` trong khi instance cũ chưa nhả → `EADDRINUSE` (thấy ở `adb logcat -s GatewayClient`). Đưa bind vào 1 singleton do foreground service (`START_STICKY` + watchdog + boot) quản lý ⇒ cổng bind đúng MỘT lần cho cả tiến trình, độc lập vòng đời UI; bền bỉ hơn và đúng trách nhiệm lớp (network ở tầng service, Activity chỉ hiển thị). Không phá tầng: App vẫn là TCP server, RPi vẫn host-only.
- **Evidence:** `ClusterApp/.../network/GatewayClient.java` (`INSTANCE`/`get()`/`getController()`, ctor private, bỏ `init()`); `network/SocketService.java` (`GatewayClient.get().start()/stop()`, bỏ `socketLoop`/`workerThread`); `ui/ClusterActivity.java` (`startForegroundService`, `controller = GatewayClient.get().getController()`). Thay thế cách start ở D-019 (server start trong Activity). Pairs D-011 (vai trò server), [android_app.md](android_app.md) §2.

### D-021 — Link eth Pi↔Gateway dùng subnet riêng `192.168.10.0/24`, tách khỏi WiFi/adb
- **Decision:** Đường Ethernet điểm-điểm giữa W5500 và eth0 của Pi chạy trên subnet riêng `192.168.10.0/24` (`W5500_IP=192.168.10.50`, `APP_IP` = eth0 Pi `192.168.10.104`), KHÔNG dùng chung dải `192.168.1.x` của WiFi nhà (WiFi dành cho adb/logcat).
- **Rationale:** Khi cắm W5500 thẳng vào eth0, gói TCP đi qua eth0 — nhưng IP `192.168.1.104` từng "khớp" lại là IP của **wlan0**, không phải eth0 → W5500 kẹt `SOCK_SYNSENT`, log `socket not ready, drop frame`. Đặt eth0 cùng dải `192.168.1.x` với WiFi thì Pi có 2 interface cùng subnet ⇒ nhập nhằng ARP/định tuyến. Subnet riêng cho link trực tiếp loại bỏ cả hai vấn đề mà vẫn giữ WiFi cho adb. App lắng nghe `0.0.0.0:5000` nên accept trên eth0 không cần đổi gì.
- **Evidence:** `STM32-2nd/Core/Inc/w5500_config.h` (`W5500_IP`/`W5500_GATEWAY`/`APP_IP` → `192.168.10.x`); Pi eth0 đặt static `192.168.10.104/24`; `ClusterApp/.../network/GatewayClient.java` `bind(InetSocketAddress(LISTEN_PORT))` = wildcard. Pairs D-009/D-011; failure mode #1 [integration.md](integration.md) §5.

### D-022 — Bật CAN RX trong `Eth_SendTask`, KHÔNG ở `main()` trước scheduler
- **Decision:** `HAL_CAN_Start` + `HAL_CAN_ActivateNotification` gọi ở đầu `Eth_SendTask` (sau khi `MX_FREERTOS_Init` tạo `canToEthQueue`), không gọi trong `main()` trước `osKernelStart`. Callback `HAL_CAN_RxFifo0MsgPendingCallback` còn guard `canToEthQueueHandle != NULL`. Filter config vẫn ở `main()`.
- **Rationale:** Bật ngắt RX sớm trong `main()` → frame CAN từ node Sensor có thể tới **trong lúc `W5500_Init()` (`wizchip_sw_reset`) đang chạy** → ISR gọi `xQueueSendFromISR` vào queue còn NULL → `configASSERT(pxQueue)` → MCU treo **trước cả khi in `[BOOT]`** (UART câm hoàn toàn). Bug ẩn khi dây SPI sai (sw_reset không tốn thời gian); **lộ ra sau khi sửa đúng dây W5500** vì cửa sổ thời gian dài hơn. Bật CAN sau khi queue tồn tại + scheduler chạy loại bỏ race; guard NULL là phòng vệ tầng 2.
- **Evidence:** `STM32-2nd/Core/Src/freertos.c` (`HAL_CAN_Start`/`ActivateNotification` đầu `Eth_SendTask_Entry`); `STM32-2nd/Core/Src/main.c` (CAN start gỡ khỏi `USER CODE 2`; callback guard `canToEthQueueHandle`). Chẩn đoán bằng debug call stack: `wizchip_init → ... → HAL_SPI_Transmit` bị `USB_LP_CAN1_RX0_IRQHandler → xQueueGenericSendFromISR → configASSERT` (pxQueue=0x0) chen vào.

### D-023 — Android chia full-scale ADC 12-bit (4095) + intro animation overlap→slide→sweep
- **Decision:** `ClusterController.applyGatewayPacket` chia full-scale **4095** (`ADC_FULL_SCALE`), không phải 65535, cho speed/fuel/rpm. Intro khởi động viết lại trong `AnimationManager.playIntro()`: 3 gauge fade-in chồng nhau ở tâm → trái/phải trượt ra vị trí cố định (`translationX/Y`, center đứng yên) → cả 3 kim quét `0→1→0` trong 2 s; `ClusterActivity.updateUi()` chỉ set kim live sau `introAnimDone`.
- **Rationale:** Sensor (`STM32-1st/freertos.c::StartADCTask`) nạp thẳng `adcBuffer[]` 12-bit (0..4095) vào `SensorData_t`, KHÔNG scale lên 16-bit; chia 65535 ở Android chỉ dùng 1/16 dải → max biến trở ≈ 15 km/h (fuel ≈ 6%, rpm ≈ 500). Sửa ở tầng Android (display) đúng trách nhiệm lớp, không đụng wire/CAN. Intro cũ (`AnimationManager` scatter math tĩnh theo `layoutW/H`) là dead-code chỉ fade; bản mới dùng vị trí view THẬT sau layout nên đúng mọi độ phân giải Pi; khóa `introAnimDone` tránh vòng 33ms ghi đè hiệu ứng quét kim.
- **Evidence:** `ClusterApp/.../controller/ClusterController.java` (`ADC_FULL_SCALE`); `ui/animation/AnimationManager.java` (`playIntro`); `ui/ClusterActivity.java` (`runIntroAnimation`, gate `introAnimDone` trong `updateUi`, `onDestroy→stop`). Thay phần parse `/65535` ở D-019/vehicle_state. Pairs [android_app.md](android_app.md) §3/§5.

---

## How to extend
When you make a non-obvious choice, append a new `D-0xx` entry here (decision → rationale → evidence) and bump the *Last updated* date. Keep entries to a few lines.
