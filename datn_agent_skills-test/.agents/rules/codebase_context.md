---
trigger: always_on
glob: "*"
description: "Tự động nạp kiến trúc codebase vào context trước khi làm task — tránh grep/scan lại từ đầu. Bắt buộc cập nhật doc sau khi sửa codebase."
---

# Quy Tắc Ngữ Cảnh Codebase (Codebase Context)

Dự án: mạng ECU ô tô mô phỏng — **Sensor ECU (STM32-1st) → CAN → Gateway ECU (STM32-2nd) → Ethernet/W5500 → Android ClusterApp (TCP server, chạy trên Raspberry Pi)**.

## 1. Đọc trước khi làm

Trước bất kỳ task nào, BẮT BUỘC đọc (theo vai trò):

| Vai trò | File cần đọc (trong `datn_agent_skills-test/project_setup/architecture/`) |
|---------|-------------|
| **Mọi task (ĐỌC ĐẦU TIÊN)** | `PROJECT_MAP.md` + `overview.md` + `DECISIONS.md` |
| **Sensor ECU (STM32-1st)** | `sensor_ecu.md` |
| **Gateway ECU (STM32-2nd)** | `gateway_ecu.md` |
| **CAN / giao thức** | `can_database.md` + `vehicle_state.md` |
| **Android (ClusterApp)** | `android_app.md` |
| **Luồng dữ liệu end-to-end** | `integration.md` + `system_topology.md` |
| **Hiểu "tại sao"** | `DECISIONS.md` |

### Reading protocol (tiết kiệm token)
1. Đọc `PROJECT_MAP.md` TRƯỚC để biết "cái gì ở đâu" (`file:symbol`) — đừng grep/scan mò.
2. Nhảy thẳng tới `file:symbol` mà PROJECT_MAP trỏ; chỉ mở FULL file khi cần SỬA.
3. Chỉ Grep/Glob khi architecture không có thông tin → và cập nhật lại doc sau đó.

### Canonical ownership (mỗi fact sống MỘT nơi — chống trùng lặp/drift)
- `architecture/*` = sự thật xuyên suốt (cấu trúc, CAN, struct, FSM, luồng). **Nguồn chuẩn khi mâu thuẫn.**
- Bốn lớp KHÔNG được hoán đổi trách nhiệm: Sensor = nguồn sự thật, Gateway = chỉ dịch giao thức, RPi = host, Android = hiển thị.
- Khi code lệch doc: **code là chuẩn**; sửa doc cho khớp.

## 2. Cập nhật sau khi sửa codebase

Sau thay đổi ảnh hưởng kiến trúc, BẮT BUỘC cập nhật file tương ứng:

| Loại thay đổi | File cần cập nhật |
|---------------|------------------|
| Frame/signal CAN | `can_database.md` + `vehicle_state.md` |
| Payload TCP / struct VehicleState | `vehicle_state.md` + `integration.md` + `gateway_ecu.md` |
| Task/peripheral/pin STM32 | `sensor_ecu.md` / `gateway_ecu.md` + `system_topology.md` |
| UI/parse/model Android | `android_app.md` |
| Luồng dữ liệu chính | `overview.md` + `integration.md` |
| Thêm symbol/entry point công khai | `PROJECT_MAP.md` |
| Quyết định thiết kế không hiển nhiên | thêm `D-0xx` vào `DECISIONS.md` |

## 3. Định dạng cập nhật
- Cập nhật dòng `> **Last updated:**` với ngày hiện tại.
- Sửa đúng mục liên quan — không viết lại toàn bộ file. Mỗi mục 1–2 dòng.
- `file:symbol` thêm vào phải tồn tại thật trong submodule.
