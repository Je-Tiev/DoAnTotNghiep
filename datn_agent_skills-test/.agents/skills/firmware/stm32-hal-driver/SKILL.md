---
name: stm32-hal-driver
description: Write or modify STM32F103 peripheral drivers using the STM32 HAL (GPIO, SPI, ADC/DMA, USART, CAN). Use when adding/changing a peripheral or low-level driver in STM32-1st or STM32-2nd.
---

# STM32 HAL Driver

Develop and edit bare-metal drivers for the STM32F103C8 nodes using the ST HAL + CubeMX-generated scaffolding.

## When to use this skill
- Adding/modifying a peripheral (GPIO, SPI, ADC, DMA, USART, CAN, timers).
- Writing a new sensor/actuator driver (e.g. keypad, 74HC595, potentiometer).
- Touching anything under `Core/Src/*.c` / `Core/Inc/*.h` that wraps HAL.

## How to use it
1. **Respect CubeMX regions.** Put hand-written code only inside `/* USER CODE BEGIN ... */ ... /* USER CODE END ... */`. Anything outside is regenerated when the `.ioc` is re-run and will be lost.
2. **Pin/clock changes go through the `.ioc`** (`STM32_Sensor_CAN.ioc` / `STM32_Gateway_CAN.ioc`), then regenerate — do not hand-edit `MX_*_Init` pin maps. Confirm against existing pins (CAN PA11/PA12; W5500 CS PB12 on SPI1).
3. **Follow existing patterns:** SPI via `HAL_SPI_Transmit/TransmitReceive` (see `w5500_port.c`), ADC via DMA into a buffer (see `adc.c` → `adcBuffer[3]`), UART debug via `debug_uart.c`/`DEBUG_LOG`.
4. **Keep drivers HAL-thin and reusable**; put application logic in tasks (`freertos.c`), not in the driver.
5. **Non-blocking in ISR/RTOS context:** avoid `HAL_MAX_DELAY` busy-waits on hot paths inside tasks; prefer interrupts/DMA + queues.
6. After changing a peripheral or pin, update [`architecture/sensor_ecu.md`](../../../project_setup/architecture/sensor_ecu.md) or [`gateway_ecu.md`](../../../project_setup/architecture/gateway_ecu.md) and [`system_topology.md`](../../../project_setup/architecture/system_topology.md).
