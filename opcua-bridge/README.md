# Bricks OPC-UA Bridge — Setup Guide

## How the System Works

```
[Siemens S7-1500 PLC]           [This PC / Factory PC]        [Flutter App]
   OPC-UA Server         ──────▶   Node.js Bridge Server  ──────▶  Dashboard
   opc.tcp://...:4840    TCP       REST API :3001          HTTP     (polls /api/data)
```

The **bridge server** is the key: it speaks OPC-UA (binary TCP) to the PLC and
speaks HTTP REST to Flutter. Flutter **cannot** call OPC-UA directly.

---

## The Network Challenge

The PLC is at `192.168.0.1` on the **factory LAN**.  
The bridge server must be able to reach that IP.

### Option A — RUT200 Port Forwarding ⭐ (Recommended for dev PC)

Run the bridge on **your dev PC**, configure RUT200 to forward port 4840 through to the PLC.

**Step 1: Configure RUT200 Port Forward**
1. Connect to RUT200 admin panel (either on LAN or via its WAN IP)
2. Go to: **Network → Firewall → Port Forwards → Add**
3. Fill in:
   ```
   Name          : OPC-UA-Bridge
   Protocol      : TCP
   External Port : 4840
   Internal IP   : 192.168.0.1
   Internal Port : 4840
   ```
4. Click **Save & Apply**

**Step 2: Find RUT200's Public IP / DDNS**
- From your RMS data: WAN IP was `100.81.134.22` (may change with mobile data)
- **Better:** Enable DDNS on RUT200 → Services → Dynamic DNS
  - Get a free hostname like `bricks-factory.ddns.net`

**Step 3: Update `.env`**
```env
OPC_ENDPOINT=opc.tcp://100.81.134.22:4840
# Or with DDNS:
OPC_ENDPOINT=opc.tcp://bricks-factory.ddns.net:4840
```

**Step 4: Test and Run**
```powershell
# Test connection first
node test_connection.js opc.tcp://100.81.134.22:4840

# If test passes, start the server
node server.js
```

---

### Option B — Run Bridge on Factory PC + ngrok (Zero Config)

Run the bridge on **a PC that is already on the factory LAN** (same network as PLC).
Use ngrok to make it accessible from outside.

**Step 1: On the factory PC**
```bash
# Copy the opcua-bridge folder to the factory PC, then:
npm install
node server.js
# Bridge connects to 192.168.0.1:4840 locally — works immediately
```

**Step 2: Expose via ngrok** (in a second terminal on factory PC)
```bash
# Install ngrok: https://ngrok.com/download (free account)
ngrok http 3001
# Gives you: https://abc123.ngrok-free.app
```

**Step 3: Update Flutter `api_config.dart`**
```dart
static const String bridgeBaseUrl = 'https://abc123.ngrok-free.app';
```

**No router config needed. Works immediately.**  
Note: Free ngrok URL changes every restart — consider ngrok paid plan or a VPS.

---

### Option C — Connect Dev PC via VPN to Factory LAN

The RUT200 has a built-in VPN server (OpenVPN or WireGuard).

**Step 1: Set up VPN on RUT200**
1. RUT200 admin → Services → VPN → OpenVPN → Enable Server
2. Generate client config file
3. Import into OpenVPN client on your dev PC
4. Connect

**Step 2: Once VPN connected, factory LAN IP is accessible**
```env
OPC_ENDPOINT=opc.tcp://192.168.0.1:4840
```

```bash
node test_connection.js  # should work
node server.js
```

---

## Quick Start (once connectivity is set up)

```powershell
# Terminal 1 — Start bridge server
cd d:\demo-main\opcua-bridge
node server.js

# Terminal 2 — Test it's working
Invoke-RestMethod http://localhost:3001/api/data | ConvertTo-Json -Depth 3

# Terminal 3 — Run Flutter
cd d:\demo-main\demo-main
flutter run -d chrome
```

## Flutter API Config

Edit `lib/services/api_config.dart`:

| Scenario | bridgeBaseUrl value |
|---|---|
| Bridge on same PC as Flutter | `http://localhost:3001` |
| Bridge on another LAN PC | `http://192.168.x.x:3001` |
| Bridge exposed via ngrok | `https://abc123.ngrok-free.app` |
| Bridge on factory PC, Flutter on phone (same LAN) | `http://factory-pc-ip:3001` |

---

## Verify Data is Live

Open in browser: `http://localhost:3001/api/raw`

You should see actual values (not `null`) for each OPC-UA node once connected:
```json
{
  "systemTotalCycle": { "value": 1913, "label": "System Total Cycle" },
  "blockCount": { "value": 245, "label": "Block Count" },
  ...
}
```

When `plcConnected: true` and values are non-null, **Flutter dashboard shows real data**.
