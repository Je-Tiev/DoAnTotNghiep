---
name: task-breakdown
description: Decompose a feature/bug across the embedded stack into ordered, layer-aware sub-tasks. Use when planning a change that may span Sensor ECU, CAN, Gateway, and Android.
---

# Task Breakdown (Embedded)

Turn a request into a concrete, dependency-ordered plan that respects the four layers.

## When to use this skill
- Planning any non-trivial change, especially one that crosses layers (a new signal, a new indicator, a protocol tweak).
- Estimating impact / order of work before coding.

## How to use it
1. **Locate the change on the layer map** (Sensor → CAN → Gateway → TCP → Android) using [`PROJECT_MAP.md`](../../../project_setup/architecture/PROJECT_MAP.md) and [`integration.md`](../../../project_setup/architecture/integration.md).
2. **Trace the data path** end-to-end and list every file that must change *in producer→consumer order*. Example for a new signal: `can_encode.c` → `can_database.md` → `can_decode.c` → `can_msg.h` (both) → 18-byte struct/offsets → `ClusterController` parser → `GaugeView`/icons → docs.
3. **Honor ownership** (D-002/003/012): keep state in the Sensor ECU, logic out of the Gateway, distribution out of the RPi. Flag any step that would violate a layer rule.
4. **Output:** an ordered checklist with the owning layer + file per step, plus which `architecture/*.md` docs to update.
5. **Surface risks:** CRC/sequence impact, endianness, struct size/padding, socket/reconnect, RTOS timing.
