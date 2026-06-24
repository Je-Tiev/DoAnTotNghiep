---
name: w5500-ethernet
description: Work on the Gateway's W5500 Ethernet/TCP client — socket state machine, network config, and the 18-byte payload send. Use for connectivity, reconnection, or packet-format changes on STM32-2nd.
---

# W5500 Ethernet / TCP Client

Maintain the Gateway uplink: WIZnet W5500 over SPI1, TCP client to the Android server.

## When to use this skill
- Network config changes (IP/MAC/port, static→DHCP).
- Socket lifecycle / reconnection issues (`SOCK_*` states).
- Changing the TCP payload size or contents.

## How to use it
1. **Read first:** [`gateway_ecu.md`](../../../project_setup/architecture/gateway_ecu.md) §4 and [`system_topology.md`](../../../project_setup/architecture/system_topology.md).
2. **Roles are fixed:** Gateway = TCP **client**, Android = TCP **server** on `APP_IP:APP_PORT` (`192.168.1.100:5000`). Don't invert this.
3. **Config lives in** `STM32-2nd/Core/Inc/w5500_config.h` (`W5500_IP`, `W5500_MAC`, `APP_IP`, `APP_PORT`, `SOCKET_ID`). `APP_IP` must equal the RPi/phone IP.
4. **Driver/API:** `w5500_port.c` — `W5500_Init` (static `wiz_NetInfo`), `W5500_EnsureSocket` (non-blocking FSM: CLOSED→`socket`, INIT→`connect`, CLOSE_WAIT→`disconnect`, ESTABLISHED→ready), `W5500_SendData`→`send`. CS = PB12.
5. **Payload contract:** send raw `sizeof(VehicleState_t)` = 18 bytes, no app framing (TCP handles integrity — see D-010). If you change size, update `GatewayClient.PACKET_SIZE` and the parser too.
6. **Resilience pattern:** `Eth_SendTask` reopens the socket after 5 consecutive send failures (`close(SOCKET_ID)`). Keep `W5500_EnsureSocket` non-blocking so the task keeps draining the CAN queue.
7. Update `system_topology.md` / `gateway_ecu.md` after changes.
