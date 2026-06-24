# datn_agent_skills-test — Architecture Knowledge & AI-Agent Layer

Persistent memory + agent configuration for the **Automotive ECU Network** graduation project
(Sensor ECU `STM32-1st` → CAN → Gateway ECU `STM32-2nd` → Ethernet/W5500 → Android `ClusterApp` on Raspberry Pi 4).

It exists so any AI agent (Antigravity, Claude Code) can pick up the project **without re-scanning the whole repo**.

## Read these first (in order)
1. [`project_setup/architecture/overview.md`](project_setup/architecture/overview.md)
2. [`project_setup/architecture/DECISIONS.md`](project_setup/architecture/DECISIONS.md)
3. [`project_setup/architecture/PROJECT_MAP.md`](project_setup/architecture/PROJECT_MAP.md)

Then jump to the per-layer doc you need (`sensor_ecu.md`, `gateway_ecu.md`, `can_database.md`, `vehicle_state.md`, `integration.md`, `android_app.md`, `system_topology.md`, `raspberry_pi.md`).

## Layout
| Path | What |
|------|------|
| `project_setup/architecture/` | The knowledge base (source of truth for structure/protocol/flow) |
| `.agents/rules/` + `.agents/skills/` | Antigravity rules and embedded-dev skills |
| `.claude/CLAUDE.md` + `.claude/setup.ps1` | Claude Code adapter; `setup.ps1` junctions skills into `.claude/skills/` |
| `project_setup/agents_config.md` | Agent roles → skills mapping |
| `bundle_skills.py`, `skills.json` | Skill manifest generator + generated manifest |

## Maintenance
- After changing code, update the matching `architecture/*.md` (see `.agents/rules/codebase_context.md` and the `arch-doc-sync` skill).
- Regenerate the skill manifest: `python bundle_skills.py`.
- Wire up Claude Code skills/junctions: `powershell -ExecutionPolicy Bypass -File .claude/setup.ps1`.
