# Raspberry Pi 4 — Host Layer

> **Last updated:** 2026-06-22 (eth0 static 192.168.10.104, subnet riêng cho link Gateway — D-021)
> **Role: HARDWARE HOST.** The Raspberry Pi 4 is the head-unit device that **runs the Android ClusterApp**. There is **no separate Raspberry-Pi server process** in this repository — the TCP server and all state distribution live *inside* the Android app ([android_app.md](android_app.md)).

## 1. What the RPi actually does here

- Provides the display + Android runtime that hosts `ClusterApp`.
- Carries the network endpoint the Gateway connects to: the RPi's **eth0** IP is what `APP_IP` in `STM32-2nd/Core/Inc/w5500_config.h` must point at (`192.168.10.104:5000` — IP của interface mang gói, KHÔNG phải IP WiFi/wlan0). eth0 đặt **static** trong cùng subnet riêng `192.168.10.0/24` với Gateway; WiFi giữ `192.168.1.x` cho adb (D-021).
- That's it. No packet parsing, no socket code, no firmware lives at this layer — those belong to the Gateway ECU and the Android app respectively.

## 2. Why this doc exists / "state distributor" clarification

The original system concept described the RPi as a standalone "TCP server + state distributor" with Android as a thin display client. **The implemented design folds both roles into the Android app**: `GatewayClient` opens the `ServerSocket`, and `ClusterController` holds the latest `VehicleState` and pushes it to the UI. The RPi simply runs that app.

If a separate RPi-side service (e.g. a Python broker re-distributing to multiple clients) is ever added, document it here and update [integration.md](integration.md) and [system_topology.md](system_topology.md). Until then, treat this layer as **host-only**.

## 3. Configuration checklist (host setup)

| Item | Where | Note |
|------|-------|------|
| RPi eth0 IP (data) | Android Ethernet settings → **Static** (hoặc `adb shell su -c "ip addr add 192.168.10.104/24 dev eth0"`) | Phải khớp `APP_IP`; là interface nối thẳng W5500 |
| Same subnet as Gateway | `192.168.10.0/24` (riêng, tách WiFi) | Gateway is `192.168.10.50` |
| WiFi/wlan0 (adb) | `192.168.1.x` | Chỉ cho adb/logcat — KHÔNG phải đích TCP |
| Android runtime | RPi (Android-on-RPi) running ClusterApp | App binds `0.0.0.0:5000` (mọi interface) |
| Firewall | allow inbound TCP `5000` | Gateway is the connecting client |
