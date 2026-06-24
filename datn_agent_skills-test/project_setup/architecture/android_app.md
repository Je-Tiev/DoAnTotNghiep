# Android App — ClusterApp (`CarClusterApp`)

> **Last updated:** 2026-06-22 (ADC scale 12-bit/4095; intro animation: overlap-center → slide-out → needle sweep)
> **Role: VISUALIZATION LAYER + TCP server.** Receives the 18-byte `VehicleState` snapshot, parses it, derives display-only warnings, and renders the digital cluster. It never sends commands back and is not a source of truth.

## 1. Stack & module layout

- Java, Android SDK **min 24 / target 36**, Gradle.
- Package root: `app/src/main/java/com/example/carclusterapp/`

| Area | Class | File |
|------|-------|------|
| Network (server) | `GatewayClient`, `SocketService` | `network/` |
| Control logic | `ClusterController` | `controller/ClusterController.java` |
| Model | `VehicleState` | `model/VehicleState.java` |
| UI | `ClusterActivity`, `SplashActivity`, `GaugeView`, `AnimationManager` | `ui/`, `ui/view/`, `ui/animation/` |
| Resilience | `BootReceiver`, `WatchdogReceiver` | `receiver/` |
| Debug/util | `DebugActivity`, `AppLogger`, `ConnectionStats` | `ui/`, `util/` |

## 2. Network — App is the TCP **server** (`network/GatewayClient.java`)

- `LISTEN_PORT = 5000`, `PACKET_SIZE = 18`.
- `serverLoop()`: `ServerSocket` binds `0.0.0.0:5000`, `accept()` blocks until the Gateway (W5500 client) connects; `setTcpNoDelay(true)`. Bind lỗi log riêng (`Bind error on port…`) tách khỏi accept/read lỗi để chẩn đoán port-busy.
- **`GatewayClient` = singleton phạm vi tiến trình** (`GatewayClient.get()`, ctor private) sở hữu sẵn 1 `ClusterController`. Cổng 5000 chỉ bind MỘT lần cho cả app, KHÔNG gắn vào Activity → tái tạo Activity không tạo serverLoop thứ hai đòi cổng (hết `EADDRINUSE`). `start()` có guard `if(running)return` nên idempotent.
- **Vòng đời server thuộc `SocketService`:** `onStartCommand`→`GatewayClient.get().start()`, `onDestroy`→`.stop()`. `ClusterActivity.onCreate` chỉ `startForegroundService(SocketService)` (đảm bảo service chạy) rồi render từ `GatewayClient.get().getController()` — Activity KHÔNG tự mở/đóng server nữa. Nếu gateway log `[ETH] socket not ready` mà `adb logcat -s GatewayClient` KHÔNG có `TCP server listening on port 5000` → service chưa start.
- `readFrames()`: `DataInputStream.readFully(buf, 0, 18)` gathers exactly one fixed 18-byte packet (handles TCP stream fragmentation), then calls `controller.applyGatewayPacket(buf)`.
- Receive thread `TCP_Recv_Thread` runs at `MAX_PRIORITY`; reconnect retry every 2 s.
- `SocketService` = foreground service (`START_STICKY`); `BootReceiver` auto-starts on boot; `WatchdogReceiver` resurrects a dead service. → survives Android process kills.

## 3. Packet parsing (`controller/ClusterController.java::applyGatewayPacket`)

18-byte little-endian layout (matches the gateway struct memory order — see [vehicle_state.md](vehicle_state.md)):

| Bytes | Field | Transform |
|-------|-------|-----------|
| 0..6 | turnL,turnR,hazard,highBeam,lowBeam,door,seatbelt | `!= 0` |
| 7 | gear | 0=P,1=R,2=N,3=D |
| 8 | driveMode | 0=ECO,1=SPORT,2=COMFORT,3=NORMAL |
| 9 | heat → `defrostOn` | `!= 0` |
| 10 | steer | `!= 0` |
| 11 | wind | `!= 0` |
| 12–13 | speed (u16 LE) | `/4095 * 240` → km/h |
| 14–15 | fuel (u16 LE) | `/4095` → 0..1 |
| 16–17 | rpm (u16 LE) | `/4095 * 8000` → RPM |

> ⚠️ Full-scale = **4095** (`ClusterController.ADC_FULL_SCALE`), KHÔNG phải 65535: Sensor gửi raw ADC 12-bit, không scale. Chia 65535 → gauge chỉ chạy 1/16 dải (max biến trở ≈ 15 km/h). Xem [vehicle_state.md](vehicle_state.md) D-023.

- `leftTurnOn/rightTurnOn = hazard || raw`; `fuelLowOn = fuel < 0.15`.

### Derived warnings (UI-only; not sent by firmware)
| Warning | Rule |
|---------|------|
| `engineCheckOn` | `rpm > 6500` |
| `breakOn` | deceleration `> 12` km/h per second between packets |
| `oilPressureOn` | `rpm < 500` AND `speed > 5` |
| `temperatureOn` | virtual heat model (load>0.6 heats up) crossing `0.85` |

- Turn-signal blink: 500 ms toggle via `mainHandler`. Needle motion eased with a 150 ms `ValueAnimator` (`DecelerateInterpolator`).

## 4. Model (`model/VehicleState.java`)

Plain POJO; written by the network thread, read by the UI thread. Helpers: `speedNorm()`/`rpmNorm()` (0..1 for `GaugeView`), `gearLabel()` (P/R/N/D), `driveModeLabel()`/`driveModeColor()`, `hasAnyWarning()`. Defaults include `odoKm = 12450.0` (persistent odometer concept).

## 5. UI

- `ClusterActivity` (immersive landscape) drives `GaugeView` (custom multi-layer `Canvas`: speed/rpm/fuel gauges, ticks, needle, color thresholds) plus turn/beam/comfort/warning icons, gear + drive-mode, clock, odometer.
- **Fullscreen + scale runtime:** `onCreate` bật immersive sticky (`WindowCompat` + `WindowInsetsControllerCompat`, ẩn `systemBars`, re-apply ở `onWindowFocusChanged`) + `FLAG_KEEP_SCREEN_ON`. 3 gauge KHÔNG còn kích thước dp cố định (260/290dp trong XML) mà được `scaleGauges()` set lại theo px thật của `gaugeContainer` trong `OnGlobalLayoutListener`: `base=min(H, 0.42·W)`, side`=0.9·base`, overlap`=0.19·side`. GaugeView.onDraw vẽ theo `getWidth/Height` nên tự co giãn — hợp mọi độ phân giải Pi (không cần `values-land`/`dimens.xml`). Xem [DECISIONS.md](DECISIONS.md) D-019.
- ⚠️ Icon top/warning để `alpha=0.2` khi tắt, **chỉ sáng khi có data** — nếu ETH chưa thông sẽ thấy "chỉ có 3 gauge"; đây là hành vi đúng, không phải bug layout.
- `SplashActivity` (2 s) → `ClusterActivity`. `AnimationManager.playIntro()` chạy intro ~3.3 s sau khi layout ổn định (gọi từ `gaugeContainer.post()` sau `scaleGauges()`): (1) 3 gauge fade-in CHỒNG NHAU ở tâm container, (2) gauge trái/phải trượt ra vị trí cố định bằng `translationX/Y` (center đứng yên), (3) cả 3 kim quét trọn 1 vòng `0→1→0` trong 2 s. Dùng translation trên view thật → không phụ thuộc độ phân giải. `ClusterActivity.updateUi()` chỉ set giá trị kim **live** sau khi `introAnimDone=true` (nếu không vòng 33ms ghi đè hiệu ứng quét). `onDestroy`→`animationManager.stop()`.
- `DebugActivity` (launch via `adb am start -n com.example.carclusterapp/.ui.DebugActivity`): live packet rate, last snapshot, CRC/error counters, log ring buffer; `AppLogger` mirrors to a rotating file.
