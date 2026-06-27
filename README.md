# 🅿️ rde_parking

🔥 PROXIMITY-LOADED PARKING & LOCK SYSTEM V1.1.1 — Built on ox_core & Statebags! 🅿️

[![Version](https://img.shields.io/badge/version-1.1.1-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking/blob/main/LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/Framework-ox__core-blue?style=for-the-badge)](https://github.com/overextended/ox_core)
[![Nostr](https://img.shields.io/badge/Nostr-Decentralized-purple?style=for-the-badge)](https://github.com/RedDragonElite/rde_nostr_log)
[![Price](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)
[![Ecosystem](https://img.shields.io/badge/RDE%20Ecosystem-rde__carservice-orange?style=for-the-badge)](https://github.com/RedDragonElite/rde_carservice)

**Proximity-streamed vehicle parking, statebag-synced locking, full property persistence, zero-entity-bloat performance — and fully integrated with `rde_carservice` as part of the RDE ecosystem.**

> Built on ox_core · ox_lib · ox_target · oxmysql
>
> Built by Red Dragon Elite | SerpentsByte

> 🤝 **RDE Ecosystem:** `rde_parking` and [`rde_carservice`](https://github.com/RedDragonElite/rde_carservice) are designed to work together. Park a vehicle — call carservice — it auto-unparks and delivers it to you. Pick it up via carservice — the parking entry is gone. Deliver it back — you can park it again. Two scripts, one coherent system, zero conflicts.

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Why RDE Parking?](#-why-rde-parking)
- [Features](#-features)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage & Controls](#-usage--controls)
- [Architecture](#-architecture)
- [rde_carservice Integration](#-rde_carservice-integration)
- [Developer API](#-developer-api)
- [Security](#-security)
- [Commands](#-commands)
- [Database](#-database)
- [Performance](#-performance)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🎯 Overview

RDE Parking is a production-grade parking and vehicle-lock system for FiveM servers. Server-side proximity streaming, full statebag synchronization for both lock state and vehicle mods, ox_target interaction, persistent MySQL storage, server-validated ownership on every action, and optional decentralized Nostr logging — **free forever**.

v1.1.1 fixes two silent bugs in how the `vehicles.stored` column was written, and completes the bidirectional integration with `rde_carservice` that makes both scripts operate as a single coherent system. Call carservice on a parked vehicle — the parking entry clears automatically, the entity despawns via the proximity system, and the NPC driver brings the car to you. Pick it up via carservice — the parking row is gone. Get it delivered — the ox_target options reset instantly so you can park it again. **Two scripts, one ecosystem.**

---

## 🔥 Why RDE Parking?

| Other Parking Scripts | ✅ RDE Parking |
|---|---|
| Every parked car spawns at boot, forever | Proximity-streamed — spawns only near players, despawns when empty |
| Client trusts its own plate/netId for locking | Server-side owner verification on every lock/unlock |
| Vehicle mods only visible to whoever parked it | Statebag + broadcast sync — every nearby player sees correct mods |
| Polling loops checking distance every frame | Throttled server sweep (default 5s), statebag-driven client reactions |
| Single TriggerClientEvent spaghetti | One sync path per state change — no double broadcast |
| ESX / QBCore bloat | ox_core only — the future, not the past |
| Discord webhooks for logs (deletable, bannable) | Optional decentralized Nostr logging — permanent & uncensorable |
| Silently conflicts with delivery scripts | Full rde_carservice integration — cross-event sync, zero conflicts |
| Paid or locked down | 100% free forever — RDE Black Flag |

---

## ✨ Features

### 🅿️ Parking & Retrieval

- **ox_target driven** — park, retrieve, lock and unlock all through context interaction, no keybind hell
- Engine-off requirement and minimum body-health threshold before a vehicle can be parked (both configurable)
- Full property capture on park via `lib.getVehicleProperties()` — mods, paint, livery, damage, fuel, everything
- **Auto-retrieve on engine start** — get back in a parked vehicle and start the engine, it unparks itself automatically
- Vehicle-class blacklist (boats, trains, etc. excluded from parking by default)

### 📡 Proximity Loading (RDE OX Standards v2)

- Parked vehicles are **NOT** all spawned at once — a throttled server thread (`RunProximitySweep`, default every 5s) spawns a vehicle only once a player comes within `Config.SpawnDistance`
- Despawns again after a grace period once nobody has been nearby — the database row is untouched, the vehicle simply respawns the moment someone gets close again
- Despawn radius uses a hysteresis multiplier over the spawn radius to avoid pop-in/pop-out flicker at the boundary
- A lightweight in-memory index (coords/plate/locked only — no props) drives the sweep; full vehicle properties are only pulled from the database the instant a vehicle actually spawns

### 🔄 Statebag Sync

- Lock state and vehicle properties both sync through prefixed entity statebags (`rde_parking_*`) — single source of truth, no parallel `TriggerClientEvent` for the same data
- Late joiners and players streaming a vehicle in from far away still receive correct mods/paint/lock state automatically via the statebag, not just whoever was online at spawn time
- `GlobalState.rde_parking_active` and `GlobalState.rde_parking_spawned_count` expose a lightweight public view (plate/coords/locked only) for other resources — HUD, minimap, admin tools — with zero callback roundtrip

### 🔗 rde_carservice Integration

- Bidirectional event sync with `rde_carservice` (v1.1.0+) — see [rde_carservice Integration](#-rde_carservice-integration)
- Parking a vehicle marks it as `stored = 'rde_parking'` — carservice explicitly excludes this value, preventing duplicate-entity delivery bugs
- When carservice delivers or picks up a vehicle, parking state is cleared on both server and client automatically

### 🛡️ Security

- Server-side ownership verification on every park, lock, and unlock action against the `vehicles` table — never trusts the client's plate or netId blindly
- Per-player parking lock to prevent concurrent park-spam from the same source
- Server- and client-side lock/unlock cooldown

### 🐉 Optional Nostr Logging

- Park and retrieve events logged to `rde_nostr_log` if present — decentralized, uncensorable, zero config required if the resource isn't installed

### 🌍 Multilanguage

- Full **English & German** out of the box via `Config.Locales` — add a language by copying one block

---

## 📦 Dependencies

| Resource | Required | Notes |
|---|---|---|
| `oxmysql` | ✅ Required | Database layer |
| `ox_core` | ✅ Required | Player/character framework, vehicle ownership |
| `ox_lib` | ✅ Required | Progress bars, notifications, callbacks, vehicle property get/set |
| `ox_target` | ✅ Required | All park/retrieve/lock/unlock interactions |
| `rde_carservice` | ⭕ Optional | Cross-event integration, runs fine without it |
| `rde_nostr_log` | ⭕ Optional | Decentralized event logging — runs fine without it |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_parking.git
```

### 2. Add to server.cfg

```
ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_target
ensure rde_parking

# Optional — install before rde_parking if you want decentralized logging
ensure rde_nostr_log

# Optional — install alongside rde_parking for full delivery/pickup integration
ensure rde_carservice
```

> ⚠️ Order matters. `rde_parking` must start **after** all its dependencies.

### 3. Database

The `rde_parked_vehicles` table is created automatically on first start. No manual SQL import needed.

### 4. Configure (Optional)

Edit `config.lua` to adjust distances, cooldowns, proximity sweep behavior, and language.

### 5. Restart

```
restart rde_parking
```

Test by parking a vehicle with `/parkingstats` open in another window to watch the counters move.

---

## ⚙️ Configuration

### Core

```lua
Config.Locale = 'en' -- 'en' or 'de'
Config.Debug = false -- verbose console output, set false for live servers

Config.AutoDeleteParkedVehicles = true
Config.AutoDeleteAfterDays = 7 -- 0 = disabled
```

### Distances (metres)

```lua
Config.ParkDistance = 5.0    -- max distance to park from vehicle
Config.LockDistance = 10.0   -- max distance for lock/unlock interaction
Config.SpawnDistance = 150.0 -- proximity radius: vehicles only spawn when a player is within this range
```

### Vehicle Rules

```lua
Config.RequireEngineOff = true    -- engine must be off before parking
Config.MinHealthToPark = 100.0    -- minimum body health to allow parking

Config.BlacklistedClasses = {
    [14] = true, -- 🚤 Boats
    [21] = true, -- 🚂 Trains
}
```

### Cooldowns & Durations (ms)

```lua
Config.ParkDuration = 3000  -- progress bar duration when parking
Config.LockDuration = 800   -- progress bar duration when locking/unlocking

Config.ParkCooldown = 3000
Config.LockCooldown = 1000  -- enforced BOTH client- and server-side
```

### Proximity Loading

```lua
Config.Performance = {
    proximityCheckInterval = 5000,  -- ms between server-side proximity sweeps
    proximityDespawnEnabled = true, -- despawn vehicles nobody is near
    despawnDistanceMultiplier = 1.5,-- despawn radius = SpawnDistance * this (hysteresis)
    despawnGraceMs = 30000,         -- ms with nobody nearby before despawning
}
```

### Sound & Visual FX

```lua
Config.EnableHornFlash = true -- blink lights on lock/unlock
Config.FlashCount = 2
Config.FlashDelay = 200 -- ms between flashes

Config.ParkSound   = { enabled = true, audioName = 'CONFIRM_BEEP', audioRef = 'HUD_MINI_GAME_SOUNDSET' }
Config.UnparkSound = { enabled = true, audioName = 'DOOR_OPEN',    audioRef = 'GTAO_FM_EVENTS_SOUNDSET' }
```

> **Note on `Config.SaveDamage` / `Config.SaveMods` / `Config.SaveFuel`:** These flags exist in the config but aren't individually wired up yet — `lib.getVehicleProperties()` always captures the full property set regardless. They're reserved for a future selective-persistence pass.

---

## 🎮 Usage & Controls

Everything runs through **ox_target** — there is no keybind system.

| Situation | ox_target Option |
|---|---|
| Standing near your own unlocked vehicle | 🔒 Lock Vehicle |
| Standing near your own locked vehicle | 🔓 Unlock Vehicle |
| In your own vehicle, engine off, not yet parked | 🅿️ Park Vehicle |
| Standing near your own parked vehicle | 🚗 Retrieve Vehicle |
| Get in a parked vehicle and start the engine | Auto-retrieves — no interaction needed |

---

## 🏗️ Architecture

```
rde_parking/
├── fxmanifest.lua
├── config.lua          ← Config + Config.Locales (en/de)
├── server/
│   └── main.lua        ← proximity sweep, callbacks, statebag writes, GlobalState
└── client/
    └── main.lua        ← ox_target interactions, statebag handlers, FX
```

### Proximity Loading

A server thread (`RunProximitySweep`, default every 5s via `Config.Performance.proximityCheckInterval`) compares every online player's position against a lightweight in-memory `parkIndex` — coordinates only, never full properties. Vehicles within `Config.SpawnDistance` of any player get spawned; vehicles nobody has been within `despawnDistanceMultiplier × SpawnDistance` of for `despawnGraceMs` get despawned. The database row is the permanent source of truth — spawning and despawning only ever touch the in-world entity.

The sweep also runs immediately whenever a player finishes loading (`ox:playerLoaded`), and once on resource start to catch any players already connected through a resource restart.

### Statebags (RDE OX Standards v2)

Every entity statebag this resource sets is prefixed with `Config.StatebagPrefix` (`rde_parking_`):

| Key | Meaning |
|---|---|
| `rde_parking_parked` | Vehicle is flagged as parked |
| `rde_parking_vehicleId` | ox_core vehicle ID |
| `rde_parking_plate` | License plate |
| `rde_parking_locked` | Current lock state — the only sync path for lock/unlock |
| `rde_parking_props` | Full vehicle properties — ensures late-joining players see correct mods |
| `rde_parking_owner` | Owning character's charId |

### `vehicles.stored` Semantic (v1.1.1)

rde_parking writes `stored = 'rde_parking'` when a vehicle is parked in the world via this system. This is intentional and load-bearing:

- `stored IS NULL` → vehicle is freely in the world, not managed by any parking system
- `stored = 'rde_parking'` → vehicle is in the world AND under rde_parking's management
- `stored = 'some_garage'` → vehicle is in a garage (not in the world at all)

rde_carservice reads this value and explicitly excludes `stored = 'rde_parking'` from its delivery queries. This prevents the delivery-of-a-live-parked-entity bug that previously caused duplicate vehicles and disappearing parking spots.

---

## 🔗 rde_carservice Integration

rde_parking v1.1.1 introduces full bidirectional integration with `rde_carservice` (requires `rde_carservice` v1.1.0+). Both resources are optional to each other — if either isn't running, the other degrades gracefully with no errors.

### The Problem It Solves

Without integration, two silent bugs existed:

**Bug 1 — Duplicate entity / disappearing parked vehicle:** When a vehicle was parked via rde_parking (`stored = 'parked'`), carservice interpreted `stored IS NOT NULL` as "in a garage" and spawned a *second* entity for the same plate. GTA deleted one of them, causing the parked vehicle to vanish.

**Bug 2 — "Not your vehicle" after delivery:** After carservice delivered a vehicle, the client's `parkedCache[plate]` was still `true` from the previous parking session. `IsParkedLocally()` returned `true`, blocking `ParkVehicle()` silently. The Park option disappeared from ox_target; the player saw Retrieve instead — and nothing worked.

### How It Works

```
Park via rde_parking
  └─ UPDATE vehicles SET stored = 'rde_parking'

Carservice Delivery of a PARKED vehicle (auto-unpark)
  └─ requestDelivery: plate found in rde_parked_vehicles → auto-unpark delivery
  └─ TriggerEvent('rde_carservice:prepareDeliveryOfParked', src, plate)
  └─ rde_parking server:
       ├─ DELETE FROM rde_parked_vehicles WHERE plate = ?   (no re-spawn)
       ├─ State.parkIndex[id] = nil                          (removed from spawn candidates)
       ├─ State.spawnedVehicles[id] kept → entity alive, proximity despawn handles it
       └─ TriggerClientEvent('rde_parking:clearParkedCache', src, plate)
  └─ rde_parking client: State.parkedCache[plate] = nil  ✅ player can park after delivery
  └─ UPDATE vehicles SET stored = NULL → NPC driver delivers car to player ✅
  └─ Entity at parking spot: auto-despawned after despawnGraceMs when nobody nearby

Carservice Delivery from GARAGE (normal flow)
  └─ SQL AND stored != 'rde_parking' → only real garage vehicles ✅

Carservice Pickup (world → garage)
  └─ completePickup: TriggerEvent('rde_carservice:vehiclePickedUp', src, plate)
  └─ rde_parking server: ClearParkedByPlate(plate)
       └─ removes stale rde_parked_vehicles row → proximity sweep won't respawn it ✅
```

### Integration Checklist

| | Check |
|---|---|
| `rde_parking` ≥ v1.1.1 | ✅ This release |
| `rde_carservice` ≥ v1.1.0 | Required for the carservice side of the events |
| Both resources in `server.cfg` | Order between them doesn't matter — events fire only when both are running |
| No config changes needed | Integration is automatic, zero config |

---

## 🔧 Developer API

### Server Events (listen from other resources)

```lua
-- fired by rde_carservice BEFORE delivery when vehicle is parked in world
-- rde_parking clears DB + parkIndex + notifies client cache
-- entity stays alive and is despawned naturally by the proximity system
AddEventHandler('rde_carservice:prepareDeliveryOfParked', function(source, plate) ... end)

-- fired by rde_carservice after successful delivery (garage → world)
AddEventHandler('rde_carservice:vehicleDelivered', function(source, plate) ... end)

-- fired by rde_carservice after successful pickup (world → garage)
AddEventHandler('rde_carservice:vehiclePickedUp', function(source, plate) ... end)
```

### Server Functions (call from other resources)

```lua
-- Force a full reload of the parking index + an immediate proximity sweep
-- (also exposed as /parkingreload)
LoadParkingIndex()
RunProximitySweep()

-- Publish the public GlobalState view manually after an external change
PublishParkingState()
```

### GlobalState Reads (any resource, any side)

```lua
local active  = GlobalState.rde_parking_active         -- { [vehicleId] = { plate, coords, locked } }
local spawned = GlobalState.rde_parking_spawned_count  -- number: currently spawned (nearby) vehicles
```

### Client Events

```lua
-- Fired by the server after a vehicle spawns (broadcast to ALL clients, not just one)
RegisterNetEvent('rde_parking:applyVehicleProps', function(netId, props) ... end)

-- Fired after a successful manual unpark
RegisterNetEvent('rde_parking:vehicleUnparked', function(plate) ... end)

-- Fired by the server when carservice clears a vehicle's parked state
-- Clears parkedCache[plate] so the player can park the delivered vehicle again
RegisterNetEvent('rde_parking:clearParkedCache', function(plate) ... end)
```

---

## 🛡️ Security

The v1.1.0 RDE OX Standards audit caught and fixed two production-relevant bugs from the original release:

**1. Missing ownership check on lock sync.**
Previously, any client could call the lock-sync event with an arbitrary plate/netId and lock or unlock any vehicle on the server. Now every lock/unlock request is verified server-side against `vehicles.owner` before anything happens, with a cooldown on top.

**2. Vehicle props only broadcast to one client.**
Mods and paint were only sent to whoever's client triggered the spawn. Props are now broadcast to all connected clients and written to the entity statebag, so anyone streaming the vehicle in later receives the correct appearance automatically.

v1.1.1 adds:

**3. `setStored` despawn bug.**
`oxVeh:setStored('parked', true)` with `despawn=true` could silently delete the parked entity if ox_core happened to track it. Replaced with a direct `MySQL.update` that writes `stored = 'rde_parking'` with no entity side effects.

**Baseline security model:**

- Every park, lock, and unlock action is verified server-side against the `vehicles` table
- Per-player parking lock prevents concurrent park-spam from a single source
- Lock/unlock cooldown enforced on both client and server
- Single statebag sync path per state change — no parallel `TriggerClientEvent` for the same data

---

## 📋 Commands

**Admin** (restricted = `group.admin`)

| Command | Description |
|---|---|
| `/parkingstats` | Show spawned (nearby) / indexed (total) / DB parked counts |
| `/parkingreload` | Reload the parking index from the database and re-run the proximity sweep |
| `/parkingcleanup` | Delete vehicles older than `Config.AutoDeleteAfterDays` |

---

## 🗄️ Database

Table is auto-created on first start:

```sql
CREATE TABLE rde_parked_vehicles (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT NOT NULL UNIQUE,
    plate      VARCHAR(20) NOT NULL,
    coords     TEXT NOT NULL,
    heading    FLOAT NOT NULL,
    props      LONGTEXT NOT NULL,
    locked     TINYINT(1) DEFAULT 0,
    parked_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vehicle_id (vehicle_id),
    INDEX idx_plate      (plate),
    INDEX idx_parked_at  (parked_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> Schema is **unchanged** from v1.0.0 — no migration step required when upgrading.

---

## ⚡ Performance

### Architecture

Parked vehicles only exist as world entities while a player is actually within range. The proximity sweep keeps entity count proportional to where players currently are, not to the total size of the `rde_parked_vehicles` table — a server with thousands of parked vehicles spread across the map costs roughly the same as one with a hundred, as long as players aren't standing next to all of them at once.

The lightweight in-memory index that drives the sweep holds only plate/coordinates/heading/locked/owner — never the full property blob, which is only pulled from the database at the exact moment a vehicle is about to spawn.

### Optimization Tips

- Raise `proximityCheckInterval` on servers with very large parked-vehicle counts to reduce sweep frequency
- Lower `despawnGraceMs` if you want vehicles to clear out of memory faster in high-traffic areas
- `despawnDistanceMultiplier` should stay above `1.0` — a value too close to `SpawnDistance` causes pop-in/pop-out flicker right at the boundary

---

## 🐛 Troubleshooting

**Parked vehicles don't appear when I get close?**
Run `/parkingreload` in console. If they still don't show up, confirm `oxmysql` is fully started before `rde_parking` — check the ensure order in `server.cfg`.

**Vehicle mods/paint not showing for other players?**
Confirm you're on v1.1.0+. Props now broadcast to all clients and sync via the `rde_parking_props` statebag.

**Lock/unlock does nothing?**
Check the cooldown — `Config.LockCooldown` is enforced on both client and server. Also confirm the vehicle is owned by your character; ownership is verified server-side.

**"No permission" on admin commands?**
Admin commands use `lib.addCommand` with `restricted = 'group.admin'` — verify your ox_core group via your permissions setup.

**After carservice delivery, can't park the delivered vehicle?**
Ensure both `rde_parking` ≥ v1.1.1 and `rde_carservice` ≥ v1.1.0 are installed. The cross-event integration (`rde_parking:clearParkedCache`) must fire to reset the client cache.

**Parked vehicle disappears when calling carservice delivery?**
Same as above — this was the duplicate-entity bug fixed in v1.1.1 via the `stored = 'rde_parking'` semantic + carservice exclusion query.

**Nostr logger not connecting?**
`rde_nostr_log` isn't installed — expected and harmless. Install it and ensure it before `rde_parking` to enable decentralized logging.

---

## 📝 Changelog

### v1.1.1 — rde_carservice Integration + setStored Fix *(current)*

- 🔗 **rde_carservice integration** — full bidirectional event sync with `rde_carservice` v1.1.0+: auto-unpark delivery, pickup cleanup, client cache sync
- 🐛 **Fix:** `oxVeh:setStored('parked', true)` replaced with direct MySQL `UPDATE vehicles SET stored = 'rde_parking'` — eliminates silent entity despawn risk and uses a distinct, carservice-excluded stored value
- 🐛 **Fix:** `unparkVehicle` now uses direct MySQL `stored = NULL` for consistency
- 🐛 **Fix:** client `parkedCache[plate]` not cleared after carservice delivery → player could not re-park a delivered vehicle
- 🐛 **Fix:** stale `rde_parked_vehicles` row after carservice pickup → proximity sweep no longer respawns already-stored vehicles
- 🐛 **Fix:** `prepareDeliveryOfParked` handler deliberately avoids `DeleteEntity` — clears DB + parkIndex only, keeps `spawnedVehicles` entry so the existing proximity despawn system handles entity cleanup after `despawnGraceMs`. This prevents GTA entity handle recycling from invalidating the carservice delivery vehicle.
- ✨ `ClearParkedByPlate()` server helper — used by vehicleDelivered/vehiclePickedUp for pickup-path and post-delivery cleanup
- ✨ New server events listened: `rde_carservice:prepareDeliveryOfParked` / `rde_carservice:vehicleDelivered` / `rde_carservice:vehiclePickedUp`
- ✨ New client event: `rde_parking:clearParkedCache` (cross-resource state reset)
- 📦 No database schema changes — direct upgrade from v1.1.0, no migration needed

### v1.1.0 — RDE OX Standards v2 Overhaul

- ✨ **Proximity Loading** — vehicles spawn/despawn based on player distance instead of all spawning at boot
- ✨ GlobalState register (`rde_parking_active`, `rde_parking_spawned_count`) for external resources
- ✨ Prefixed, statebag-based lock & props synchronization — no double broadcast
- 🐛 **Fix:** missing ownership check on lock sync — any client could previously lock/unlock any vehicle
- 🐛 **Fix:** vehicle props only broadcast to one client instead of all nearby players
- 🔧 `fxmanifest.lua`: `/server:7290` dependency added (RDE Standard)
- 🔧 Database schema unchanged — no migration step needed

### v1.0.0 — Initial release

- ✨ ox_target driven park / retrieve / lock / unlock
- ✨ Full vehicle property persistence via `lib.getVehicleProperties()`
- ✨ Auto-retrieve on engine start
- ✨ EN / DE locales

---

## 📜 License

```
###################################################################################
# .:: RED DRAGON ELITE (RDE) - BLACK FLAG SOURCE LICENSE v6.66 ::.
# PROJECT: RDE_PARKING v1.1.1 (PROXIMITY-LOADED PARKING & LOCK SYSTEM)
# ARCHITECT: .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com
# ORIGIN: https://github.com/RedDragonElite
# WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS
#
# [ THE RULES OF THE GAME ]
#
# 1. // THE "FUCK GREED" PROTOCOL (FREE USE)
#    You are free to use, edit, and abuse this code on your server.
#    Learn from it. Break it. Fix it. That is the hacker way.
#    Cost: 0.00€. If you paid for this, you got scammed by a rat.
#
# 2. // THE TEBEX KILL SWITCH (COMMERCIAL SUICIDE)
#    Listen closely, you parasites:
#    If I find this script on Tebex, Patreon, or in a paid "Premium Pack":
#    > I will DMCA your store into oblivion.
#    > I will publicly shame your community.
#    > I hope every parking spot you ever pull into is already taken.
#    SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.
#
# 3. // THE CREDIT OATH
#    Keep this header. If you remove my name, you admit you have no skill.
#    You can add "Edited by [YourName]", but never erase the original creator.
#    Don't be a skid. Respect the architecture.
#
# 4. // THE CURSE OF THE COPY-PASTE
#    This code uses statebags, proximity streaming, and a layered sync
#    architecture. If you just copy-paste without reading, it WILL break.
#    Don't come crying to my DMs. RTFM or learn to code.
#
# --------------------------------------------------------------------------
# "We build the future on the graves of paid resources."
# "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."
# --------------------------------------------------------------------------
###################################################################################
```

**TL;DR:**

- ✅ Free forever — use it, edit it, learn from it
- ✅ Keep the header — credit where it's due
- ❌ Don't sell it — commercial use = instant DMCA
- ❌ Don't be a skid — copy-paste without reading won't work anyway

---

## 🌐 Community & Support

| | |
|---|---|
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr (RDE) | RedDragonElite |
| 🔵 Nostr (Shin) | SerpentsByte |
| 🅿️ RDE Parking | [rde_parking](https://github.com/RedDragonElite/rde_parking) |
| 🚘 RDE Carservice | [rde_carservice](https://github.com/RedDragonElite/rde_carservice) |
| 🎮 RDE Props | [rde_props](https://github.com/RedDragonElite/rde_props) |
| 🚪 RDE Doors | [rde_doors](https://github.com/RedDragonElite/rde_doors) |
| 🚨 RDE AIPD | [rde_aipd](https://github.com/RedDragonElite/rde_aipd) |
| 📡 RDE Nostr Log | [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) |

When asking for help, always include:
- Full error from server console or txAdmin
- Your `server.cfg` resource start order
- ox_core / ox_lib versions in use

---

> *"We build the future on the graves of paid resources."*
>
> **REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

[![Website](https://img.shields.io/badge/Website-Visit-red?style=for-the-badge&logo=google-chrome)](https://rd-elite.com)
[![Nostr](https://img.shields.io/badge/Nostr-Follow-purple?style=for-the-badge&logo=rss)](https://primal.net/p/npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94)

🐉 *Made with 🔥 by Red Dragon Elite*

[⬆ Back to Top](#-rde_parking)
