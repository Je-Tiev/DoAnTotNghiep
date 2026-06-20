# Communication Protocols

## 1. CAN Protocol
The system uses the standard 11-bit CAN 2.0A frame format operating at 250 kbps.

### Transmitted Frames (STM32 #1 to STM32 #2)
#### Frame 0x100 (Control/Sensor Data)
- **Rate**: 10 Hz (100 ms)
- **DLC**: 8 Bytes
- **Byte 0-1**: Button State (16-bit bitmask, Bit 0-11 for buttons 1-12)
- **Byte 2-3**: Potentiometer 1 (16-bit unsigned, scaled 0-65535)
- **Byte 4-5**: Potentiometer 2 (16-bit unsigned, scaled 0-65535)
- **Byte 6-7**: Potentiometer 3 (16-bit unsigned, scaled 0-65535)

#### Frame 0x200 (Vehicle Sensor Data)
- **Rate**: 10 Hz (100 ms)
- *(Details expanded based on future implementation)*

## 2. Ethernet Protocol
The system uses a custom binary packet structure over TCP/UDP, sent from the STM32 #2 to the Raspberry Pi socket server.

### Ethernet Packet Format (16 Bytes)
- **Target**: `192.168.1.50:5000`
- **Byte 0**: Sync Byte 1 (`0xAA`)
- **Byte 1**: Sync Byte 2 (`0x55`)
- **Byte 2-3**: Payload Length (`10` in 16-bit big-endian)
- **Byte 4**: Sequence Number (`0-255`, increments)
- **Byte 5-6**: Button State (Matches CAN Byte 0-1)
- **Byte 7-8**: Potentiometer 1
- **Byte 9-10**: Potentiometer 2
- **Byte 11-12**: Potentiometer 3
- **Byte 13-14**: CRC16 (CCITT polynomial `0x1021`, covers bytes 0-12)
- **Byte 15**: Trailer (`0xFF`)