---
name: cubeide-build-flash
description: Build, flash, and debug the STM32F103 firmware (STM32CubeIDE / arm-none-eabi-gcc / ST-Link) and read UART debug output. Use to compile a node, program the board, or set up a build invocation.
---

# STM32 Build / Flash / Debug

Compile and program the two STM32F103C8 nodes.

## When to use this skill
- Building `STM32-1st` or `STM32-2nd` after code changes.
- Flashing a board and watching UART debug logs.
- Setting up/repairing the toolchain invocation.

## How to use it
1. **Project type:** STM32CubeIDE projects (`STM32_Sensor_CAN.ioc`, `STM32_Gateway_CAN.ioc`), ARM GCC, target `STM32F103C8Tx`, linker `STM32F103C8TX_FLASH.ld`.
2. **Build:** open in STM32CubeIDE and Build, or headless via the bundled `arm-none-eabi-gcc` + generated makefile (`Debug/` folder). Produce `.elf`/`.bin`/`.hex`.
3. **Flash:** ST-Link via CubeIDE, or `STM32_Programmer_CLI -c port=SWD -w firmware.elf -rst` / `st-flash write firmware.bin 0x08000000`.
4. **Debug output:** USART1 @ 115200. Both nodes emit `DEBUG_LOG`/`Debug_Printf` traces (CAN TX counts, ADC values, decode diagnostics). The Sensor node also accepts UART commands: `PING`, `GET_STATUS`, `CLR_WARN`, `SET_GEAR:n`.
5. **Two boards, two binaries** — never cross-flash; the Sensor and Gateway are different firmware images sharing only `can_msg.h`.
6. **Shell note:** this workspace is Windows/PowerShell — chain commands with `;`.
