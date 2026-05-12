# Project Checklist - Quick Reference

## PRIORITY 1: WEEK 1 (Foundation Phase)

### STM32 #1: Hardware Setup
- [X] A.1.1 - Configure GPIO for keypad (7 pins)
- [x] A.1.2 - Configure GPIO for 74HC595 (3 pins)
- [x] A.1.3 - Configure ADC channels (3 pins)
- [x] A.1.4 - Configure CAN interface (2 pins) - **CRITICAL**
- [ ] A.1.5 - Create and verify pinout documentation
- [x] **TEST**: All GPIO initialized without errors

### STM32 #1: CAN Protocol
- [ ] A.5.1 - Set CAN baudrate to 250kbps - **CRITICAL PATH**
- [ ] A.5.2 - Set message ID to 0x100
- [ ] A.5.3 - Configure 8-byte DLC
- [ ] A.5.4 - Test with CAN analyzer (verify traffic)
- [ ] **TEST**: CAN frames appear on bus

### STM32 #2: Hardware Setup
- [x] B.1.1 - Configure CAN interface (2 pins) - **MUST MATCH STM32 #1**
- [x] B.1.2 - Configure SPI for W5500 (4 pins)
- [ ] B.1.3 - Configure W5500 reset + IRQ pins
- [ ] B.1.4 - Create pinout documentation
- [ ] **TEST**: CAN bus sees STM32 #2 as receiver

### STM32 #2: W5500 Initialization
- [ ] B.4.1 - Initialize W5500 via SPI - **CRITICAL**
- [ ] B.4.2 - Configure MAC address (AA:BB:CC:DD:EE:FF)
- [ ] B.4.3 - Configure IP address (192.168.1.100)
- [ ] B.4.4 - Configure gateway & subnet
- [ ] **TEST**: W5500 responds to SPI (ID register reads correctly)

### Raspberry Pi 4: Network Setup
- [ ] C.1.1 - Set static IP address (192.168.1.50)
- [ ] C.1.2 - Test connectivity to STM32 #2 (ping 192.168.1.100)
- [ ] C.1.3 - Verify port 5000 availability
- [ ] C.1.4 - Check firewall settings
- [ ] **TEST**: Network reachability confirmed

---

## PRIORITY 2: WEEK 2 (Feature Development)

### STM32 #1: Input Drivers
- [x] A.2.1 - Implement keypad scanning loop
- [ ] A.2.2 - Add debouncing (20ms threshold)
- [ ] A.2.3 - Create key-to-value mapping for 12 buttons
- [ ] A.2.4 - Test each button individually
- [ ] A.3.1 - Implement 74HC595 SPI communication
- [ ] A.3.2 - Create LED control functions (on/off/blink)
- [ ] A.3.3 - Test all 8 LEDs independently
- [ ] A.4.1 - Configure ADC for continuous mode
- [ ] A.4.2 - Implement rolling average filter (5-sample)
- [ ] A.4.3 - Calibrate potentiometer ranges (0-255 or 0-1023)
- [ ] **TEST**: All sensors read correctly on UART debug output

### STM32 #1: CAN Data Packing
- [ ] A.6.1 - Create `sensor_data_t` struct
- [ ] A.6.2 - Implement `pack_sensor_data()` function
- [ ] A.6.3 - Define 8-byte frame layout
- [ ] A.6.4 - Implement `unpack_sensor_data()` (verify round-trip)
- [ ] **TEST**: Pack/unpack with known values produces identical output

### STM32 #2: CAN Reception
- [ ] B.2.1 - Configure CAN receive filters
- [ ] B.2.2 - Set filter ID to 0x100 (STM32 #1)
- [ ] B.2.3 - Create receive interrupt handler
- [ ] B.2.4 - Implement receive queue/buffer
- [ ] **TEST**: Receive frames from STM32 #1 in test mode

### STM32 #2: W5500 Ethernet Protocol
- [ ] B.5.1 - Define packet format (header, length, data, CRC)
- [ ] B.5.2 - Implement TCP socket creation (port 5000)
- [ ] B.5.3 - Implement client accept handler
- [ ] B.5.4 - Implement packet transmission function
- [ ] **TEST**: Manual telnet connection to port 5000

### Raspberry Pi: Socket Server Core
- [ ] C.2.1 - Create TCP server socket
- [ ] C.2.2 - Bind to port 5000
- [ ] C.2.3 - Listen for incoming connections
- [ ] C.2.4 - Accept client connection
- [ ] C.2.5 - Implement receive loop (blocking read)
- [ ] C.3.1 - Validate packet header (0xAA 0x55)
- [ ] C.3.2 - Parse packet length field
- [ ] C.3.3 - Verify CRC/checksum
- [ ] **TEST**: Echo server receives test packets from netcat

---

## PRIORITY 3: WEEK 3 (System Integration)

### STM32 #1: Main Application
- [x] A.7.1 - Create FreeRTOS task for keypad (100ms period)
- [x] A.7.2 - Create FreeRTOS task for ADC (50ms period)
- [x] A.7.3 - Create FreeRTOS task for CAN transmission (100ms)
- [ ] A.7.4 - Add mutex for shared data access
- [?] A.7.5 - Add watchdog timer
- [ ] A.8 - **INTEGRATION TEST**: Hardware end-to-end (all tasks running)

### STM32 #2: Data Forwarding
- [ ] B.3 - Implement CAN frame parsing (unpack structure)
- [ ] B.6.1 - Create CAN → Ethernet conversion loop
- [ ] B.6.2 - Broadcast packets to connected clients
- [ ] B.6.3 - Handle client disconnects gracefully
- [ ] B.8 - **INTEGRATION TEST**: CAN frames reach Raspberry Pi

### Raspberry Pi: Data Processing
- [ ] C.4.1 - Store received sensor values in memory
- [ ] C.4.2 - Add timestamp tracking
- [ ] C.4.3 - Calculate min/max/average per window
- [ ] C.5.1 - Create UI for real-time data display
- [ ] C.5.2 - Show button states (visual grid)
- [ ] C.5.3 - Show LED states (visual grid)
- [ ] C.5.4 - Display potentiometer values (gauges/bars)
- [ ] C.8 - **INTEGRATION TEST**: Live data display updates correctly

---

## PRIORITY 4: WEEK 4 (Polish & Testing)

### Robustness
- [ ] A.8 - Add UART debug logging for all sensor values
- [ ] B.8 - Add Ethernet packet logging (source, dest, payload)
- [ ] B.5.4 - Implement rate limiting (100ms min between sends)
- [ ] C.6.1 - Create background service for socket server
- [ ] C.6.2 - Configure boot receiver for auto-start
- [ ] C.7 - Implement file-based logging system

### Testing
- [ ] Full system test: sensors → CAN → Ethernet → UI (30 minutes)
- [ ] Stress test: 100+ frames/sec for 1 hour
- [ ] Robustness test: sudden network disconnects + reconnects
- [ ] Performance test: measure latency (sensor → display)
- [ ] Edge cases: missing/malformed packets, client drops

---

## CURRENT STATUS DASHBOARD

```
WEEK 1 (Foundation):        [███████░░░░░░░░░░░░░░░░░░░░░░] 25% Complete
WEEK 2 (Features):          [██░░░░░░░░░░░░░░░░░░░░░░░░░░░] 5% Complete
WEEK 3 (Integration):       [█░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 10% Complete
WEEK 4 (Polish/Testing):    [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% Complete

SUBSYSTEM A (STM32 #1):     [███████░░░░░░░░░░░░░░░░░░░░░░] 19% Complete
SUBSYSTEM B (STM32 #2):     [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% Complete
SUBSYSTEM C (Raspberry Pi): [██████░░░░░░░░░░░░░░░░░░░░░░░░] 15% Complete

OVERALL PROJECT:            [█████░░░░░░░░░░░░░░░░░░░░░░░░░] 13% Complete
                            (15 of 114 tasks completed)
```

---

## BLOCKERS & DEPENDENCIES QUICK VIEW

**Currently Blocking Nothing** ✓

**Blocked By Nothing** ✓

---


*Last Updated: 2026-05-07*
*Project Start Date: 2026-05-06*
