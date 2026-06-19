Config = {}

-- ════════════════════════════════════════
--  🌐  Language  ('en' | 'de')
-- ════════════════════════════════════════
Config.Locale = 'en'

Config.Locales = {
    en = {
        -- 🎯 ox_target labels
        target_park      = '🅿️ Park Vehicle',
        target_unpark    = '🚗 Retrieve Vehicle',
        target_lock      = '🔒 Lock Vehicle',
        target_unlock    = '🔓 Unlock Vehicle',

        -- ✅ Success
        vehicle_parked   = '🅿️ Vehicle safely parked',
        vehicle_unparked = '🚗 Vehicle retrieved',
        vehicle_locked   = '🔒 Vehicle locked',
        vehicle_unlocked = '🔓 Vehicle unlocked',
        vehicle_spawned  = '✅ Vehicle ready at parking spot',

        -- ❌ Errors
        engine_must_be_off   = 'Turn off the engine first',
        not_your_vehicle     = 'This vehicle does not belong to you',
        not_in_own_vehicle   = 'You must be in your own vehicle',
        vehicle_damaged      = 'Vehicle too damaged to park safely',
        parking_spot_blocked = 'Parking spot is blocked',
        database_error       = 'A database error occurred',
        parking_failed       = 'Parking failed — please try again',

        -- ⏳ Progress labels
        parking_vehicle    = '🅿️ Parking vehicle…',
        retrieving_vehicle = '🚗 Retrieving vehicle…',
        locking_vehicle    = '🔒 Locking…',
        unlocking_vehicle  = '🔓 Unlocking…',

        -- 📊 Info
        vehicle_info   = '📊 Vehicle Info',
        fuel_level     = '⛽ Fuel',
        health_level   = '🔧 Condition',
        parked_time    = '🕒 Parked since',
    },
    de = {
        -- 🎯 ox_target labels
        target_park      = '🅿️ Fahrzeug parken',
        target_unpark    = '🚗 Fahrzeug holen',
        target_lock      = '🔒 Fahrzeug abschließen',
        target_unlock    = '🔓 Fahrzeug aufschließen',

        -- ✅ Erfolg
        vehicle_parked   = '🅿️ Fahrzeug sicher geparkt',
        vehicle_unparked = '🚗 Fahrzeug geholt',
        vehicle_locked   = '🔒 Fahrzeug abgeschlossen',
        vehicle_unlocked = '🔓 Fahrzeug aufgeschlossen',
        vehicle_spawned  = '✅ Fahrzeug am Parkplatz bereit',

        -- ❌ Fehler
        engine_must_be_off   = 'Motor zuerst abstellen',
        not_your_vehicle     = 'Dieses Fahrzeug gehört dir nicht',
        not_in_own_vehicle   = 'Du musst in deinem eigenen Fahrzeug sitzen',
        vehicle_damaged      = 'Fahrzeug zu beschädigt zum sicheren Parken',
        parking_spot_blocked = 'Parkplatz ist blockiert',
        database_error       = 'Datenbankfehler aufgetreten',
        parking_failed       = 'Parken fehlgeschlagen — bitte erneut versuchen',

        -- ⏳ Fortschritt
        parking_vehicle    = '🅿️ Parke Fahrzeug…',
        retrieving_vehicle = '🚗 Hole Fahrzeug…',
        locking_vehicle    = '🔒 Abschließen…',
        unlocking_vehicle  = '🔓 Aufschließen…',

        -- 📊 Info
        vehicle_info   = '📊 Fahrzeug Info',
        fuel_level     = '⛽ Tank',
        health_level   = '🔧 Zustand',
        parked_time    = '🕒 Geparkt seit',
    },
}

-- ════════════════════════════════════════
--  🏷️  Statebag Prefix  (RDE OX Standards v2)
--  All entity statebags this resource sets use this exact prefix.
--  AddStateBagChangeHandler matches EXACT keys, not prefixes — so every
--  key below is the prefix + a fixed suffix, never a partial match.
-- ════════════════════════════════════════
Config.StatebagPrefix = 'rde_parking_'

-- ════════════════════════════════════════
--  🗑️  Auto-Delete
-- ════════════════════════════════════════
Config.AutoDeleteParkedVehicles = true
Config.AutoDeleteAfterDays      = 7   -- 0 = disabled

-- ════════════════════════════════════════
--  📏  Distances  (metres)
-- ════════════════════════════════════════
Config.ParkDistance   = 5.0    -- max distance to park from vehicle
Config.LockDistance   = 10.0   -- max distance for lock/unlock interaction
Config.SpawnDistance  = 150.0  -- proximity radius: vehicles only spawn when a player is within this range

-- ════════════════════════════════════════
--  🚗  Vehicle Rules
-- ════════════════════════════════════════
Config.RequireEngineOff = true    -- engine must be off before parking
Config.SaveDamage       = true    -- ⚠️ NOTE: not individually wired up — lib.getVehicleProperties()
Config.SaveMods         = true    --    always captures the FULL property set (damage, mods, fuel,
Config.SaveFuel         = true    --    paint, etc.) regardless of these flags. They're reserved for
                                   --    a future selective-persistence pass; left here so nothing
                                   --    that currently reads them breaks.
Config.MinHealthToPark  = 100.0   -- minimum body health to allow parking

-- ════════════════════════════════════════
--  ⏱️  Progress Bar Durations  (ms)
-- ════════════════════════════════════════
Config.ParkDuration   = 3000   -- time to park
Config.LockDuration   = 800    -- time to lock/unlock

-- ════════════════════════════════════════
--  🔊  Sound & Visual FX
-- ════════════════════════════════════════
Config.EnableHornFlash = true   -- blink lights on lock/unlock
Config.FlashCount      = 2
Config.FlashDelay      = 200    -- ms between flashes

Config.ParkSound = {
    enabled   = true,
    audioName = 'CONFIRM_BEEP',
    audioRef  = 'HUD_MINI_GAME_SOUNDSET',
}
Config.UnparkSound = {
    enabled   = true,
    audioName = 'DOOR_OPEN',
    audioRef  = 'GTAO_FM_EVENTS_SOUNDSET',
}

-- ════════════════════════════════════════
--  ⏱️  Anti-Exploit Cooldowns  (ms)
-- ════════════════════════════════════════
Config.ParkCooldown = 3000
Config.LockCooldown = 1000   -- also enforced server-side now (see server/main.lua CanLock)

-- ════════════════════════════════════════
--  🚫  Blacklisted Vehicle Classes
-- ════════════════════════════════════════
Config.BlacklistedClasses = {
    [14] = true,  -- 🚤 Boats
    [21] = true,  -- 🚂 Trains
}

-- ════════════════════════════════════════
--  🐛  Debug
-- ════════════════════════════════════════
Config.Debug = false

-- ════════════════════════════════════════
--  📊  Performance / Proximity Loading
--  RDE OX Standards v2 — vehicles are NOT all spawned at once anymore.
--  A throttled server thread spawns parked vehicles only once a player
--  comes within Config.SpawnDistance, and despawns them again (DB row
--  stays, so they're not "lost") once nobody has been nearby for
--  despawnGraceMs. This keeps entity count proportional to where
--  players actually are instead of the total size of the DB table.
-- ════════════════════════════════════════
Config.Performance = {
    threadSleep                  = 500,     -- legacy/general client throttle, unrelated to proximity
    checkDistance                = 150.0,   -- legacy/general — Config.SpawnDistance is authoritative now
    cacheOwnership                = true,

    proximityCheckInterval        = 5000,   -- ms between server-side proximity sweeps
    proximityDespawnEnabled       = true,   -- despawn vehicles nobody is near (frees entities/memory)
    despawnDistanceMultiplier     = 1.5,    -- despawn radius = Config.SpawnDistance * this (hysteresis, avoids pop-in flicker)
    despawnGraceMs                = 30000,  -- ms with nobody nearby before an idle spawned vehicle is despawned
}

return Config
