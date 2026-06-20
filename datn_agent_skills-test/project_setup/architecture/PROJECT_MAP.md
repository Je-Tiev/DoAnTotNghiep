# Project Map

This document maps the core directories and entry points of the repository. Use this to quickly navigate the codebase.

## 1. STM32 #1 (Sensor Node)
Path: `/STM32-1st`
- **Core Logic**: `/STM32-1st/Core/Src/main.c` (FreeRTOS setup, HAL initialization)
- **Tasks**: Look for `ADCTask`, `CANTask`, `buttonTask`, and `blinkTimer` in the source files.
- **Hardware Config**: `/STM32-1st/STM32_Sensor_CAN.ioc`

## 2. STM32 #2 (Gateway Node)
Path: `/STM32-2nd`
- **Core Logic**: `/STM32-2nd/Core/Src/main.c`
- **CAN Handling**: Look for `HAL_CAN_RxFifo0MsgPendingCallback` and `decodeCAN()`.
- **Ethernet Task**: Look for `Eth_SendTask`, `W5500_EnsureSocket()`, and `W5500_SendData()`.
- **Hardware Config**: `/STM32-2nd/STM32_Gateway_CAN.ioc`

## 3. ClusterApp (Android UI & Socket Server)
Path: `/ClusterApp`
- **App Module**: `/ClusterApp/app/`
- **Build Scripts**: `/ClusterApp/build.gradle`, `/ClusterApp/app/build.gradle`
- **Main Code**: Typically under `/ClusterApp/app/src/main/java/` (look for the Socket Server and UI Data Binding logic).

## 4. Documentation & Agent Config
Path: `/datn_agent_skills-test`
- **Architecture**: `/datn_agent_skills-test/project_setup/architecture/`
- **Agent Rules**: `/datn_agent_skills-test/.agents/` and `/datn_agent_skills-test/.claude/`
- **Scripts/Tools**: `/datn_agent_skills-test/tools/`
