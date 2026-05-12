# Technical Specifications & Protocol Definitions

## 1. PINOUT & HARDWARE SPECIFICATIONS

### STM32 #1 (Sensor Node) - STM32F103C8TX
Total Pins Used: **12**

```
GPIO ALLOCATION:
├── Keypad Matrix (7 pins)
│   ├── Row 0: PB0
│   ├── Row 1: PB1
│   ├── Row 2: PB2
│   ├── Row 3: PB3
│   ├── Col 0: PB4
│   ├── Col 1: PB5
│   └── Col 2: PB6
│
├── 74HC595 Shift Register (3 pins)
│   ├── CS/Latch:  PA4  (NSS)
│   ├── MOSI/Data: PA7  (SPI1_MOSI)
│   └── CLK:       PA5  (SPI1_CLK)
│
├── ADC Inputs (3 pins)
│   ├── Pot 1: PA0 (ADC_CH0)
│   ├── Pot 2: PA1 (ADC_CH1)
│   └── Pot 3: PA2 (ADC_CH2)
│
└── CAN Interface (2 pins)
    ├── CAN_TX: PA12 (CAN_TX)
    └── CAN_RX: PA11 (CAN_RX)

UART DEBUG (Optional):
├── TX: PA9  (USART1_TX)
└── RX: PA10 (USART1_RX)
```

### STM32 #2 (Gateway Node) - STM32F103C8TX
Total Pins Used: **8**

```
GPIO ALLOCATION:
├── CAN Interface (2 pins)
│   ├── CAN_TX: PA12 (CAN_TX)
│   └── CAN_RX: PA11 (CAN_RX)
│
├── W5500 SPI Interface (4 pins)
│   ├── CS:    PA4  (NSS)
│   ├── MOSI:  PA7  (SPI1_MOSI)
│   ├── MISO:  PA6  (SPI1_MISO)
│   └── CLK:   PA5  (SPI1_CLK)
│
├── W5500 Control (2 pins)
│   ├── RST:   PA8
│   └── INT:   PB0
│
└── UART DEBUG (Optional)
    ├── TX: PA9  (USART1_TX)
    └── RX: PA10 (USART1_RX)
```

---

## 2. CAN PROTOCOL SPECIFICATION

### CAN Bus Configuration
```
Baudrate:       250 kbps (standard for automotive applications)
Frame Type:     Standard 11-bit CAN 2.0A
Error Handling: CRC-16 polynomial
Timeout:        1 second (retry mechanism)
```

### CAN Frame Format - Sensor Data (0x100)
**Source**: STM32 #1 → **Destination**: STM32 #2

```
┌─────────────────────────────────────────────────────────────┐
│ CAN Frame Structure (8 bytes total)                         │
├─────────────────────────────────────────────────────────────┤
│ Byte 0-1: Button State (16-bit bitmask)                    │
│   Bit 0:    Button 1  (0=released, 1=pressed)              │
│   Bit 1:    Button 2                                        │
│   ...                                                        │
│   Bit 11:   Button 12                                       │
│   Bit 12-15: Reserved (always 0)                            │
│                                                              │
│ Byte 2-3: Potentiometer 1 (16-bit unsigned, 0-65535)       │
│   Range: 0 = fully left, 65535 = fully right               │
│   ADC 12-bit (0-4095) → scale to 0-65535                   │
│                                                              │
│ Byte 4-5: Potentiometer 2 (16-bit unsigned, 0-65535)       │
│                                                              │
│ Byte 6-7: Potentiometer 3 (16-bit unsigned, 0-65535)       │
└─────────────────────────────────────────────────────────────┘

Header:  0x100 (CAN Message ID)
DLC:     0x08 (8 bytes)
TX Rate: 100 ms (10 Hz)
```

### CAN Frame Example (Binary)
```
CAN ID:  0x100
Data:    [0x0F, 0x00, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]
         └─ 15 buttons pressed
                └─ Pot1 = 0x1234
                         └─ Pot2 = 0x5678
                                  └─ Pot3 = 0x9ABC
```

### C Struct Definition (STM32 #1 & #2)
```c
#pragma pack(1)
typedef struct {
    uint16_t button_state;      // Byte 0-1: 12 buttons + 4 reserved
    uint16_t potentiometer1;    // Byte 2-3: ADC value
    uint16_t potentiometer2;    // Byte 4-5: ADC value
    uint16_t potentiometer3;    // Byte 6-7: ADC value
} CAN_SENSOR_DATA_t;
#pragma pack()

// Usage:
CAN_SENSOR_DATA_t sensor_data;
sensor_data.button_state = (button_reading & 0x0FFF);  // Only 12 bits
sensor_data.potentiometer1 = adc_value1;
// ... pack into CAN frame
```

---

## 3. ETHERNET PROTOCOL SPECIFICATION

### Network Configuration
```
STM32 #2 (W5500):
├── MAC Address:     AA:BB:CC:DD:EE:FF  (configurable)
├── IP Address:      192.168.1.100
├── Subnet Mask:     255.255.255.0
├── Gateway:         192.168.1.1
└── Port:            5000 (TCP listening)

Raspberry Pi 4:
├── MAC Address:     (auto-assigned)
├── IP Address:      192.168.1.50  (or DHCP)
├── Gateway:         192.168.1.1
└── Port:            5000 (client connects here)

Network Mode:        TCP/IP (reliable, ordered delivery)
Packet Interval:     100 ms (10 Hz, synchronized with CAN)
```

### Ethernet Packet Format (STM32 #2 → Raspberry Pi)
**Sent via TCP socket to 192.168.1.50:5000**

```
┌───────────────────────────────────────────────────────────────┐
│ Ethernet Packet Structure (16 bytes total)                    │
├───────────────────────────────────────────────────────────────┤
│ Byte 0:   Header Sync Byte 1 (always 0xAA)                  │
│ Byte 1:   Header Sync Byte 2 (always 0x55)                  │
│                                                                │
│ Byte 2-3: Payload Length (16-bit big-endian)                │
│           Value: 10 (fixed for this implementation)          │
│                                                                │
│ Byte 4:   Sequence Number (0-255, wraps around)             │
│           Increments on each transmission                    │
│                                                                │
│ Byte 5-6: Button State (16-bit, same as CAN byte 0-1)       │
│                                                                │
│ Byte 7-8:  Potentiometer 1 (16-bit)                         │
│                                                                │
│ Byte 9-10: Potentiometer 2 (16-bit)                         │
│                                                                │
│ Byte 11-12: Potentiometer 3 (16-bit)                        │
│                                                                │
│ Byte 13-14: CRC16 (CCITT polynomial 0x1021)                 │
│            Covers bytes 0-12                                 │
│                                                                │
│ Byte 15:  Trailer (always 0xFF)                              │
└───────────────────────────────────────────────────────────────┘

Total Size: 16 bytes
```

### Ethernet Packet Example (Hex)
```
AA 55 00 0A 42 00 0F 12 34 56 78 9A BC A1 B2 FF

Breakdown:
├─ AA 55          : Header sync
├─ 00 0A          : Length = 10 bytes
├─ 42             : Sequence = 0x42 (66)
├─ 00 0F          : Buttons = 0x000F (15 buttons)
├─ 12 34          : Pot1 = 0x1234 (4660)
├─ 56 78          : Pot2 = 0x5678 (22136)
├─ 9A BC          : Pot3 = 0x9ABC (39612)
├─ A1 B2          : CRC = 0xA1B2
└─ FF             : Trailer
```

### C Struct Definition (STM32 #2 & Raspberry Pi)
```c
#pragma pack(1)
typedef struct {
    uint8_t  header1;              // 0xAA
    uint8_t  header2;              // 0x55
    uint16_t payload_length;       // 10 (big-endian)
    uint8_t  sequence_number;      // 0-255
    uint16_t button_state;         // 12-bit data
    uint16_t potentiometer1;       // ADC value
    uint16_t potentiometer2;       // ADC value
    uint16_t potentiometer3;       // ADC value
    uint16_t crc16;                // CCITT CRC
    uint8_t  trailer;              // 0xFF
} ETHERNET_PACKET_t;
#pragma pack()
```

---

## 4. RASPBERRY PI APPLICATION PROTOCOL

### Socket Server Details
```
Listening Address:  0.0.0.0 (any interface)
Listening Port:     5000
Protocol:           TCP/IPv4
Connection Type:    Accept multiple clients (broadcast mode)
Max Clients:        10 (configurable)

Thread Model:       Single-threaded async OR multi-threaded
Timeout (idle):     30 seconds (close connection if no activity)
Buffer Size:        1024 bytes (ring buffer for packet reassembly)
```

### Data Reception State Machine
```
IDLE
├─ Wait for incoming connection
│  ↓
LISTENING
├─ Accept client connection
├─ Store client socket + timestamp
│  ↓
RECEIVING
├─ Read bytes until frame complete
│  ├─ Validate header (0xAA 0x55)
│  ├─ Validate length field
│  ├─ Validate trailer (0xFF)
│  ├─ Verify CRC16
│  └─ If valid → PROCESSING
│  └─ If invalid → INVALID_FRAME (log + skip)
│  ↓
PROCESSING
├─ Extract sensor values
├─ Update UI in real-time
├─ Store in database
├─ Update statistics (min/max/avg)
│  ↓
IDLE (wait for next packet)

CLIENT_DISCONNECT
├─ Detected on recv() = 0 or timeout
├─ Close socket
├─ Remove from client list
└─ Return to IDLE
```

### Sensor Data Mapping
```
Received CAN Frame ──→ Ethernet Packet ──→ Raspberry Pi Storage

Button State (16-bit):
└─ 12 buttons represented as individual boolean values
   UI: 3x4 grid of buttons showing pressed/released state

Potentiometer 1-3 (16-bit each, 0-65535):
└─ Mapped to percentage: (value / 65535) * 100
   UI: Displayed as:
   ├─ Percentage value (0-100%)
   ├─ Analog gauge (visual bar)
   └─ Numerical display (0-65535)
```

---

## 5. FIRMWARE CONFIGURATION CONSTANTS

### STM32 #1 Firmware
```c
// CAN Configuration
#define CAN_BAUDRATE           250000      // 250 kbps
#define CAN_MESSAGE_ID         0x100       // Sensor data
#define CAN_TX_PERIOD_MS       100         // 10 Hz

// Task Timing
#define KEYPAD_SCAN_PERIOD_MS  100         // Scan every 100ms
#define ADC_SAMPLE_PERIOD_MS   50          // Sample every 50ms
#define DEBOUNCE_TIME_MS       20          // 20ms debounce

// ADC Filtering
#define ADC_SAMPLE_COUNT       5           // 5-point rolling average
#define ADC_SCALE_FACTOR       (65535/4095)  // 12-bit → 16-bit scaling

// UART Debug
#define DEBUG_BAUDRATE         115200      // 115.2 kbps
#define DEBUG_ENABLED          1           // Enable/disable debug output
```

### STM32 #2 Firmware
```c
// CAN Configuration
#define CAN_BAUDRATE           250000      // Must match STM32 #1
#define CAN_RX_MESSAGE_ID      0x100       // Listen for sensor data

// W5500 Configuration
#define W5500_MAC_ADDR         {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF}
#define W5500_IP_ADDR          {192, 168, 1, 100}
#define W5500_SUBNET           {255, 255, 255, 0}
#define W5500_GATEWAY          {192, 168, 1, 1}
#define W5500_PORT             5000

// SPI Configuration
#define W5500_SPI_BAUDRATE     2000000     // 2 MHz (W5500 supports up to 80 MHz)
#define W5500_SPI_CPOL         0
#define W5500_SPI_CPHA         0

// Ethernet TX Rate
#define ETH_TX_PERIOD_MS       100         // 10 Hz (synchronized with CAN)
#define ETH_TX_RETRY_MAX       3           // Retry 3 times on fail

// UART Debug
#define DEBUG_BAUDRATE         115200
#define DEBUG_ENABLED          1
```

### Raspberry Pi Application
```python
# Configuration
SERVER_HOST = '0.0.0.0'
SERVER_PORT = 5000
MAX_CLIENTS = 10
BUFFER_SIZE = 1024
CLIENT_TIMEOUT = 30  # seconds
PACKET_TIMEOUT = 500  # milliseconds

# Packet Constants
SYNC_BYTE_1 = 0xAA
SYNC_BYTE_2 = 0x55
TRAILER_BYTE = 0xFF
EXPECTED_PAYLOAD_LENGTH = 10

# Data Display
BUTTON_GRID = 3  # rows
BUTTON_COLS = 4  # columns
POT_DISPLAY_TYPE = 'gauge'  # or 'percentage'
```

---

## 6. TESTING & VALIDATION CHECKLIST

### STM32 #1 Unit Tests
```
[ ] Keypad Detection
    ├─ [ ] Each button registers when pressed
    ├─ [ ] No false triggers
    └─ [ ] Debouncing prevents bouncing

[ ] LED Control
    ├─ [ ] All 8 LEDs turn on/off independently
    ├─ [ ] Shift register responds to commands
    └─ [ ] PWM dimming works (if implemented)

[ ] ADC Reading
    ├─ [ ] ADC reads correct voltage ranges
    ├─ [ ] Filtering smooths noisy readings
    └─ [ ] Calibration is accurate

[ ] CAN Transmission
    ├─ [ ] Frames transmitted at 100ms interval
    ├─ [ ] CRC is correct
    └─ [ ] STM32 #2 receives all frames
```

### STM32 #2 Integration Tests
```
[ ] CAN Reception
    ├─ [ ] Receives frames from STM32 #1
    ├─ [ ] Filters out invalid frames
    └─ [ ] No missed frames in 10-minute test

[ ] W5500 Communication
    ├─ [ ] SPI handshake successful
    ├─ [ ] MAC address configurable
    ├─ [ ] IP address assigned
    └─ [ ] Ping response from Raspberry Pi

[ ] Data Forwarding
    ├─ [ ] Converts CAN frames to Ethernet packets
    ├─ [ ] Sends to port 5000
    └─ [ ] Multiple clients can connect
```

### Raspberry Pi System Tests
```
[ ] Socket Server
    ├─ [ ] Listens on port 5000
    ├─ [ ] Accepts incoming connections
    ├─ [ ] Receives packets correctly
    └─ [ ] Handles client disconnect gracefully

[ ] Data Parsing
    ├─ [ ] Validates packet header (0xAA 0x55)
    ├─ [ ] Rejects malformed packets
    ├─ [ ] Verifies CRC16
    └─ [ ] Extracts sensor values correctly

[ ] UI Display
    ├─ [ ] Button grid updates in real-time
    ├─ [ ] Potentiometer values display correctly
    ├─ [ ] Connection status indicator works
    └─ [ ] No UI lag with sustained data flow

[ ] Auto-Start
    ├─ [ ] Service starts on boot
    ├─ [ ] Restarts on crash
    ├─ [ ] Can be stopped/started manually
    └─ [ ] Log file creation works
```

---

## 7. DEBUGGING REFERENCE

### Common CAN Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| No CAN traffic | Pins not initialized | Verify GPIO config in CubeMX |
| Wrong baudrate | CAN baudrate mismatch | Both must be 250kbps |
| Frames received but corrupted | CRC errors | Check cable/termination (120Ω resistors) |
| Inconsistent frame arrival | Timing/task priority | Use proper FreeRTOS synchronization |

### Common W5500 Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| SPI not responding | CS pin logic | Verify active-low CS pulse |
| No network connectivity | IP/MAC config wrong | Re-initialize via SPI |
| Sporadic packet loss | Buffer overflow | Increase W5500 buffer size |
| High latency | SPI speed too low | Increase SPI clock to 2+ MHz |

### Common RPi App Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Server won't start | Port 5000 in use | Check: `sudo lsof -i :5000` |
| Packets not received | Firewall blocking | Disable firewall or allow port |
| Corrupted data | Byte order mismatch | Use big-endian for multi-byte values |
| Memory leak in service | Improper socket cleanup | Ensure close() called on disconnect |

---

**Last Updated**: 2026-04-20
**Version**: 1.0 - Initial Technical Specs
