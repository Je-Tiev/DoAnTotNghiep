# ClusterApp Architecture

The `ClusterApp` acts as the head unit and primary UI for the system, replacing the role of traditional physical dashboard gauges. It runs on an Android environment (specifically deployed on a Raspberry Pi or a compatible Android tablet).

## Key Components

### 1. Socket Server
- **Protocol**: TCP / UDP (port 5000).
- **Function**: Listens for incoming 16-byte binary packets from the Gateway Node (STM32 #2).
- **Data Parsing**: 
  - Validates sync bytes (`0xAA`, `0x55`).
  - Verifies CRC16 to discard corrupted packets.
  - Unpacks the payload into button states and potentiometer percentages.

### 2. User Interface
- **Framework**: Native Android UI (Java/Kotlin).
- **Data Display**:
  - 3x4 grid for button pressed/released states.
  - Gauges and percentages (0-100%) for potentiometer values.
  - Network connection status indicator.

### 3. Background Service
- Designed to start automatically and maintain the socket connection.
- Recovers gracefully from client disconnects and network timeouts.
