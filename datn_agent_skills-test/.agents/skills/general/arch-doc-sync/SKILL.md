---
name: arch-doc-sync
description: Keep project_setup/architecture/*.md in sync with the code after a change, so future AI sessions stay accurate. Use after modifying firmware, the CAN protocol, the TCP payload, or the Android app.
---

# Architecture Doc Sync

Maintain the persistent knowledge layer so the next session doesn't have to re-scan the repo.

## When to use this skill
- Immediately after any code change that affects structure, protocol, tasks, pins, or data flow.
- Whenever code and docs disagree (code wins — fix the doc).

## How to use it
1. **Map the change to the doc** (mirrors `.agents/rules/codebase_context.md`):
   | Change | Update |
   |--------|--------|
   | CAN frame/signal | `can_database.md` + `vehicle_state.md` |
   | TCP payload / struct | `vehicle_state.md` + `integration.md` + `gateway_ecu.md` |
   | STM32 task/peripheral/pin | `sensor_ecu.md` / `gateway_ecu.md` + `system_topology.md` |
   | Android UI/parse/model | `android_app.md` |
   | Main data flow | `overview.md` + `integration.md` |
   | New public symbol / entry point | `PROJECT_MAP.md` |
   | Non-obvious decision | new `D-0xx` in `DECISIONS.md` |
2. **Edit surgically** — change only the affected section, keep entries to 1–2 lines, don't rewrite whole files.
3. **Bump** the `> Last updated:` line to today's date.
4. **Canonical ownership:** `architecture/*` is the source of truth; each fact lives in exactly one file — link with relative paths instead of duplicating.
5. **Verify citations:** any `file:symbol` you add must actually exist in the submodule.
