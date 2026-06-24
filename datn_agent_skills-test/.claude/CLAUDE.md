# Project Memory — Automotive ECU Network (graduation project)

> Lớp tương thích cho **Claude Code**, chạy song song với governance Antigravity ở `.agents/`.
> Nội dung gốc (rules, skills) sống trong `datn_agent_skills-test/` và dùng chung qua **junction** (xem `.claude/setup.ps1`). Máy này không bật Developer Mode nên dùng junction (thư mục) thay symlink — cùng mục tiêu single-source, không cần quyền admin.

## Rules gốc (single source of truth)

@../.agents/rules/codebase_context.md

> **BẮT BUỘC ĐỌC TRƯỚC KHI LÀM TASK:** ba file này đủ để hiểu dự án mà không cần quét lại repo —
> 1. `datn_agent_skills-test/project_setup/architecture/overview.md`
> 2. `datn_agent_skills-test/project_setup/architecture/DECISIONS.md`
> 3. `datn_agent_skills-test/project_setup/architecture/PROJECT_MAP.md`
>
> Sau đó nhảy tới doc theo lớp (`sensor_ecu.md`, `gateway_ecu.md`, `can_database.md`, `android_app.md`, …). Tuyệt đối không đoán mò cấu trúc.

---

## Adapter cho Claude Code

### 1. Ánh xạ công cụ (tool mapping)
- `view_file` / `list_dir` → **Read** / **Glob**.
- `grep_search` → **Grep**.
- "Kích hoạt skill `<X>`" / "gọi skill `<X>`" → gọi skill `<X>` qua **Skill tool** (skills expose ở `.claude/skills/`).

### 2. Đường dẫn workspace (path mapping)
Workspace mở tại `c:\Users\coc14\Downloads\Đồ án tốt nghiệp`. Các thành phần:

| Thành phần | Thư mục |
|---|---|
| Sensor ECU (STM32-1st) | `./STM32-1st` |
| Gateway ECU (STM32-2nd) | `./STM32-2nd` |
| Android ClusterApp | `./ClusterApp` |
| Knowledge base + agent config | `./datn_agent_skills-test` |

Nếu gặp đường dẫn cũ hardcode ổ `d:\datn\...` ở bất kỳ đâu → **bỏ qua**, dùng thư mục tương ứng ở trên.

### 3. Shell
Môi trường **Windows + PowerShell**. Nối nhiều lệnh bằng `;` (không dùng `&&`).

### 4. Quan hệ với `.agents/`
- `.agents/` (Antigravity) là **nguồn gốc, không sửa bản sao**. `.claude/skills/*` là **junction** trỏ về `.agents/skills/*` → sửa một nơi, cả hai hệ thống cùng cập nhật.
- Skills ở `.claude/skills/` được làm phẳng (bỏ lớp category `firmware/`, `android/`, `general/`) nhưng `SKILL.md` là cùng file gốc.
- Regenerate manifest: `python bundle_skills.py` → `skills.json`.

### 5. Quy tắc lớp (không vi phạm)
Sensor ECU = nguồn sự thật · Gateway ECU = chỉ dịch giao thức · Raspberry Pi = host · Android = hiển thị. Không chuyển trách nhiệm giữa các lớp (xem `DECISIONS.md`).
