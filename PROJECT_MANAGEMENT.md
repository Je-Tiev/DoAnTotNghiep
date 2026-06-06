# Embedded Systems Project - Technical Management

## 1. HIGH-LEVEL PROGRESS SUMMARY

| Subsystem | Status | Priority | Est. % Complete |
|-----------|--------|----------|-----------------|
| STM32 #1 (Sensor Node) | Complete | High | 90% |
| STM32 #2 (Gateway Node) | In Progress | High | 60% |
| Raspberry Pi 4 (Server) | Not Started | Medium | 0% |
| Integration Testing | Not Started | Critical | 0% |

**Project Status**: STM32 #1 & #2 Partial Integration
**Overall Progress**: 50% (60/114 tasks completed)

---

## 2. DETAILED CHECKLIST BY SUBSYSTEM

### SUBSYSTEM A: STM32 #1 - SENSOR NODE (CAN Transmitter)
**Pins Used**: 12 (7 keypad + 3 LED shift + 3 ADC + 2 CAN)

#### A.1 Hardware Configuration & Setup
- [x] Configure GPIO for keypad matrix (7 pins: 4 rows + 3 columns)
- [x] Configure GPIO for 74HC595 shift register (CS, MOSI, CLK)
- [x] Configure ADC channels for potentiometers (ADC0, ADC1, ADC2)
- [x] Configure CAN interface (CAN_TX, CAN_RX pins)
- [x] Validate hardware connections on breadboard/PCB
- [x] Create hardware pinout documentation

#### A.2 Keypad Matrix Driver
- [x] Implement row scanning algorithm
- [x] Implement debouncing logic (20-50ms)
- [x] Create key-to-value mapping (12 buttons)
- [x] Test individual key detection
- [x] Test key combination handling
- [x] Unit test: verify all 12 buttons register correctly

#### A.3 LED Control via 74HC595
- [x] Implement SPI communication with shift register
- [x] Implement LED pattern functions (on, off, blink, pulse)
- [x] Create LED state management (8-bit register)
- [x] Test individual LED control
- [x] Test simultaneous multi-LED patterns
- [x] Unit test: verify all 8 LEDs response

#### A.4 ADC Potentiometer Reading
- [x] Configure ADC in continuous mode
- [x] Implement ADC sampling (0-4095 → 0-65535 via DMA)
- [~] Implement noise filtering/averaging (rolling average) - partial
- [ ] Create potentiometer calibration routine
- [x] Test analog-to-digital conversion accuracy
- [x] Unit test: verify stable readings within tolerance

#### A.5 CAN Communication Setup
- [x] Configure CAN peripheral (250kbps standard for automotive)
- [x] Define message ID (0x100 - Control, 0x200 - Sensor)
- [x] Create CAN frame structure (DLC: 8 bytes for sensor, 4 for control)
  - Byte 0-1: Button state (16 bits for 12 buttons + padding)
  - Byte 2-3: Potentiometer 1 (16-bit ADC)
  - Byte 4-5: Potentiometer 2 (16-bit ADC)
  - Byte 6-7: Potentiometer 3 (16-bit ADC)
- [x] Implement CAN transmission routine
- [x] Test CAN frame transmission with analyzer

#### A.6 Data Packing Algorithm
- [x] Create struct for sensor data: `sensor_data_t`
- [x] Implement data packing function: `pack_sensor_data()`
- [x] Implement CAN frame formatter
- [x] Add timestamp/sequence number (optional)
- [x] Unit test: verify packing/unpacking consistency

#### A.7 Main Application Loop
- [x] Create FreeRTOS task for keypad reading (100ms period)
- [x] Create FreeRTOS task for ADC sampling (50ms period)
- [x] Create FreeRTOS task for CAN transmission (100ms period)
- [x] Implement task synchronization (mutexes/semaphores)
- [ ] Add watchdog timer
- [x] Integration test: all three tasks running without conflicts

#### A.8 Debugging & Testing
- [x] Set up serial debugging interface (UART)
- [x] Implement debug output for all sensor values
- [x] Create test harness for manual testing
- [x] End-to-end test on hardware

---

### SUBSYSTEM B: STM32 #2 - GATEWAY NODE (CAN Receiver + Ethernet Transmitter)
**Pins Used**: 8 (2 CAN + 4 SPI for W5500 + GPIO)

#### B.1 Hardware Configuration & Setup
- [x] Configure CAN interface (CAN_RX, CAN_TX pins) - match STM32 #1
- [x] Configure SPI for W5500 (MOSI, MISO, CLK, CS)
- [x] Configure GPIO for W5500 reset and interrupt pins
- [x] Configure UART for debugging
- [x] Validate hardware connections
- [x] Create hardware pinout documentation

#### B.2 CAN Communication Setup
- [x] Configure CAN peripheral (250kbps - must match STM32 #1)
- [x] Set up CAN receive filters (ID: 0x100 for Control, 0x200 for Sensor)
- [x] Create CAN frame receive interrupt handler
- [x] Implement CAN receive queue/buffer
- [x] Test CAN frame reception from STM32 #1

#### B.3 CAN Frame Parsing
- [x] Create struct for CAN message: `can_message_t`
- [x] Implement CAN frame unpacking function: `decodeCAN()`
- [x] Validate received data (checksum/length check)
- [x] Extract sensor values from CAN frame
- [x] Create parsing error handling with diagnostics
- [x] Unit test: verify parsing with known test frames

#### B.4 W5500 Ethernet Driver Setup
- [x] Initialize W5500 via SPI
- [x] Configure MAC address, IP address, subnet, gateway
- [x] Set up socket parameters (UDP mode configured)
- [x] Implement SPI read/write functions
- [x] Test W5500 communication (SPI handshake)

#### B.5 Ethernet Communication Protocol
- [x] Define data packet format to send to Raspberry Pi
  - Header: UDP packet with network info
  - Data: VehicleState_t (control + sensor fields)
  - CRC: Optional (UDP provides basic checksum)
- [x] Implement UDP socket creation (port 5000)
- [x] Implement packet transmission function
- [~] Implement client connection handling - partial
- [ ] Handle client disconnect/reconnect

#### B.6 Data Forwarding Logic
- [x] Create data forwarding task
- [x] Implement CAN → Ethernet conversion
- [~] Add timestamp to packets - optional
- [~] Handle multiple clients - UDP broadcast mode
- [~] Implement rate limiting (100ms minimum between sends)
- [~] Buffer management for dropped frames

#### B.7 Main Application Loop
- [x] Create FreeRTOS task for CAN receive (interrupt-driven)
- [x] Create FreeRTOS task for Ethernet data transmission (event-driven)
- [ ] Create FreeRTOS task for connection management (1s)
- [x] Implement task synchronization (message queue)
- [ ] Add watchdog timer
- [~] Integration test: CAN → Ethernet forwarding - partial

#### B.8 Debugging & Testing
- [ ] Set up serial debug output (UART)
- [ ] Implement frame logging (CAN and Ethernet packets)
- [ ] Create packet sniffer for validation
- [ ] End-to-end test: receive from STM32 #1 and send to network
- [ ] Create Ethernet packet sniffer for validation
- [ ] End-to-end test: receive from STM32 #1 and send to network

---

### SUBSYSTEM C: RASPBERRY PI 4 - SOCKET SERVER APPLICATION
**Platform**: Android-based (or embedded Linux)

#### C.1 Project Setup
- [x] Initialize Android/Linux project structure
- [x] Set up build system (Gradle for Android)
- [~] Configure network permissions (Manifest/system config)
- [~] Set up dependency management (if using libraries)

#### C.2 Socket Server Implementation
- [ ] Create TCP server socket (port 5000, listening address 0.0.0.0)
- [ ] Implement socket accept/connection handler
- [ ] Implement socket read/receive loop
- [ ] Implement client state management (connected clients list)
- [ ] Implement error handling and reconnection logic
- [ ] Unit test: socket creation and acceptance

#### C.3 Data Reception & Parsing
- [ ] Implement packet reception with header validation (0xAA 0x55)
- [ ] Implement packet length validation
- [ ] Implement CRC/checksum verification
- [ ] Create data unpacking function: `parse_sensor_packet()`
- [ ] Extract individual sensor values
- [ ] Implement error logging for invalid packets

#### C.4 Data Processing
- [ ] Create data storage model/database (SQLite or in-memory)
- [ ] Implement sensor value caching
- [ ] Add timestamp tracking
- [ ] Create data aggregation (min/max/average per time window)
- [ ] Implement real-time data display update mechanism

#### C.5 UI Implementation (if required)
- [x] Create main activity/window
- [x] Implement real-time data display (buttons, LEDs, potentiometer values)
- [x] Add visualization (gauges, graphs for analog values)
- [x] Implement connection status indicator
- [x] Manual LED control buttons (optional feedback)

#### C.6 Auto-Start & Background Service
- [~] Create background service for socket server
- [~] Implement boot receiver to start service on system startup
- [~] Handle service lifecycle (onCreate, onDestroy)
- [~] Implement foreground notification (required for long-running service)
- [~] Test service restart after crash

#### C.7 Logging & Debugging
- [~] Implement application logging (file-based or logcat)
- [~] Create debug console for real-time packet inspection
- [~] Add connection statistics (packets received, bytes transferred)
- [~] Implement log rotation (prevent storage overflow)

#### C.8 Testing & Validation
- [ ] Unit test: socket server functionality
- [ ] Integration test: packet reception and parsing
- [ ] System test: end-to-end data flow
- [ ] Performance test: sustained data reception (100 packets/sec for 1 hour)
- [ ] Stress test: sudden connection drops and reconnects

---

## 3. DEPENDENCY GRAPH (Text Form)

```
PHASE 1: Hardware & Configuration
├── STM32 #1: GPIO & ADC setup (A.1, A.2)
├── STM32 #1: SPI for 74HC595 (A.1, A.3)
├── STM32 #1: CAN peripheral config (A.1, A.5)
├── STM32 #2: CAN peripheral config (B.1, B.2)
├── STM32 #2: SPI for W5500 (B.1, B.4)
└── RPi4: Network setup (C.1)

PHASE 2: Individual Subsystem Features
├── STM32 #1: Keypad driver → Test (A.2 → A.8)
├── STM32 #1: LED control → Test (A.3 → A.8)
├── STM32 #1: ADC reading → Test (A.4 → A.8)
├── STM32 #1: CAN setup → Data packing (A.5 → A.6)
├── STM32 #2: CAN receive → Frame parsing (B.2 → B.3)
├── STM32 #2: W5500 init → Ethernet protocol (B.4 → B.5)
└── RPi4: Socket server → Data parsing (C.2 → C.3)

PHASE 3: Integration
├── STM32 #1: Main loop integration (A.1-A.7 → A.8) ✓ Prerequisite for system test
├── STM32 #1: Send CAN test frame (A.6 → B.2)
├── STM32 #2: Receive & parse CAN (B.2 → B.3) ✓ Blocks: B.6
├── STM32 #2: Forward to Ethernet (B.3 → B.6)
├── RPi4: Receive & parse packets (C.2 → C.3) ✓ Blocks: C.4
└── STM32 #2: Verify packet format (B.6 ← C.3 feedback)

PHASE 4: End-to-End Testing
├── STM32 #1: Sensors → CAN (A.8 complete)
├── STM32 #2: CAN → Ethernet (B.8 complete)
├── RPi4: Socket → Display (C.8 complete)
├── Cross-subsystem validation
└── System stress testing

Critical Path:
A.1, A.5, A.6 → B.1, B.2, B.3 → B.4, B.5, B.6 → C.1, C.2, C.3
```

---

## 4. TASK DEPENDENCIES TABLE

| Task | Depends On | Blocks | Duration (est.) |
|------|-----------|--------|-----------------|
| A.1 (GPIO setup) | None | A.2, A.3, A.4, A.5 | 1 day |
| A.2 (Keypad) | A.1 | A.7 | 2 days |
| A.3 (LED) | A.1 | A.7 | 2 days |
| A.4 (ADC) | A.1 | A.7 | 2 days |
| A.5 (CAN setup) | A.1 | A.6, B.2 | 1 day |
| A.6 (Data packing) | A.2, A.3, A.4, A.5 | A.7, B.3 | 1 day |
| A.7 (Main loop) | A.2, A.3, A.4, A.6 | A.8 | 2 days |
| A.8 (Testing) | A.7 | Phase 3 | 2 days |
| B.1 (GPIO/SPI setup) | None | B.2, B.4 | 1 day |
| B.2 (CAN receive) | A.5, B.1 | B.3, B.8 | 1 day |
| B.3 (CAN parsing) | A.6, B.2 | B.6 | 1 day |
| B.4 (W5500 init) | B.1 | B.5 | 1 day |
| B.5 (Ethernet proto) | B.4 | B.6 | 2 days |
| B.6 (Data forward) | B.3, B.5, C.2 | B.8 | 2 days |
| B.8 (Testing) | B.6 | Phase 4 | 1 day |
| C.1 (Setup) | None | C.2 | 1 day |
| C.2 (Socket server) | C.1 | C.3, C.6 | 2 days |
| C.3 (Data parsing) | B.5, C.2 | C.4, C.7 | 1 day |
| C.4 (Processing) | C.3 | C.5 | 2 days |
| C.5 (UI) | C.4 | C.8 | 2 days |
| C.6 (Auto-start) | C.2 | C.8 | 1 day |
| C.7 (Logging) | C.2 | C.8 | 1 day |
| C.8 (Testing) | C.5, C.6, C.7 | Phase 4 | 2 days |

---

**Last Updated**: 2026-04-20
**Status**: Coding Phase
