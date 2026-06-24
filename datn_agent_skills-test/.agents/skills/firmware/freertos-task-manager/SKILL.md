---
name: freertos-task-manager
description: Design, add, or modify FreeRTOS tasks, queues, timers, and mutexes (CMSIS-RTOS v2) on the STM32 nodes. Use when changing concurrency, task timing, priorities, or inter-task messaging.
---

# FreeRTOS Task Manager

Manage the RTOS layer on both STM32 nodes (CMSIS-RTOS v2 over FreeRTOS).

## When to use this skill
- Adding/removing a task, changing a task's period, priority, or stack.
- Adding a queue/timer/mutex or changing inter-task communication.
- Diagnosing starvation, missed deadlines, or shared-state races.

## How to use it
1. **Know the current task set** before editing — read [`sensor_ecu.md`](../../../project_setup/architecture/sensor_ecu.md) §2 and [`gateway_ecu.md`](../../../project_setup/architecture/gateway_ecu.md) §2.
   - Sensor: `buttonTask` (Low, 20 ms), `ADCTask` (BelowNormal, 100 ms), `CANTask` (High, blocks on queue), `defaultTask` (UART parser). One shared `sensorQueue`.
   - Gateway: `Eth_SendTask` (Normal, 512×4), `defaultTask` (idle). Queue `canToEthQueue`.
2. **Define tasks the CubeMX way:** `osThreadAttr_t` + `osThreadNew` inside `MX_FREERTOS_Init`, in the USER CODE regions. Mirror the existing stack/priority style (`stack_size = N * 4`).
3. **Communicate via queues, not globals,** for cross-task data; use a mutex (see `uartMutex`) for shared peripherals. Keep one writer per shared global where possible.
4. **Serialize hardware access** — e.g. all CAN TX flows through `CANTask`; don't call `HAL_CAN_AddTxMessage` from multiple tasks.
5. **Budget stack & priority:** high-rate/critical work = higher priority but short; blocking waits use `osWaitForever` on a queue, not busy spin.
6. Update the task tables in the architecture docs after any change.
