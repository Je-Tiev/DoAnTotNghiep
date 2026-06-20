# Firmware Architecture

## STM32 #1 (Sensor Node)
- **Microcontroller**: STM32F103C8TX
- **RTOS**: FreeRTOS
- **Key Features**:
  - Continuous ADC scanning via DMA for 3 potentiometers.
  - Matrix keypad scanning (4x3) with debouncing.
  - SPI communication with 74HC595 shift register for 8 LEDs.
  - CAN Transmission (Message IDs `0x100`, `0x200`) using HAL CAN drivers.
- **Tasks**:
  1. `ADCTask`: Samples potentiometers.
  2. `buttonTask`: Scans the matrix and updates the LED shift register.
  3. `CANTask`: Pulls from queues and calls `HAL_CAN_AddTxMessage()`.
  4. `blinkTimer`: Timer callback for LED patterns.

## STM32 #2 (Gateway Node)
- **Microcontroller**: STM32F103C8TX
- **Networking Module**: W5500 SPI Ethernet Module
- **Key Features**:
  - Interrupt-driven CAN Reception with FIFO0.
  - Hybrid state accumulation to merge data from multiple CAN frames (`0x100`, `0x200`).
  - Ethernet communication using the W5500 via SPI (`Eth_SendTask`).
- **Tasks**:
  1. `Eth_SendTask`: Validates the W5500 socket (`W5500_EnsureSocket`), extracts accumulated CAN data (`decodeCAN`), and transmits the 16-byte UDP/TCP packet.
