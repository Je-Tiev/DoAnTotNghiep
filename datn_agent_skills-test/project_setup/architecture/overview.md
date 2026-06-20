# Project Overview: Automotive Cluster & Sensor Network

## 1. System Goals
This project implements an embedded sensor network and digital cluster for an automotive or related simulation system. The system reliably collects physical inputs (buttons, potentiometers), transmits them over a robust CAN bus, gateways the data to an Ethernet network, and finally visualizes the real-time data on an Android-based UI head unit.

## 2. Tech Stack

| Layer | Technologies | Primary Function |
|-------|--------------|------------------|
| **Firmware (Sensor Node)** | C, STM32 HAL, FreeRTOS, STM32CubeIDE | Reads Keypad & ADC, sends data via CAN `0x100` / `0x200`. |
| **Firmware (Gateway Node)** | C, STM32 HAL, W5500 SPI Ethernet | Receives CAN messages and forwards them as UDP/TCP packets over Ethernet. |
| **Application (UI Head Unit)** | Android, Java/Kotlin, Gradle | Socket server (Port 5000) listening to Ethernet data, UI rendering for gauges and status. |
| **Hardware** | STM32F103C8TX, W5500, 74HC595, CAN Transceivers | Microcontrollers and networking hardware. |

## 3. Data Flow

1. **Physical Input**: A 4x3 keypad matrix and 3 potentiometers are read by **STM32 #1 (Sensor Node)** using FreeRTOS tasks.
2. **CAN Bus Transmission**: STM32 #1 packs the data into 8-byte CAN frames (Message IDs `0x100` for control, `0x200` for sensor) and sends them at 250kbps (10Hz).
3. **Gateway Reception**: **STM32 #2 (Gateway Node)** receives the CAN frames via interrupt, unpacks them, validates CRC8, and repacks the data into a 16-byte Ethernet payload.
4. **Ethernet Transmission**: STM32 #2 communicates with a W5500 chip via SPI, pushing the 16-byte payload over UDP/TCP to `192.168.1.50:5000`.
5. **UI Rendering**: The **Raspberry Pi (ClusterApp)** Android socket server receives the packet, validates the header/trailer/CRC16, and updates the UI gauges and indicators in real-time.

## 4. Repository Layout Overview
- `STM32-1st/`: Source code for the Sensor Node.
- `STM32-2nd/`: Source code for the Gateway Node.
- `ClusterApp/`: Source code for the Android UI.
- `datn_agent_skills-test/`: Documentation and agent workflow specifications.
