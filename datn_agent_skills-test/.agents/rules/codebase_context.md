---
trigger: always_on
glob: "*"
description: "Tự động nạp kiến trúc codebase vào context trước khi làm task — tránh grep/scan lại từ đầu. Bắt buộc cập nhật sau khi sửa codebase."
---

# Quy Tắc Ngữ Cảnh Codebase (Codebase Context)

## 1. Đọc trước khi làm

Trước khi thực hiện bất kỳ task nào liên quan đến backend, frontend, hoặc firmware, BẮT BUỘC đọc các file sau (theo vai trò):

| Vai trò | File cần đọc |
|---------|-------------|
| **Mọi task (ĐỌC ĐẦU TIÊN)** | `datn-agent-skills/project_setup/architecture/PROJECT_MAP.md` (index file:line) + `overview.md` + `architecture/protocol.md` |
| **ClusterApp (Android UI)** | `architecture/cluster_app.md` |
| **Firmware (STM32)** | `architecture/firmware.md` |
| **Hiểu "tại sao"** | `architecture/DECISIONS.md` (quyết định thiết kế) khi cần ngữ cảnh lựa chọn |

### Reading protocol (tiết kiệm token)
1. Đọc `PROJECT_MAP.md` TRƯỚC để biết "cái gì ở đâu" — đừng grep/scan mò.
2. Nhảy thẳng tới `file:line` mà PROJECT_MAP trỏ; chỉ mở FULL file khi cần SỬA.
3. Chỉ Grep/Glob khi PROJECT_MAP/architecture không có thông tin → và cập nhật lại doc sau đó.

### Canonical ownership (mỗi fact sống MỘT nơi — chống trùng lặp/drift)
- `architecture/*` = sự thật xuyên suốt (API, topic, schema, FSM, luồng). **Nguồn chuẩn khi mâu thuẫn.**
- `components/<x>/README.md` = "how/why" của riêng component; **trỏ tới header** thay vì copy struct/chữ ký.
- `CLAUDE.md` / rules = quy ước & cách làm việc.
- Khi code lệch doc: **code là chuẩn**; sửa doc cho khớp (trừ khi chủ động chọn ngược).

## 2. Cập nhật sau khi sửa codebase

Sau khi hoàn thành bất kỳ thay đổi nào ảnh hưởng đến kiến trúc, BẮT BUỘC cập nhật file tương ứng trong `project_setup/architecture/`:

| Loại thay đổi | File cần cập nhật |
|---------------|------------------|
| Sửa cấu trúc CAN / Ethernet Packet | `protocol.md` |
| Thêm/xóa UI component trên Android | `cluster_app.md` |
| Thay đổi cấu hình STM32 / FreeRTOS | `firmware.md` |
| Thêm package/dependency lớn | file liên quan → mục Tech Stack |
| Thay đổi luồng dữ liệu chính | `overview.md` + file liên quan |
| Thêm/sửa public API, hằng số, topic, FSM, component | `PROJECT_MAP.md` (hoặc chạy `tools/gen_project_map.py` rồi rà lại) |
| Quyết định thiết kế không hiển nhiên (vì sao chọn X) | thêm mục mới vào `DECISIONS.md` |

## 3. Định dạng cập nhật

- Luôn cập nhật dòng `> **Cập nhật lần cuối:**` với ngày hiện tại.
- Thêm/sửa đúng mục liên quan — không viết lại toàn bộ file.
- Giữ ngắn gọn: mỗi mục tối đa 1-2 dòng mô tả.
