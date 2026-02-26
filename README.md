<div align="center">

# 🅿️ RDE Parking System

[![Version](https://img.shields.io/badge/version-1.0.0-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag-black?style=for-the-badge)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Exclusive-purple?style=for-the-badge)](https://github.com/communityox/ox_core)
[![FREE](https://img.shields.io/badge/price-FREE%20FOREVER-green?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)

**The most immersive, production-grade parking & car lock system ever built for FiveM.**  
Statebag-synced. ox_target powered. Zero stuck UI. Nostr-logged. Zero compromises.

![screenshot1](https://private-user-images.githubusercontent.com/57282916/555194010-2f80d0b2-e96d-4d50-a8cc-660bf980c109.png)
![screenshot2](https://private-user-images.githubusercontent.com/57282916/555193808-573712e2-c1b3-4bdc-aaad-53d371321946.png)
![screenshot3](https://private-user-images.githubusercontent.com/57282916/555249862-32aaa718-048f-475d-a866-99e1051c95da.png)

*Built by [Red Dragon Elite](https://rd-elite.com) | Free Forever | OX Ecosystem Exclusive*

[📖 Installation](#-installation) • [🎮 Features](#-features) • [⚙️ Configuration](#%EF%B8%8F-configuration) • [📡 Nostr Logging](#-nostr-logging) • [💬 Discord](https://discord.gg/rde)

---

</div>

## 🔥 Why This System Changes Everything

Every other parking script is either a bloated mess with stuck TextUI, broken animations, or Discord-only logging that gets rate-limited and deleted.  
This is what production-grade looks like.

| ❌ Other Scripts | ✅ RDE Parking System |
| --- | --- |
| **Stuck "[E] Lock" label** on screen forever | **ox_target** — labels show/hide automatically, zero stuck UI |
| **No animations** — nothing happens visually | **Key-fob + phone animations** — real feedback on every action |
| **Key conflicts** — [E] does five things at once | **ox_target interactions** — context-aware, no conflicts |
| **No statebag sync** — only the spawner sees it | **Statebag-first** — server-authoritative, synced to all |
| **Discord logging** — rate limited, censored, deletable | **Nostr logging** — decentralized, permanent, optional |
| **English only** | **EN / DE** built-in, easily extendable |
| **`RegisterCommand` with manual ACE checks** | **`lib.addCommand`** with `group.admin` — RDE standard |
| **Wrong lock label when already locked** | **Two separate targets** — correct icon & label always |
| **Vehicle disappears after parking** | **Vehicle stays in world** — locked in place, saved to DB |

---

## 🎯 Features

### 🎮 Gameplay
- **Park your vehicle** anywhere via ox_target — engine must be off, vehicle must be yours
- **Vehicle stays in the world** — parked in place, locked, persistent across restarts
- **Auto-retrieve on engine start** — get in your parked car, start the engine → automatically retrieved from DB, no manual step
- **Retrieve manually** via ox_target — removes DB entry, unlocks vehicle
- **Lock & unlock** via ox_target — separate entries with correct icons, double-beep + indicator flash, synced to all players
- **Auto-spawn on login** — your parked vehicles reappear exactly where you left them
- **Blacklist** — boats and trains can't be parked by default (configurable)

### 🎬 Animations
- **🔑 Lock / Unlock** — key-fob gesture (`mp_common` / `givetake1_b`, upper body only, flag 50) — character raises hand and presses the remote
- **📱 Park** — phone-check animation (`amb@world_human_stand_mobile`, upper body, flag 49) — character looks at their phone/keys confirming the spot
- All animations run exactly as long as the progress circle and are cleanly stopped on cancel or completion

### 🔊 Sound & Visual FX
- **Double-beep horn** on lock (350ms + pause + 200ms, loops every frame — correct GTA native usage)
- **Single pip** on unlock (150ms)
- **Hazard indicator flash** (`SetVehicleIndicatorLights`) — proper blinkers, not headlights
- **Other players** see and hear the effects too (synced via server event)

### 🏗️ Technical
- **ox_target powered** — no TextUI polling loops, no stuck labels, no key conflicts
- **Two separate lock/unlock targets** — `rde_parking_lock` shows when unlocked, `rde_parking_unlock` shows when locked — always correct icon and label
- **Statebag-first architecture** — `parked`, `locked`, `vehicleId`, `plate`, `owner` all on the entity
- **ox_core exclusive** — proper `Ox.GetPlayer` validation on every callback and event
- **ox_lib properties** — `lib.getVehicleProperties` / `lib.setVehicleProperties` for mods, fuel, damage
- **No async in canInteract** — `canInteract` fires every frame; uses instant local caches only, never DB calls
- **Parked cache** — client-side cache synced on login and updated immediately on park/unpark
- **Auto-delete scheduler** — removes vehicles older than N days automatically
- **Nostr logging** — optional, completely silent if `rde_nostr_log` isn't installed

### 🌐 Quality of Life
- **Multi-language** — EN / DE out of the box, add any language in 5 minutes
- **Fully configurable** — distances, durations, sounds, cooldowns, all in `config.lua`
- **Admin commands** — `/parkingstats`, `/parkingreload`, `/parkingcleanup`
- **Debug mode** — detailed console output with timestamps

---

## 📦 Dependencies

**Required:**
- [ox_core](https://github.com/communityox/ox_core) — Framework
- [ox_lib](https://github.com/communityox/ox_lib) — UI, progress, vehicle properties, animations
- [ox_target](https://github.com/communityox/ox_target) — Vehicle interaction system
- [oxmysql](https://github.com/communityox/oxmysql) — Database connector

**Optional:**
- [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) — Decentralized logging *(100% optional — completely silent if not installed)*

---

## 🚀 Installation

### 1. Download

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_parking.git
```

Or download the latest [release](https://github.com/RedDragonElite/rde_parking/releases/latest) and extract to your resources folder.

### 2. Add to server.cfg

Dependency order matters — follow this exactly:

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_target
ensure ox_inventory
ensure rde_nostr_log   # optional
ensure rde_parking
```

### 3. Configure

Edit `config.lua` to your liking:

```lua
Config.Locale           = 'de'    -- 'en' or 'de'
Config.RequireEngineOff = true    -- engine must be off before parking
Config.AutoDeleteAfterDays = 7    -- remove vehicles older than 7 days (0 = off)
Config.Debug            = false   -- set true during setup
```

### 4. Done ✅

The script auto-creates the database table `rde_parked_vehicles` on first start.  
No SQL imports. No manual setup. Check your console for the startup banner.

---

## 🎮 How It Works

### Parking Flow

```
1. Get in your vehicle (must be registered owner)
2. Drive to your desired parking spot
3. Turn engine off  [Config.RequireEngineOff = true]
4. Step outside → ox_target → "🅿️ Park Vehicle"
5. 📱 Phone-check animation plays while progress circle runs (3 seconds)
6. Vehicle locked in place — stays in world, saved to DB
7. Double horn beep + hazard lights flash
```

### Retrieval Flow — Manual

```
1. Walk up to your parked vehicle (it re-spawned on login)
2. Look at it → ox_target → "🚗 Retrieve Vehicle"
3. Short progress circle (1.5 seconds)
4. Vehicle unlocked, DB entry removed — drive away
```

### Retrieval Flow — Automatic

```
1. Get in your parked vehicle
2. Start the engine
3. System detects engine start on a parked vehicle → auto-retrieves instantly
4. No menu, no interaction needed — just get in and drive
```

### Lock / Unlock Flow

```
1. Stand next to your vehicle (outside)
2. Look at it:
   • Unlocked → ox_target shows "🔒 Lock Vehicle"
   • Locked   → ox_target shows "🔓 Unlock Vehicle"
3. 🔑 Key-fob animation plays (0.8 seconds)
4. Lock:   double horn beep + 2x hazard flash
   Unlock: single pip + 1x hazard flash
5. Lock state synced to all nearby players via server event
6. Lock state persisted to DB for parked vehicles
```

### Why ox_target Instead of [E] / TextUI?

The old approach — polling distance in a thread, showing TextUI, hiding it on walk-away — has a fundamental flaw: `hideTextUI()` is only called if the thread reaches that branch cleanly. Any yield, any race condition, and the label stays on screen forever.

ox_target handles show/hide internally. It's always correct. No stuck UI possible.

---

## ⚙️ Configuration

### `config.lua` — Full Reference

```lua
-- Language: 'en' | 'de' (add your own in Config.Locales)
Config.Locale = 'de'

-- Auto-delete old parked vehicles
Config.AutoDeleteParkedVehicles = true
Config.AutoDeleteAfterDays      = 7     -- 0 = disabled

-- Distances (metres)
Config.ParkDistance  = 5.0    -- max range for park/retrieve
Config.LockDistance  = 10.0   -- max range for lock/unlock
Config.SpawnDistance = 150.0  -- spawn radius on player login

-- Vehicle rules
Config.RequireEngineOff = true    -- engine must be off to park
Config.SaveDamage       = true    -- persist damage
Config.SaveMods         = true    -- persist mods
Config.SaveFuel         = true    -- persist fuel
Config.MinHealthToPark  = 100.0   -- minimum body health

-- Progress bar durations (ms)
Config.ParkDuration = 3000
Config.LockDuration = 800

-- Cooldowns (ms)
Config.ParkCooldown = 3000
Config.LockCooldown = 1000

-- Blacklisted vehicle classes (won't be parkable)
Config.BlacklistedClasses = {
    [14] = true,  -- Boats
    [21] = true,  -- Trains
}
```

### Adding a New Language

Open `config.lua` and add a new locale block:

```lua
Config.Locales.fr = {
    target_park      = '🅿️ Garer le véhicule',
    target_unpark    = '🚗 Récupérer le véhicule',
    target_lock      = '🔒 Verrouiller',
    target_unlock    = '🔓 Déverrouiller',
    vehicle_parked   = '🅿️ Véhicule garé en sécurité',
    -- ... copy all keys from Config.Locales.en and translate
}
```

Then set `Config.Locale = 'fr'`. Done.

---

## 👑 Admin Commands

| Command | Description | Permission |
| --- | --- | --- |
| `/parkingstats` | Shows spawned vehicles, DB count, active locks | `group.admin` |
| `/parkingreload` | Despawns all parked vehicles and re-spawns them fresh | `group.admin` |
| `/parkingcleanup` | Runs the auto-delete cleanup manually | `group.admin` |

---

## 📡 Nostr Logging

If [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) is installed and started, the parking system automatically logs events to the Nostr network — decentralized, permanent, uncensorable.

**Events logged:**

| Event | Message |
| --- | --- |
| Vehicle parked | `🅿️ [PARKING] PlayerName parked ABC1234 at x / y / z` |
| Vehicle retrieved | `🚗 [PARKING] PlayerName retrieved ABC1234` |
| Admin /parkingstats | `👑 [PARKING ADMIN] AdminName – parkingstats` |
| Admin /parkingreload | `👑 [PARKING ADMIN] AdminName – parkingreload` |
| Admin /parkingcleanup | `👑 [PARKING ADMIN] AdminName – parkingcleanup` |

**No rde_nostr_log installed?** The script checks `GetResourceState('rde_nostr_log')` before every call. Not running = complete silence, not a single error.

---

## 🗄️ Database

The script auto-creates one table on first start:

```sql
CREATE TABLE IF NOT EXISTS `rde_parked_vehicles` (
    `id`         INT AUTO_INCREMENT PRIMARY KEY,
    `vehicle_id` INT NOT NULL UNIQUE,
    `plate`      VARCHAR(20) NOT NULL,
    `coords`     TEXT NOT NULL,
    `heading`    FLOAT NOT NULL,
    `props`      LONGTEXT NOT NULL,
    `locked`     TINYINT(1) DEFAULT 0,
    `parked_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_vehicle_id` (`vehicle_id`),
    INDEX `idx_plate`      (`plate`),
    INDEX `idx_parked_at`  (`parked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

`props` stores the full `lib.getVehicleProperties` output — mods, colours, extras, fuel, damage, everything. MariaDB 10.5+ recommended.

---

## 🔧 Exports

Other resources can hook into the parking system server-side:

```lua
-- Check if a vehicle plate is currently parked
-- (returns boolean)
local isParked = lib.callback.await('rde_parking:isVehicleParked', false, plate)

-- Get all vehicles owned by a character
-- (returns array of { vehicleId, plate, model })
local vehicles = lib.callback.await('rde_parking:getOwnedVehicles', false)
```

---

## 🐛 Troubleshooting

### Park option not showing up
- Make sure `ox_target` is started **before** `rde_parking` in `server.cfg`.
- The system uses `GetResourceState('ox_target')` to wait for ox_target — not `exports.ox_target` which is always a non-nil table.
- Enable `Config.Debug = true` — if you see `ox_target registered ✅` in client console, targets are loaded.

### Park option shows but clicking does nothing / "engine must be off"
- Engine check happens in `onSelect` with a notification — the option intentionally shows even when engine is on.
- Turn the engine off first, then click Park.

### Vehicle doesn't re-spawn on login
- The system waits 5 seconds after `ox:playerLoaded` — increase the `SetTimeout(5000, ...)` in `server/main.lua` if your server loads characters slowly.
- Enable `Config.Debug = true` and check server console for spawn logs.

### "Not your vehicle" when it clearly is
- The ownership cache is built from the `vehicles` table in your database.
- The cache is sent to the client after `ox:playerLoaded` via `rde_parking:updateOwnershipCache`.
- If it's empty, check your `vehicles` table has the correct `owner` column matching `charId`.

### Lock label shows wrong text / wrong icon
- This was a bug in older versions caused by ox_target ignoring the second return value of `canInteract`.
- **This is fixed** — there are now two separate targets: `rde_parking_lock` (shows when unlocked) and `rde_parking_unlock` (shows when locked).

### No horn / no blinkers when locking
- `SoundVehicleHornThisFrame` must be called every frame for the duration — calling it once does nothing. This is handled correctly.
- `SetVehicleIndicatorLights` is used for actual blinkers — not `SetVehicleLights` which controls headlights.
- If still silent, check that the vehicle entity exists and you are close enough.

### Lock not syncing to other players
- Lock sync requires the vehicle to have a valid network ID (`NetworkGetNetworkIdFromEntity`).
- Make sure the vehicle is networked (it will be if spawned by the server on login).

### Database error on start
- Make sure `oxmysql` is started before `rde_parking` in `server.cfg`.
- The script waits for oxmysql to reach `started` state before running any queries.

---

## 🗺️ Roadmap

### v1.1 (Planned)
- [ ] **Parking zones** — restrict parking to defined areas only
- [ ] **Garage integration** — park into persistent garages with slot management
- [ ] **Parking fee** — optional cost per park (ox_inventory)
- [ ] **Vehicle list UI** — view and retrieve all your parked vehicles from a menu

### v2.0 (Future)
- [ ] **Impound system** — police can tow/impound vehicles
- [ ] **Multi-character support** — vehicles tied to character, not just account
- [ ] **Parking tickets** — police can leave fines on parked vehicles
- [ ] **Map blips** — optional blip for your parked vehicle location

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m 'Add AmazingFeature'`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a Pull Request

### Bug Reports
Please include:
- FiveM server version & build
- ox_core / ox_lib / ox_target versions
- Full server **and** client console output
- Steps to reproduce

---

## 📄 License

This project is licensed under the **RDE Black Flag License**.

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE Parking | Parking & car lock system for FiveM.                #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   ORIGIN:     https://github.com/RedDragonElite                                 #
#                                                                                 #
#   WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS #
#                                                                                 #
#   [ THE RULES OF THE GAME ]                                                     #
#                                                                                 #
#   1. // THE "FUCK GREED" PROTOCOL (FREE USE)                                    #
#      You are free to use, edit, and abuse this code on your server.             #
#      Learn from it. Break it. Fix it. That is the hacker way.                   #
#      Cost: 0.00€. If you paid for this, you got scammed by a rat.               #
#                                                                                 #
#   2. // THE TEBEX KILL SWITCH (COMMERCIAL SUICIDE)                              #
#      If I find this script on Tebex, Patreon, or in a paid "Premium Pack":      #
#      > I will DMCA your store into oblivion.                                    #
#      > I will publicly shame your community.                                    #
#      > I hope your server lag spikes to 9999ms every time you blink.            #
#      SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.                            #
#                                                                                 #
#   3. // THE CREDIT OATH                                                         #
#      Keep this header. If you remove my name, you admit you have no skill.      #
#      You can add "Edited by [YourName]", but never erase the original creator.  #
#      Don't be a skid. Respect the architecture.                                 #
#                                                                                 #
#   4. // THE CURSE OF THE COPY-PASTE                                             #
#      This code uses StateBags, ox_inventory stashes, and layered callbacks.     #
#      If you just copy-paste without reading, it WILL break.                     #
#      Don't come crying to my DMs. RTFM or learn to code.                        #
#                                                                                 #
#   --------------------------------------------------------------------------    #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
#   --------------------------------------------------------------------------    #
###################################################################################
```

---

## 🙏 Credits

### Built With
- [ox_core](https://github.com/communityox/ox_core) — The only framework worth building on
- [ox_lib](https://github.com/communityox/ox_lib) — UI, progress bars, vehicle properties, animations
- [ox_target](https://github.com/communityox/ox_target) — Entity interaction system
- [oxmysql](https://github.com/communityox/oxmysql) — Database connector
- [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) — Decentralized logging

### Special Thanks
- Overextended team for the entire OX ecosystem
- The FiveM community for pushing the standard higher
- Everyone who tests, reports bugs, and contributes

---

<div align="center">

**Made with 🔥 by [.:: Red Dragon Elite ::. | SerpentsByte](https://rd-elite.com)**

*Part of the [RDE Arsenal](https://github.com/RedDragonElite) — 55+ next-gen FiveM resources, all FREE.*

[⬆ Back to Top](#%EF%B8%8F-rde-parking-system)

</div>
