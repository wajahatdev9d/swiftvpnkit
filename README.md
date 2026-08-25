# VPNKit

Self-contained iOS Swift Package for VPN — **OpenVPN**, **WireGuard**, **IKEv2**, and **IPSec**. No external SPM dependencies; Partout runtime is vendored inside this repo.

## Package size

| Component | Size |
|-----------|------|
| Swift sources (Partout + VPNKit) | ~1 MB |
| `PartoutNative.xcframework` (unpacked) | ~88 MB |
| License / metadata | ~36 KB |
| **Total repo on disk** | **~89 MB** |
| **Git clone zip (approx.)** | **~51 MB** |

### What actually ships in your app

| Slice | Size |
|-------|------|
| Device (`ios-arm64`) | ~11 MB |
| Simulator (`ios-arm64_x86_64-simulator`) | ~22 MB |

The xcframework also includes macOS and tvOS slices for completeness. Only the iOS slices link into an iPhone app.

> **Note:** Xcode creates a local `.build/` folder when resolving the package (~100+ MB). It is gitignored and safe to delete.

---

## Requirements

- iOS 16+
- Xcode 15+ / Swift 6
- Apple Developer account with **Network Extensions** capability
- Separate **Packet Tunnel Provider** app extension target (for OpenVPN / WireGuard)

---

## Installation

### 1. Add the package

**Xcode:** File → Add Package Dependencies → enter your repo URL.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_ORG/VPNKit.git", from: "1.0.0")
]
```

### 2. Link products to targets

| Target | Products |
|--------|----------|
| Main app | `VPNKit`, `VPNKitPersonal` |
| Packet Tunnel extension | `VPNKitTunnel` |

---

## Products

| Product | Use for |
|---------|---------|
| `VPNKit` | OpenVPN / WireGuard profile building, tunnel install, status |
| `VPNKitTunnel` | Subclass in your Network Extension |
| `VPNKitPersonal` | IKEv2 / IPSec via `NEVPNManager` (no extension needed) |

---

## Xcode setup

### Capabilities (main app + extension)

1. **Network Extensions** → Packet Tunnel
2. **App Groups** → e.g. `group.com.yourcompany.vpn`
3. **Keychain Sharing** (recommended for IKEv2 passwords)

### Info.plist keys (extension)

```xml
<key>PartoutAppGroupIdentifier</key>
<string>group.com.yourcompany.vpn</string>
<key>PartoutTunnelBundleIdentifier</key>
<string>com.yourcompany.vpn.tunnel</string>
```

### Entitlements (extension)

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>packet-tunnel-provider</string>
</array>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourcompany.vpn</string>
</array>
```

Use **one extension per protocol** if you support both OpenVPN and WireGuard (each needs its own bundle ID).

---

## OpenVPN / WireGuard

### 1. Packet Tunnel extension

```swift
import VPNKitTunnel

final class TunnelProvider: VPNPacketTunnelProvider {}
```

Set the extension’s principal class to `TunnelProvider`.

### 2. Configure factory

```swift
import VPNKit

let config = VPNKitConfig(
    tunnelBundleIdentifier: "com.yourcompany.vpn.openvpn",
    appGroupIdentifier: "group.com.yourcompany.vpn"
)
let factory = VPNTunnelFactory(config: config)
```

### 3. Build profile and connect

```swift
import PartoutRuntime

let input = VPNServerInput(
    title: "US Server",
    openvpnConfig: ovpnData,  // .ovpn file contents
    credentials: OpenVPN.Credentials(username: "user", password: "pass")
)

let profile = try VPNProfileBuilder.makeProfile(
    id: UUID(uuidString: "YOUR-STABLE-UUID")!,  // reuse same UUID to avoid duplicate Settings profiles
    name: "My VPN",
    input: input
)

let tunnel = try await factory.makeTunnel(
    tunnelBundleIdentifier: config.tunnelBundleIdentifier
)
await factory.saveProfile(profile)

let observer = VPNConnectionObserver(tunnel: tunnel)
try await observer.connect(profile)
```

### WireGuard

Same flow — pass `wireguardConfig:` instead of `openvpnConfig:`:

```swift
let input = VPNServerInput(
    title: "WG Server",
    wireguardConfig: wgConfData
)
```

### Status

```swift
let status = await observer.currentStatus

for await snapshots in observer.snapshotsStream() {
    // snapshots[profileID]?.status
}
```

Or post UI updates via `VPNNotification.postStatus(.connected)`.

### Disconnect

```swift
try await observer.disconnect(profile.id)
```

---

## IKEv2 / IPSec

Uses Apple’s built-in `NEVPNManager` — **no packet tunnel extension** required.

```swift
import VPNKitPersonal

// Optional: route logs to your logger
VPNKitLogger.handler = { level, message in
    print("[VPNKit] \(level): \(message)")
}

let manager = VPNPersonalManager.shared
manager.displayName = "My VPN"
manager.ikev2PasswordKeychainTag = "com.yourcompany.vpn.ikev2.password"
manager.delegate = self

// IKEv2
manager.credentials = VPNPersonalCredentials(
    kind: .ikev2,
    password: "secret",
    serverAddress: "vpn.example.com",
    userName: "user",
    remoteIdentifier: "vpn.example.com"
)

manager.connect { success in
    print("connect started: \(success)")
}
```

### IPSec

```swift
manager.credentials = VPNPersonalCredentials(
    kind: .ipsec,
    password: "userpass",
    sharedKey: "preshared-key",
    serverAddress: "vpn.example.com",
    userName: "user"
)
manager.connect { _ in }
```

### Delegate

```swift
extension MyViewController: VPNPersonalDelegate {
    func vpnPersonalConnecting() { }
    func vpnPersonalConnected() { }
    func vpnPersonalDisconnecting() { }
    func vpnPersonalDisconnected() { }
    func vpnPersonalInvalidConfig() { }
    func vpnPersonalReasserting() { }
}
```

### Disconnect

```swift
VPNPersonalManager.shared.disconnect()
```

---

## Stable profile IDs

iOS shows one VPN row per saved profile. Use **fixed UUIDs** per protocol so reconnects update the same Settings entry instead of creating duplicates:

```swift
let openVPNProfileID = UUID(uuidString: "7C4E8A1B-2D3F-4A5E-9B6C-1D2E3F4A5B6C")!
let wireGuardProfileID = UUID(uuidString: "8D5F9B2C-3E40-5B6F-0C7D-2E3F4A5B6C78")!
```

IKEv2/IPSec uses a single `NEVPNManager` profile — set `displayName` once and reuse it.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Host App                           │
│  VPNKit (OpenVPN/WG)    VPNKitPersonal (IKEv2/IPSec)    │
└────────────┬───────────────────────────┬────────────────┘
             │                           │
             ▼                           ▼
    NETunnelProviderManager      NEVPNManager.shared()
             │
             ▼
┌────────────────────────────┐
│  Packet Tunnel Extension   │
│  VPNKitTunnel subclass     │
│  → PartoutRuntime (native) │
└────────────────────────────┘
```

---

## Vendored Partout

This package vendors [Partout](https://github.com/partout-io/partout) **0.161.4**:

- `Sources/PartoutCore`, `PartoutCore_C`, `PartoutRuntime` — Swift/C sources
- `PartoutNative.xcframework` — OpenVPN / WireGuard native binary

See `Vendor/Partout-LICENSE-GPL-3.0.txt`. If you distribute apps using this package, comply with GPL-3.0 (source availability, license notice, etc.).

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Duplicate VPN profiles in Settings | Use stable profile UUIDs; call `seedProfiles` before install |
| First connect fails after “Allow VPN” | Built-in 750 ms settle + 3 retries in `VPNPersonalManager` |
| Extension can’t read profile | Match App Group in entitlements + `PartoutAppGroupIdentifier` plist key |
| OpenVPN connects but no traffic | Verify tunnel extension bundle ID matches `VPNKitConfig.tunnelBundleIdentifier` |

---

## License

VPNKit wrapper code: your project license.

Vendored Partout components: **GPL-3.0** — see `Vendor/Partout-LICENSE-GPL-3.0.txt`.
