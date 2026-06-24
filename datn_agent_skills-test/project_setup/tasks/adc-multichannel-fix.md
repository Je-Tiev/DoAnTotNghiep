# Task: Fix ADC đa kênh (chỉ 1 kênh đúng) + làm sạch logging UART — Sensor ECU (STM32-1st)

> **Loại:** implementation handoff (viết cho AI/dev khác thực thi)
> **Phạm vi:** chỉ `STM32-1st/` (Sensor ECU). KHÔNG đổi CAN schema, Gateway, Android.
> **Trạng thái:** chưa implement.
> **Tạo ngày:** 2026-06-21

---

## 1. Context (tại sao có task này)

Triệu chứng người dùng báo: bật UART log thì giá trị ADC sai; khi dùng 3 kênh (0,1,2)
**chỉ 1 kênh đọc đúng, 2 kênh còn lại sai**.

Kết luận sau khi đọc code:

- ADC1 chạy **scan + continuous + DMA circular halfword** vào `uint16_t adcBuffer[3]`,
  map `[0]=speed(ch0)`, `[1]=fuel(ch1)`, `[2]=rpm(ch2)` — cấu hình về cơ bản đúng.
  (`STM32-1st/Core/Src/adc.c`, biến `adcBuffer` ở `STM32-1st/Core/Src/main.c:56`).
- **ADCCLK = PCLK2/6 = 12 MHz** (`STM32-1st/Core/Src/main.c:195`) → trong spec (≤14 MHz). **Không** phải nguyên nhân.
- **UART chỉ là "đèn báo", KHÔNG phải nguyên nhân.** `Debug_Printf` dùng `HAL_UART_Transmit`
  polling (`STM32-1st/Core/Src/debug_uart.c:20`). DMA của ADC là phần cứng tự chạy; TX polling
  không thể làm hỏng dữ liệu trong `adcBuffer`. Log chỉ **làm lộ** giá trị vốn đã sai.

**Nguyên nhân thật của "chỉ 1 kênh đúng"** (theo thứ tự khả năng):

1. **Sampling time quá ngắn cho biến trở trở kháng cao.** Hiện đặt `ADC_SAMPLETIME_55CYCLES_5`
   (`STM32-1st/Core/Src/adc.c:62`). Với biến trở giá trị lớn (50k–100k), tụ sample/hold của ADC
   chưa nạp/xả kịp giữa các kênh → **kênh sau "ăn" giá trị kênh trước** (charge bleed). Đây là
   nguyên nhân phần mềm phổ biến nhất của "đúng 1 kênh, sai phần còn lại".
2. **Gọi `HAL_ADC_Start_DMA` hai lần** liên tiếp (`STM32-1st/Core/Src/main.c:126-130`) — lần 2 thừa.
3. (Nếu phần mềm vẫn sai) → **phần cứng**: biến trở PA1/PA2 nổi (floating), sai dây GND/VDD/wiper.

Hướng xử lý đã chốt: **"Fix gọn + bật cảnh báo"** → sửa ADC, dọn double-start, làm an toàn
logging, bật stack-overflow detection để xác nhận dứt điểm giả thuyết stack/UART.

---

## 2. Các thay đổi cần thực hiện

### Bước 1 — Sửa root cause ADC: tăng sampling time (CHÍNH)
- File: `STM32-1st/Core/Src/adc.c:62`.
- Đổi `sConfig.SamplingTime = ADC_SAMPLETIME_55CYCLES_5;` → `ADC_SAMPLETIME_239CYCLES_5;`.
  Struct `sConfig` được tái dùng cho cả 3 rank nên cả 3 kênh đều nhận 239.5 cycles.
  Ở 12 MHz: ~21 µs/kênh × 3 ≈ 63 µs/vòng — dư cho chu kỳ 10 Hz của `StartADCTask`.
- **Đồng bộ CubeMX (bắt buộc):** cập nhật cùng giá trị SamplingTime của 3 kênh ADC1 trong
  `STM32-1st/STM32_Sensor_CAN.ioc`. Lý do: dòng 62 nằm **ngoài** khối `USER CODE` của
  `MX_ADC1_Init`, nên nếu chỉ sửa `adc.c` mà không sửa `.ioc` thì lần regenerate sau sẽ ghi đè.

### Bước 2 — Dọn double DMA start
- File: `STM32-1st/Core/Src/main.c:130`.
- **Xóa** dòng `HAL_ADC_Start_DMA(&hadc1, (uint32_t*) adcBuffer, 3);` thứ hai.
- Giữ lại bản có kiểm tra lỗi ở dòng 126:
  `if (HAL_ADC_Start_DMA(&hadc1, (uint32_t*)adcBuffer, 3) != HAL_OK) { Error_Handler(); }`.

### Bước 3 — Logging an toàn (giảm áp lực stack)
- File: `STM32-1st/Core/Src/debug_uart.c`.
- Hiện `Debug_Printf` đặt `char buf[128]` trên **stack** và gọi `vsnprintf` **trước** khi lấy
  `uartMutex`. Sửa thành:
  1. Chuyển `buf[128]` thành **`static`**.
  2. Di chuyển `vsnprintf` **vào trong** vùng đã giữ `uartMutex` (sau `osMutexAcquire`).
- Vì mutex đã serialize mọi caller nên buffer tĩnh dùng chung là an toàn, đồng thời bỏ 128 B
  khỏi stack của **mọi** task gọi log (`StartADCTask` chỉ có 512 B stack).

### Bước 4 — Bật cảnh báo stack-overflow (yêu cầu "bật cảnh báo")
- File: `STM32-1st/Core/Inc/FreeRTOSConfig.h` — thêm
  `#define configCHECK_FOR_STACK_OVERFLOW 2` (hiện chưa định nghĩa = tắt).
- Thêm hook (đặt trong khối USER CODE của `STM32-1st/Core/Src/freertos.c`):
  ```c
  void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
      Debug_Printf("[STACK OVERFLOW] %s\r\n", pcTaskName);
      // tuỳ chọn: bật 1 LED báo lỗi rồi taskDISABLE_INTERRUPTS(); for(;;);
  }
  ```
- **Defense-in-depth:** nâng stack `ADCTask` và `defaultTask` từ `128*4` → `256*4`
  (`STM32-1st/Core/Src/freertos.c:94` và `:90`) vì cả hai gọi `*printf`.

### Bước 5 — Đồng bộ tài liệu kiến trúc (bắt buộc theo rule codebase_context)
- `datn_agent_skills-test/project_setup/architecture/sensor_ecu.md`: mục ADC (§3) và bảng task
  (§2) — ghi sampling time 239.5 cycles và stack mới của ADCTask/defaultTask; cập nhật dòng
  `> **Last updated:**`.
- `datn_agent_skills-test/project_setup/architecture/DECISIONS.md`: thêm 1 mục `D-0xx`:
  "ADC sampling 239.5 cycles để tránh charge-bleed giữa kênh; UART log không phải nguồn lỗi ADC".

---

## 3. Verification (end-to-end)

1. Build + flash (skill `cubeide-build-flash`: arm-none-eabi-gcc / ST-Link).
2. Mở UART @115200, gửi `GET_STATUS`. Vặn **từng** biến trở (PA0/PA1/PA2) độc lập:
   - Kỳ vọng: cả 3 giá trị `SPEED/FUEL/RPM` thay đổi **độc lập, đúng kênh**; hết hiện tượng
     2 kênh bám/"ăn" theo kênh kia.
3. Bật/tắt `DEBUG_LOG` trong `StartADCTask` (`STM32-1st/Core/Src/freertos.c:350`) → xác nhận giá
   trị **không** phụ thuộc việc log (loại bỏ giả thuyết UART).
4. Xác nhận `vApplicationStackOverflowHook` **không** kích hoạt → loại bỏ giả thuyết tràn stack.
5. Nếu sau khi tăng sampling time vẫn có kênh sai → kiểm tra **phần cứng**: dây biến trở,
   GND/VDD, đầu wiper vào đúng PA1/PA2 (không floating).

---

## 4. File đụng tới (tóm tắt)

| File | Thay đổi |
|------|----------|
| `STM32-1st/Core/Src/adc.c` | SamplingTime → 239.5 cycles |
| `STM32-1st/STM32_Sensor_CAN.ioc` | SamplingTime 3 kênh ADC1 (đồng bộ regen) |
| `STM32-1st/Core/Src/main.c` | Xóa `HAL_ADC_Start_DMA` lần 2 |
| `STM32-1st/Core/Src/debug_uart.c` | `buf` static + `vsnprintf` trong mutex |
| `STM32-1st/Core/Inc/FreeRTOSConfig.h` | `configCHECK_FOR_STACK_OVERFLOW 2` |
| `STM32-1st/Core/Src/freertos.c` | Hook overflow + stack ADCTask/defaultTask 256*4 |
| `.../architecture/sensor_ecu.md`, `DECISIONS.md` | Đồng bộ doc |
