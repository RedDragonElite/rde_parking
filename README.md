# 🅿️ rde_parking

🔥 PROXIMITY-LOADED PARKING & LOCK SYSTEM V1.1.0 — Built on ox_core & Statebags! 🅿️

[![Version](https://img.shields.io/badge/version-1.1.0-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking/blob/main/LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/Framework-ox__core-blue?style=for-the-badge)](https://github.com/overextended/ox_core)
[![Nostr](https://img.shields.io/badge/Nostr-Decentralized-purple?style=for-the-badge)](https://github.com/RedDragonElite/rde_nostr_log)
[![Price](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_parking)

**Proximity-streamed vehicle parking, statebag-synced locking, full property persistence, and zero-entity-bloat performance — all in one resource.**

Built on ox_core · ox_lib · ox_target · oxmysql

Built by Red Dragon Elite | SerpentsByte

📖 Table of Contents
Overview
Why RDE Parking?
Features
Dependencies
Installation
Configuration
Usage & Controls
Architecture
Developer API
Security
Commands
Database
Performance
Troubleshooting
Changelog
License
🎯 Overview
RDE Parking is a production-grade parking and vehicle-lock system for FiveM servers. Server-side proximity streaming, full statebag synchronization for both lock state and vehicle mods, ox_target interaction, persistent MySQL storage, server-validated ownership on every action, and optional decentralized Nostr logging — free forever.

v1.1.0 is a full RDE OX Standards v2 overhaul: parked vehicles are no longer all spawned at server boot. They stream in only when a player is actually nearby, and despawn again once nobody is — without ever touching the database row. Two real security/sync bugs from the original release were also found and fixed during the audit (see Security).

🔥 Why RDE Parking?
Other Parking Scripts	✅ RDE Parking
Every parked car spawns at boot, forever	Proximity-streamed — spawns only near players, despawns when empty
Client trusts its own plate/netId for locking	Server-side owner verification on every lock/unlock
Vehicle mods only visible to whoever parked it	Statebag + broadcast sync — every nearby player sees correct mods
Polling loops checking distance every frame	Throttled server sweep (default 5s), statebag-driven client reactions
Single TriggerClientEvent spaghetti	One sync path per state change — UpdateStatebag-style, no double broadcast
ESX / QBCore bloat	ox_core only — the future, not the past
Discord webhooks for logs (deletable, bannable)	Optional decentralized Nostr logging — permanent & uncensorable
Paid or locked down	100% free forever — RDE Black Flag
✨ Features
🅿️ Parking & Retrieval
ox_target driven — park, retrieve, lock and unlock all through context interaction, no keybind hell
Engine-off requirement and minimum body-health threshold before a vehicle can be parked (both configurable)
Full property capture on park via lib.getVehicleProperties() — mods, paint, livery, damage, fuel, everything
Auto-retrieve on engine start — get back in a parked vehicle and start the engine, it unparks itself automatically
Vehicle-class blacklist (boats, trains, etc. excluded from parking by default)
📡 Proximity Loading (RDE OX Standards v2)
Parked vehicles are NOT all spawned at once — a throttled server thread (RunProximitySweep, default every 5s) spawns a vehicle only once a player comes within Config.SpawnDistance
Despawns again after a grace period once nobody has been nearby — the database row is untouched, the vehicle simply respawns the moment someone gets close again
Despawn radius uses a hysteresis multiplier over the spawn radius to avoid pop-in/pop-out flicker at the boundary
A lightweight in-memory index (coords/plate/locked only — no props) drives the sweep; full vehicle properties are only pulled from the database the instant a vehicle actually spawns
🔄 Statebag Sync
Lock state and vehicle properties both sync through prefixed entity statebags (rde_parking_*) — single source of truth, no parallel TriggerClientEvent for the same data
Late joiners and players streaming a vehicle in from far away still receive correct mods/paint/lock state automatically via the statebag, not just whoever was online at spawn time
GlobalState.rde_parking_active and GlobalState.rde_parking_spawned_count expose a lightweight public view (plate/coords/locked only) for other resources — HUD, minimap, admin tools — with zero callback roundtrip
🛡️ Security
Server-side ownership verification on every park, lock, and unlock action against the vehicles table — never trusts the client's plate or netId blindly
Per-player parking lock to prevent concurrent park-spam from the same source
Server- and client-side lock/unlock cooldown
🐉 Optional Nostr Logging
Park and retrieve events logged to rde_nostr_log if present — decentralized, uncensorable, zero config required if the resource isn't installed
🌍 Multilanguage
Full English & German out of the box via Config.Locales — add a language by copying one block
📦 Dependencies
Resource	Required	Notes
oxmysql	✅ Required	Database layer
ox_core	✅ Required	Player/character framework, vehicle ownership
ox_lib	✅ Required	Progress bars, notifications, callbacks, vehicle property get/set
ox_target	✅ Required	All park/retrieve/lock/unlock interactions
rde_nostr_log	⭕ Optional	Decentralized event logging — runs fine without it
🚀 Installation
1. Clone the repository
cd resources
git clone https://github.com/RedDragonElite/rde_parking.git
2. Add to server.cfg
ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_target
ensure rde_parking

# Optional, install before rde_parking if you want decentralized logging
ensure rde_nostr_log
Order matters. rde_parking must start after all its dependencies.

3. Database
The rde_parked_vehicles table is created automatically on first start. No manual SQL import needed.

4. Configure (Optional)
Edit config.lua to adjust distances, cooldowns, proximity sweep behavior, and language.

5. Restart
restart rde_parking
Test by parking a vehicle with /parkingstats open in another window to watch the counters move.

⚙️ Configuration
Core
Config.Locale = 'en'                  -- 'en' or 'de'
Config.Debug  = false                 -- verbose console output, set false for live servers

Config.AutoDeleteParkedVehicles = true
Config.AutoDeleteAfterDays      = 7   -- 0 = disabled
Distances (metres)
Config.ParkDistance  = 5.0     -- max distance to park from vehicle
Config.LockDistance  = 10.0    -- max distance for lock/unlock interaction
Config.SpawnDistance = 150.0   -- proximity radius: vehicles only spawn when a player is within this range
Vehicle Rules
Config.RequireEngineOff = true    -- engine must be off before parking
Config.MinHealthToPark  = 100.0   -- minimum body health to allow parking

Config.BlacklistedClasses = {
    [14] = true,  -- 🚤 Boats
    [21] = true,  -- 🚂 Trains
}
Cooldowns & Durations (ms)
Config.ParkDuration = 3000   -- progress bar duration when parking
Config.LockDuration = 800    -- progress bar duration when locking/unlocking

Config.ParkCooldown = 3000
Config.LockCooldown = 1000   -- enforced BOTH client- and server-side
Proximity Loading
Config.Performance = {
    proximityCheckInterval    = 5000,   -- ms between server-side proximity sweeps
    proximityDespawnEnabled   = true,   -- despawn vehicles nobody is near
    despawnDistanceMultiplier = 1.5,    -- despawn radius = SpawnDistance * this (hysteresis)
    despawnGraceMs            = 30000,  -- ms with nobody nearby before despawning
}
Sound & Visual FX
Config.EnableHornFlash = true   -- blink lights on lock/unlock
Config.FlashCount      = 2
Config.FlashDelay      = 200    -- ms between flashes

Config.ParkSound   = { enabled = true, audioName = 'CONFIRM_BEEP', audioRef = 'HUD_MINI_GAME_SOUNDSET' }
Config.UnparkSound = { enabled = true, audioName = 'DOOR_OPEN',    audioRef = 'GTAO_FM_EVENTS_SOUNDSET' }
A note on Config.SaveDamage / Config.SaveMods / Config.SaveFuel: these flags exist in the config but aren't individually wired up yet — lib.getVehicleProperties() always captures the full property set (damage, mods, fuel, paint, everything) regardless of these flags. They're reserved for a future selective-persistence pass and left in place so nothing reading them today breaks.

🎮 Usage & Controls
Everything runs through ox_target — there is no keybind system.

Situation	ox_target Option
Standing near your own unlocked vehicle	🔒 Lock Vehicle
Standing near your own locked vehicle	🔓 Unlock Vehicle
In your own vehicle, engine off, not yet parked	🅿️ Park Vehicle
Standing near your own parked vehicle	🚗 Retrieve Vehicle
Get in a parked vehicle and start the engine	Auto-retrieves — no interaction needed
🏗️ Architecture
rde_parking/
├── fxmanifest.lua
├── config.lua            ← Config + Config.Locales (en/de)
├── server/
│   └── main.lua           ← proximity sweep, callbacks, statebag writes, GlobalState
└── client/
    └── main.lua            ← ox_target interactions, statebag handlers, FX

Proximity Loading
A server thread (RunProximitySweep, default every 5s via Config.Performance.proximityCheckInterval) compares every online player's position against a lightweight in-memory parkIndex — coordinates only, never full properties. Vehicles within Config.SpawnDistance of any player get spawned; vehicles nobody has been within despawnDistanceMultiplier × SpawnDistance of for despawnGraceMs get despawned. The database row is the permanent source of truth — spawning and despawning only ever touch the in-world entity.

The sweep also runs immediately whenever a player finishes loading (ox:playerLoaded), so vehicles near a fresh spawn point appear without waiting for the next scheduled tick — and once on resource start, to catch any players already connected through a resource restart.

Statebags (RDE OX Standards v2)
Every entity statebag this resource sets is prefixed with Config.StatebagPrefix (rde_parking_):

Key	Meaning
rde_parking_parked	Vehicle is flagged as parked
rde_parking_vehicleId	ox_core vehicle ID
rde_parking_plate	License plate
rde_parking_locked	Current lock state — the only sync path for lock/unlock
rde_parking_props	Full vehicle properties — ensures late-joining players see correct mods
rde_parking_owner	Owning character's charId
🔧 Developer API
Server Events
-- Force a full reload of the parking index + an immediate proximity sweep
-- (also exposed as /parkingreload)
LoadParkingIndex()
RunProximitySweep()

-- Publish the public GlobalState view manually after an external change
PublishParkingState()
GlobalState Reads (any resource)
local active  = GlobalState.rde_parking_active         -- { [vehicleId] = { plate, coords, locked } }
local spawned = GlobalState.rde_parking_spawned_count   -- number, currently spawned (nearby) vehicles
Client Events
-- Fired by the server after a vehicle is spawned (broadcast to ALL clients, not just one)
RegisterNetEvent('rde_parking:applyVehicleProps', function(netId, props) ... end)

-- Fired after a successful unpark
RegisterNetEvent('rde_parking:vehicleUnparked', function(plate) ... end)
🛡️ Security
The v1.1.0 RDE OX Standards audit caught and fixed two production-relevant bugs from the original release:

1. Missing ownership check on lock sync. Previously, any client could call the lock-sync event with an arbitrary plate/netId and lock or unlock any vehicle on the server — the server trusted the client's input blindly. Now every lock/unlock request is verified server-side against vehicles.owner before anything happens, with a cooldown on top.

2. Vehicle props only broadcast to one client. Mods and paint were only sent to whoever's client triggered the spawn — other nearby players saw the vehicle with no tuning applied. Props are now broadcast to all connected clients and written to the entity statebag, so anyone streaming the vehicle in later — including late joiners — receives the correct appearance automatically.

Beyond the audit fixes, the baseline security model:

Every park, lock, and unlock action is verified server-side against the vehicles table — never trusted from the client
Per-player parking lock prevents concurrent park-spam from a single source
Lock/unlock cooldown enforced on both client and server
Single statebag sync path per state change — no parallel TriggerClientEvent for the same data, eliminating an entire class of desync bugs
📋 Commands
Admin (restricted = group.admin)
Command	Description
/parkingstats	Show spawned (nearby) / indexed (total) / DB parked counts
/parkingreload	Reload the parking index from the database and re-run the proximity sweep
/parkingcleanup	Delete vehicles older than Config.AutoDeleteAfterDays
🗄️ Database
Table is auto-created on first start:

CREATE TABLE rde_parked_vehicles (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id  INT NOT NULL UNIQUE,
    plate       VARCHAR(20) NOT NULL,
    coords      TEXT NOT NULL,
    heading     FLOAT NOT NULL,
    props       LONGTEXT NOT NULL,
    locked      TINYINT(1) DEFAULT 0,
    parked_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vehicle_id (vehicle_id),
    INDEX idx_plate      (plate),
    INDEX idx_parked_at  (parked_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
Schema is unchanged from v1.0.0 — no migration step required when upgrading.

⚡ Performance
Architecture
Parked vehicles only exist as world entities while a player is actually within range. The proximity sweep keeps entity count proportional to where players currently are, not to the total size of the rde_parked_vehicles table — a server with thousands of parked vehicles spread across the map costs roughly the same as one with a hundred, as long as players aren't standing next to all of them at once.

The lightweight in-memory index that drives the sweep holds only plate/coordinates/heading/locked/owner — never the full property blob, which is only pulled from the database at the exact moment a vehicle is about to spawn.

Optimization Tips
Raise proximityCheckInterval on servers with very large parked-vehicle counts to reduce sweep frequency
Lower despawnGraceMs if you want vehicles to clear out of memory faster in high-traffic areas
despawnDistanceMultiplier should stay above 1.0 — a value too close to SpawnDistance causes pop-in/pop-out flicker right at the boundary
🐛 Troubleshooting
Parked vehicles don't appear when I get close?
Run /parkingreload in console. If they still don't show up, confirm oxmysql is fully started before rde_parking — check the ensure order in server.cfg.

Vehicle mods/paint not showing for other players?
This was the v1.1.0 audit fix — confirm you're actually on v1.1.0 and not an older build. Props now broadcast to all clients and sync via the rde_parking_props statebag.

Lock/unlock does nothing?
Check the cooldown — Config.LockCooldown is enforced on both client and server. Also confirm the vehicle is actually owned by your character; ownership is verified server-side.

"No permission" on admin commands?
Admin commands use lib.addCommand with restricted = 'group.admin' — verify your ox_core group via your permissions setup, not Config.AdminGroups (this resource doesn't use that pattern for its own commands).

Vehicle parks but disappears entirely instead of staying visible?
Check Config.SpawnDistance — the vehicle you just parked is adopted directly into the spawned cache using its live netId, so it should stay visible to you immediately. If it vanishes, confirm no other resource is deleting the entity on the same frame.

Nostr logger not connecting?
[RDE | PARKING] Resource "rde_nostr_log" not found in console means rde_nostr_log isn't installed — this is expected and harmless if you don't want decentralized logging. Install it and ensure it starts before rde_parking to enable.

📝 Changelog
v1.1.0 — RDE OX Standards v2 Overhaul (current)
✨ Proximity Loading — vehicles spawn/despawn based on player distance instead of all spawning at boot
✨ GlobalState register (rde_parking_active, rde_parking_spawned_count) for external resources
✨ Prefixed, statebag-based lock & props synchronization — no double broadcast
🐛 Fix: missing ownership check on lock sync — any client could previously lock/unlock any vehicle
🐛 Fix: vehicle props only broadcast to one client instead of all nearby players
🔧 fxmanifest.lua: /server:7290 dependency added (RDE Standard)
🔧 Database schema unchanged — no migration step needed
v1.0.0 — Initial release
✨ ox_target driven park / retrieve / lock / unlock
✨ Full vehicle property persistence via lib.getVehicleProperties()
✨ Auto-retrieve on engine start
✨ EN / DE locales
📜 License
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE_PARKING v1.1.0 (PROXIMITY-LOADED PARKING & LOCK SYSTEM)       #
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
#      Listen closely, you parasites:                                             #
#      If I find this script on Tebex, Patreon, or in a paid "Premium Pack":      #
#      > I will DMCA your store into oblivion.                                    #
#      > I will publicly shame your community.                                    #
#      > I hope every parking spot you ever pull into is already taken.           #
#      SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.                            #
#                                                                                 #
#   3. // THE CREDIT OATH                                                         #
#      Keep this header. If you remove my name, you admit you have no skill.      #
#      You can add "Edited by [YourName]", but never erase the original creator.  #
#      Don't be a skid. Respect the architecture.                                 #
#                                                                                 #
#   4. // THE CURSE OF THE COPY-PASTE                                             #
#      This code uses statebags, proximity streaming, and a layered sync         #
#      architecture. If you just copy-paste without reading, it WILL break.       #
#      Don't come crying to my DMs. RTFM or learn to code.                        #
#                                                                                 #
#   --------------------------------------------------------------------------    #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
#   --------------------------------------------------------------------------    #
###################################################################################
TL;DR:

✅ Free forever — use it, edit it, learn from it
✅ Keep the header — credit where it's due
❌ Don't sell it — commercial use = instant DMCA
❌ Don't be a skid — copy-paste without reading won't work anyway
🌐 Community & Support
🐙 GitHub	RedDragonElite
🌍 Website	rd-elite.com
🔵 Nostr (RDE)	RedDragonElite
🔵 Nostr (Shin)	SerpentsByte
🎮 RDE Props	rde_props
🚪 RDE Doors	rde_doors
🚨 RDE AIPD	rde_aipd
📡 RDE Nostr Log	rde_nostr_log
When asking for help, always include:

Full error from server console or txAdmin
Your server.cfg resource start order
ox_core / ox_lib versions in use

"We build the future on the graves of paid resources."

REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.

[![Website](https://img.shields.io/badge/Website-Visit-red?style=for-the-badge&logo=google-chrome)](https://rd-elite.com)
[![Nostr](https://img.shields.io/badge/Nostr-Follow-purple?style=for-the-badge&logo=rss)](https://primal.net/p/npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94)

🐉 Made with 🔥 by Red Dragon Elite

⬆ Back to Top
