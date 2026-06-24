---
name: report-writer
description: Draft, revise, or fact-check the Vietnamese graduation thesis (đồ án tốt nghiệp) in LaTeX, pulling every technical fact and citation from project_setup/architecture/*. Use when writing or editing any chapter/section of the báo cáo, or when turning code/architecture into prose, figures, and tables.
---

# Report Writer — Báo cáo tốt nghiệp (LaTeX)

Hỗ trợ viết **đồ án tốt nghiệp** về mạng ECU ô tô mô phỏng. Mục tiêu: prose chính xác, **không bịa số liệu**, mọi sự thật kỹ thuật trích từ tài liệu kiến trúc (single source of truth) — không tự suy diễn lại từ việc quét repo.

## Khi nào dùng skill này
- Soạn mới / chỉnh sửa / rà soát bất kỳ chương, mục, hình, bảng nào của báo cáo.
- Chuyển kiến trúc & code thành văn mô tả, sơ đồ luồng, bảng tín hiệu CAN, đặc tả payload.
- Kiểm tra chéo: nội dung báo cáo có khớp với code/doc hiện tại không.

## Nguồn sự thật (BẮT BUỘC đọc trước khi viết)
Mọi con số, tên symbol, layout frame, struct, pin, FSM, luồng dữ liệu phải lấy từ `datn_agent_skills-test/project_setup/architecture/`. Theo reading protocol của dự án:
1. `PROJECT_MAP.md` → biết "cái gì ở đâu" (`file:symbol`).
2. `overview.md` + `DECISIONS.md` → bức tranh tổng thể và *tại sao*.
3. Nhảy tới doc theo lớp khi viết chương tương ứng:
   - Sensor ECU → `sensor_ecu.md`
   - Gateway ECU → `gateway_ecu.md`
   - CAN/giao thức → `can_database.md` + `vehicle_state.md`
   - Android → `android_app.md`
   - Luồng end-to-end → `integration.md` + `system_topology.md`

**Quy tắc khớp dữ liệu:** nếu báo cáo mâu thuẫn với architecture/code → **code/doc là chuẩn**, sửa báo cáo. Mọi `file:symbol`, số chân, ID frame (0x100/0x200), kích thước payload (18 byte) trích vào báo cáo phải tồn tại thật.

## Không được bịa
- **Không** tự đặt số liệu đo (tần số task, độ trễ, throughput, sai số cảm biến, dung lượng) nếu không có nguồn. Đánh dấu `% TODO[cần đo]: ...` để tác giả điền sau.
- **Không** vẽ kết quả/biểu đồ từ dữ liệu không tồn tại. Mô tả phương pháp đo trước, để chỗ trống cho số thật.
- Giữ đúng **trách nhiệm 4 lớp** khi mô tả hệ thống: Sensor = nguồn sự thật · Gateway = chỉ dịch giao thức · Raspberry Pi = host · Android = hiển thị. Không gán nhầm chức năng giữa các lớp (xem `DECISIONS.md`).

## Đề cương
Tác giả **đã có đề cương riêng** — bám theo mục lục/khung chương của tác giả, không tự áp khung khác. Khi tác giả đưa tên chương/mục, viết đúng phạm vi mục đó; nếu thiếu đề cương cho phần đang viết thì hỏi, đừng tự bịa cấu trúc.

## Quy ước LaTeX (tiếng Việt)
- Cấu trúc đề nghị: `main.tex` (preamble + `\input` từng chương), mỗi chương 1 file `chapters/chuongN.tex`, hình trong `figures/`, tài liệu tham khảo `refs.bib`.
- Tiếng Việt: dùng template trong `resources/preamble.tex` (XeLaTeX/LuaLaTeX + `fontspec` + `polyglossia`/`babel`). Biên dịch bằng **xelatex** (hoặc latexmk -xelatex), không dùng pdflatex thuần vì dấu tiếng Việt.
- Hình/bảng/code/tham chiếu: theo mẫu trong `resources/snippets.tex` (`figure`, `table`, `listings`, `\label`/`\ref`, `\cite`). Luôn `\label` + `\ref`, không hardcode "Hình 3.2".
- Thuật ngữ: lần đầu nêu tiếng Việt kèm tiếng Anh trong ngoặc, ví dụ "khung dữ liệu (frame)"; sau đó dùng nhất quán.
- Trích code: chèn đoạn ngắn có ý nghĩa qua `lstlisting`, kèm `file:symbol` ở caption; không dán nguyên file dài.

## Quy trình viết một mục
1. Xác định mục thuộc lớp nào → đọc đúng doc kiến trúc của lớp đó.
2. Lấy facts (symbol, số, layout) từ doc; nếu doc thiếu → Grep code rồi **cập nhật lại doc** (xem skill `arch-doc-sync`).
3. Viết prose tiếng Việt học thuật, súc tích; chèn hình/bảng/code bằng mẫu LaTeX.
4. Đánh dấu mọi số liệu chưa có bằng `% TODO[cần đo]`.
5. Tự rà: thuật ngữ nhất quán, `\ref`/`\cite` không gãy, không vi phạm trách nhiệm 4 lớp.

## Liên quan
- Nếu trong lúc viết phát hiện code đã đổi nhưng doc chưa cập nhật → chạy `arch-doc-sync` để sửa doc *trước*, rồi mới trích vào báo cáo.
- Bố cục hệ thống/sơ đồ topo lấy từ `system_topology.md` + `integration.md`.
