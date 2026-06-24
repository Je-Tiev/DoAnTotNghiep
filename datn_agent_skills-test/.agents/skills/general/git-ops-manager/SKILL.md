---
name: git-ops-manager
description: Run Git operations across the monorepo and its three submodules (STM32-1st, STM32-2nd, ClusterApp). Use for commits, branches, pushes, and keeping submodule pointers in sync on Windows/PowerShell.
---

# Git Ops Manager

Handle version control for the superproject + three submodules.

## When to use this skill
- Committing/pushing changes in any submodule or the superproject.
- Updating submodule pointers, branching, or resolving submodule drift.

## How to use it
1. **Repo shape:** superproject at `Đồ án tốt nghiệp/` with submodules `STM32-1st` (`Je-Tiev/STM32_Sensor_CAN`), `STM32-2nd` (`Je-Tiev/STM32_Gateway_CAN`), `ClusterApp` (`Je-Tiev/CarClusterApp`). `datn_agent_skills-test/` is a normal folder.
2. **Commit inside the submodule first**, push it, then commit the updated pointer in the superproject. Otherwise the superproject references an unpushed commit.
3. **Shell:** Windows/PowerShell — chain with `;` (not `&&`). Avoid interactive flags (`-i`).
4. **Only commit/push when the user asks.** If on the default branch for a risky change, branch first.
5. **Commit messages:** concise, present-tense; include the date when matching project convention.
6. After firmware/app changes, make sure the matching `architecture/*.md` doc updates are in the same commit (see `arch-doc-sync`).
