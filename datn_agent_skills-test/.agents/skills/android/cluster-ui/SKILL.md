---
name: cluster-ui
description: Work on the Android ClusterApp — TCP packet parsing, VehicleState model, derived warnings, and GaugeView/indicator rendering. Use for any change in ClusterApp/.
---

# Cluster UI (Android)

Maintain the display layer: `CarClusterApp` (Java, Android SDK min 24 / target 36).

## When to use this skill
- Changing how the 18-byte packet is parsed or scaled.
- Adding/adjusting gauges, icons, warnings, or animations.
- Touching the TCP server, service resilience, or the `VehicleState` model.

## How to use it
1. **Read first:** [`android_app.md`](../../../project_setup/architecture/android_app.md) and [`vehicle_state.md`](../../../project_setup/architecture/vehicle_state.md).
2. **Display-only rule:** the app never sends commands upstream and is not a source of truth. New "warnings" that aren't on the wire are derived in `ClusterController` (engine/brake/oil/temp pattern).
3. **Packet parsing** is in `controller/ClusterController.java::applyGatewayPacket` — little-endian, fixed 18-byte offsets. If the gateway struct changes, update offsets AND `GatewayClient.PACKET_SIZE` together.
4. **Threading:** packets arrive on `TCP_Recv_Thread`; UI updates must hop to the main thread (`mainHandler.post`). Keep the model single-writer (network) / single-reader (UI).
5. **Network:** app is the TCP **server** (`GatewayClient` `ServerSocket :5000`), kept alive by `SocketService` (foreground, START_STICKY) + `BootReceiver` + `WatchdogReceiver`. Preserve this resilience chain.
6. **Rendering:** gauges in `ui/view/GaugeView.java`; normalize via `VehicleState.speedNorm()/rpmNorm()`. Use `adb am start -n com.example.carclusterapp/.ui.DebugActivity` for live diagnostics.
7. Update `android_app.md` after UI/parse/model changes.
