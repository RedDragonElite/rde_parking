local Ox = require '@ox_core.lib.init'

-- ═══════════════════════════════════════════════════
--  🌐  Locale Helper
-- ═══════════════════════════════════════════════════

local function T(key, ...)
    local locale = Config.Locales[Config.Locale] or Config.Locales['en']
    local str    = locale[key] or Config.Locales['en'][key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

-- ═══════════════════════════════════════════════════
--  📡  Nostr Logger — Optional
-- ═══════════════════════════════════════════════════

local function NostrLog(message, tags)
    if GetResourceState('rde_nostr_log') ~= 'started' then return end
    pcall(function()
        exports['rde_nostr_log']:postLog(message, tags or {})
    end)
end

local function NostrPark(playerName, plate, coords)
    NostrLog(('🅿️ [PARKING] %s parked %s at %.1f / %.1f / %.1f'):format(playerName, plate, coords.x, coords.y, coords.z), {
        { 'script', 'rde_parking' }, { 'event', 'park' },
        { 'player', playerName }, { 'plate', plate },
    })
end

local function NostrUnpark(playerName, plate)
    NostrLog(('🚗 [PARKING] %s retrieved %s'):format(playerName, plate), {
        { 'script', 'rde_parking' }, { 'event', 'unpark' },
        { 'player', playerName }, { 'plate', plate },
    })
end

-- ═══════════════════════════════════════════════════
--  📊  State Management
-- ═══════════════════════════════════════════════════

local State = {
    spawnedVehicles    = {},   -- [vehicleId] = { entity, netId, plate, coords, heading, props, locked, owner, farSince }
    parkIndex          = {},   -- [vehicleId] = { plate, coords, heading, locked, owner }  -- lightweight, ALL parked vehicles, no props
    playerParkingLocks = {},   -- [source]    = true
}

-- ═══════════════════════════════════════════════════
--  🛠️  Utility
-- ═══════════════════════════════════════════════════

local function Debug(msg, ...)
    if not Config.Debug then return end
    print(('[^5RDE PARKING^7][^3SERVER^7][^2%s^7] %s'):format(
        os.date('%H:%M:%S'),
        msg:format(...)
    ))
end

-- 🗄️ DB boolean helpers (RDE OX Standards v2)
local function DbBool(v) return (v == true or v == 1) and 1 or 0 end
local function BoolDb(v) return v == 1 or v == '1' or v == true end

local function TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function GetPlayerCharacter(src)
    local player = Ox.GetPlayer(src)
    if not player then
        Debug('Player not found: %s', src)
        return nil
    end
    if not player.charId then
        Debug('Player has no character: %s', src)
        return nil
    end
    return player
end

local function GetPlayerDisplayName(src)
    local p = Ox.GetPlayer(src)
    if p and p.get then
        local firstName = p.get('firstName') or ''
        local lastName  = p.get('lastName')  or ''
        local name      = (firstName .. ' ' .. lastName):gsub('^%s*(.-)%s*$', '%1')
        if name ~= '' then return name end
    end
    return GetPlayerName(src) or 'Unknown'
end

local function TrimPlate(plate)
    return plate and plate:gsub('^%s*(.-)%s*$', '%1') or ''
end

local function GetOxVehicle(vehicleId)
    return Ox.GetVehicle(vehicleId)
end

-- ═══════════════════════════════════════════════════
--  💾  Database Setup
-- ═══════════════════════════════════════════════════

local dbReady = false

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(1000)
    end
    Wait(1000)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rde_parked_vehicles` (
            `id`        INT AUTO_INCREMENT PRIMARY KEY,
            `vehicle_id` INT NOT NULL UNIQUE,
            `plate`     VARCHAR(20) NOT NULL,
            `coords`    TEXT NOT NULL,
            `heading`   FLOAT NOT NULL,
            `props`     LONGTEXT NOT NULL,
            `locked`    TINYINT(1) DEFAULT 0,
            `parked_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_vehicle_id` (`vehicle_id`),
            INDEX `idx_plate`      (`plate`),
            INDEX `idx_parked_at`  (`parked_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    dbReady = true
    Debug('Database ready')

    LoadParkingIndex()
    RunProximitySweep()   -- catches any players already on the server at a resource restart

    if Config.AutoDeleteParkedVehicles and Config.AutoDeleteAfterDays > 0 then
        DeleteOldParkedVehicles()
    end
end)

-- ═══════════════════════════════════════════════════
--  🅿️  Parking Logic
-- ═══════════════════════════════════════════════════

function DeleteOldParkedVehicles()
    if not Config.AutoDeleteParkedVehicles or Config.AutoDeleteAfterDays <= 0 then return end
    Debug('Checking for old parked vehicles (>%d days)…', Config.AutoDeleteAfterDays)
    local result = MySQL.query.await([[
        DELETE FROM rde_parked_vehicles
        WHERE parked_at < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], { Config.AutoDeleteAfterDays })
    if result and result.affectedRows > 0 then
        Debug('Deleted %d old parked vehicles', result.affectedRows)
    end
end

-- 📡 Publish a lightweight, PUBLIC view of currently-spawned parked vehicles
-- to GlobalState. Only plate/coords/locked — all info already visible to
-- anyone who simply walks up to the car, so nothing private leaks here.
-- Event-driven (only called on actual state changes), never on a timer,
-- per RDE Performance standards.
function PublishParkingState()
    local active = {}
    for vehicleId, data in pairs(State.spawnedVehicles) do
        active[tostring(vehicleId)] = { plate = data.plate, coords = data.coords, locked = data.locked }
    end
    GlobalState[Config.StatebagPrefix .. 'active']        = active
    GlobalState[Config.StatebagPrefix .. 'spawned_count']  = TableCount(State.spawnedVehicles)
end

-- 📍 Loads a lightweight index (NO props — those stay in the DB until a
-- vehicle is actually about to spawn) of every currently-parked vehicle,
-- server-wide. This is the source of truth the proximity sweep reads from.
function LoadParkingIndex()
    local rows = MySQL.query.await([[
        SELECT pv.vehicle_id, pv.plate, pv.coords, pv.heading, pv.locked, v.owner
        FROM rde_parked_vehicles pv
        JOIN vehicles v ON pv.vehicle_id = v.id
    ]])

    State.parkIndex = {}

    if not rows then
        Debug('Parking index loaded: 0 vehicles')
        return
    end

    for _, row in ipairs(rows) do
        local ok, coords = pcall(json.decode, row.coords)
        if ok and coords then
            State.parkIndex[row.vehicle_id] = {
                plate   = row.plate,
                coords  = vector3(coords.x, coords.y, coords.z),
                heading = row.heading,
                locked  = BoolDb(row.locked),
                owner   = row.owner,
            }
        end
    end

    Debug('Parking index loaded: %d vehicles', #rows)
end

-- 🚗 Spawns a parked vehicle entity from a full data row.
-- `data.owner` must be the charId (or nil) — no longer tied to a
-- specific requesting player/session, since spawning is now
-- proximity-triggered and can happen with nobody "logging in".
function SpawnParkedVehicle(data)
    local coords    = type(data.coords) == 'string' and json.decode(data.coords) or data.coords
    local props     = type(data.props)  == 'string' and json.decode(data.props)  or data.props
    local vehicleId = data.vehicle_id
    local plate     = data.plate
    local heading   = data.heading
    local locked    = data.locked or 0
    local model     = data.model
    local owner     = data.owner

    if State.spawnedVehicles[vehicleId] then
        Debug('Vehicle already spawned: %s', vehicleId)
        return
    end

    local modelHash = type(model) == 'number' and model or GetHashKey(model)
    local vehicle   = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, true)
    local attempts  = 0

    while not DoesEntityExist(vehicle) and attempts < 100 do
        Wait(50)
        attempts += 1
    end

    if not DoesEntityExist(vehicle) then
        Debug('Failed to spawn vehicle: %s', vehicleId)
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleDoorsLocked(vehicle, locked == 1 and 2 or 1)

    -- 🏷️ Statebags — prefixed (RDE OX Standards v2), single source of truth.
    -- 'props' is included here too (not just the one-shot broadcast below)
    -- so any client who streams this entity in LATER — late joiners,
    -- players who were far away — still gets the correct mods/paint/etc.
    -- via the natural statebag sync, not just whoever was online at spawn time.
    local st = Entity(vehicle).state
    st:set(Config.StatebagPrefix .. 'parked',    true,                true)
    st:set(Config.StatebagPrefix .. 'vehicleId', vehicleId,           true)
    st:set(Config.StatebagPrefix .. 'plate',     plate,               true)
    st:set(Config.StatebagPrefix .. 'locked',    locked == 1,         true)
    st:set(Config.StatebagPrefix .. 'props',     json.encode(props),  true)
    if owner then
        st:set(Config.StatebagPrefix .. 'owner', owner, true)
    end

    State.spawnedVehicles[vehicleId] = {
        entity  = vehicle,
        netId   = netId,
        plate   = plate,
        coords  = vector3(coords.x, coords.y, coords.z),
        heading = heading,
        props   = props,
        locked  = locked == 1,
        owner   = owner,
    }

    Debug('Spawned vehicle: %s (NetID: %s)', plate, netId)

    -- 🎨 Immediate broadcast to everyone currently online, for snappy visuals.
    -- Broadcasts to -1 (ALL clients), not just whoever triggered the spawn —
    -- previously this only went to the spawning player's own client, so other
    -- nearby players saw the vehicle without its mods/paint applied. Fixed.
    SetTimeout(800, function()
        if DoesEntityExist(vehicle) then
            TriggerClientEvent('rde_parking:applyVehicleProps', -1, netId, props)
        end
    end)
end

-- ═══════════════════════════════════════════════════
--  📡  Proximity Loading  (RDE OX Standards v2)
-- ═══════════════════════════════════════════════════

local function GetOnlinePlayerCoords()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= 0 then
            list[#list + 1] = GetEntityCoords(ped)
        end
    end
    return list
end

local function IsAnyPlayerWithin(coords, radius, playerCoordsList)
    for i = 1, #playerCoordsList do
        if #(playerCoordsList[i] - coords) <= radius then return true end
    end
    return false
end

-- Spawns a single parked vehicle from the lightweight index, fetching its
-- props fresh from the DB only at this moment (keeps the index itself light).
function SpawnParkedVehicleByIndex(vehicleId, idx)
    if State.spawnedVehicles[vehicleId] then return end

    local row = MySQL.single.await([[
        SELECT pv.coords, pv.heading, pv.props, pv.locked, v.model
        FROM rde_parked_vehicles pv
        JOIN vehicles v ON pv.vehicle_id = v.id
        WHERE pv.vehicle_id = ?
    ]], { vehicleId })

    if not row then
        -- Vehicle got unparked in the meantime — drop the stale index entry
        State.parkIndex[vehicleId] = nil
        return
    end

    SpawnParkedVehicle({
        vehicle_id = vehicleId,
        plate      = idx.plate,
        coords     = row.coords,
        heading    = row.heading,
        props      = row.props,
        locked     = row.locked,
        model      = row.model,
        owner      = idx.owner,
    })

    PublishParkingState()
end

-- Deletes the entity for a spawned-but-now-far-away parked vehicle.
-- The DB row (and the index entry) stay intact — it'll respawn the next
-- time a player gets close again. Nothing is "lost".
function DespawnParkedVehicle(vehicleId)
    local data = State.spawnedVehicles[vehicleId]
    if not data then return end

    if DoesEntityExist(data.entity) then
        DeleteEntity(data.entity)
    end

    State.spawnedVehicles[vehicleId] = nil
    Debug('Despawned parked vehicle (no players nearby): %s', data.plate)
    PublishParkingState()
end

-- Core proximity tick: spawn what's now in range, despawn what's been out
-- of range for too long. Called on a throttled thread AND once immediately
-- whenever a player loads in, so nearby vehicles appear without delay.
function RunProximitySweep()
    if not dbReady then return end
    local playerCoordsList = GetOnlinePlayerCoords()

    -- 🅿️ Spawn nearby parked vehicles that aren't loaded yet
    for vehicleId, idx in pairs(State.parkIndex) do
        if not State.spawnedVehicles[vehicleId] and IsAnyPlayerWithin(idx.coords, Config.SpawnDistance, playerCoordsList) then
            SpawnParkedVehicleByIndex(vehicleId, idx)
        end
    end

    -- 🧹 Despawn vehicles nobody has been near for a while
    if Config.Performance.proximityDespawnEnabled then
        local despawnRadius = Config.SpawnDistance * Config.Performance.despawnDistanceMultiplier
        local now = GetGameTimer()

        for vehicleId, data in pairs(State.spawnedVehicles) do
            if data.coords and not IsAnyPlayerWithin(data.coords, despawnRadius, playerCoordsList) then
                data.farSince = data.farSince or now
                if now - data.farSince >= Config.Performance.despawnGraceMs then
                    DespawnParkedVehicle(vehicleId)
                end
            else
                data.farSince = nil
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.Performance.proximityCheckInterval)
        RunProximitySweep()
    end
end)

-- ═══════════════════════════════════════════════════
--  📡  Callbacks
-- ═══════════════════════════════════════════════════

lib.callback.register('rde_parking:getOwnedVehicles', function(src)
    local player = GetPlayerCharacter(src)
    if not player then return {} end

    local vehicles = MySQL.query.await([[
        SELECT id as vehicleId, plate, model
        FROM vehicles
        WHERE owner = ?
    ]], { player.charId })

    return vehicles or {}
end)

lib.callback.register('rde_parking:parkVehicle', function(src, plate, coords, heading, props, netId)
    local player = GetPlayerCharacter(src)
    if not player then return false end

    plate = TrimPlate(plate)

    if State.playerParkingLocks[src] then
        Debug('Parking lock active for player %s', src)
        return false
    end
    State.playerParkingLocks[src] = true

    local vehicle = MySQL.single.await([[
        SELECT id FROM vehicles
        WHERE plate = ? AND owner = ?
    ]], { plate, player.charId })

    if not vehicle then
        Debug('Vehicle not owned by player: %s', plate)
        State.playerParkingLocks[src] = nil
        return false
    end

    local vehicleId = vehicle.id

    -- Remove existing parked entry
    MySQL.query.await('DELETE FROM rde_parked_vehicles WHERE vehicle_id = ?', { vehicleId })

    local insertId = MySQL.insert.await([[
        INSERT INTO rde_parked_vehicles (vehicle_id, plate, coords, heading, props, locked)
        VALUES (?, ?, ?, ?, ?, 0)
    ]], {
        vehicleId,
        plate,
        json.encode({ x = coords.x, y = coords.y, z = coords.z }),
        heading,
        json.encode(props),
    })

    if not insertId or insertId == 0 then
        Debug('Failed to park vehicle: %s', plate)
        State.playerParkingLocks[src] = nil
        return false
    end

    -- 🔗 rde_carservice INTEGRATION: Use direct MySQL update instead of
    --    oxVeh:setStored('parked', true). Two reasons:
    --    1. setStored('parked', true) with despawn=true would DELETE the entity
    --       we want to keep in the world — the oxVeh tracking may or may not
    --       know about our server-spawned entity, making this a silent bomb.
    --    2. The generic value 'parked' was read by carservice as "vehicle in a
    --       garage" (stored IS NOT NULL), causing it to spawn a DUPLICATE entity
    --       → the "parked vehicle disappears" bug. 'rde_parking' is now excluded
    --       explicitly by carservice's delivery query.
    MySQL.update.await('UPDATE vehicles SET stored = ? WHERE id = ?', { 'rde_parking', vehicleId })

    -- 🆕 Register in the proximity index + spawned cache. The entity the
    -- player was just driving is still alive in the world right now — we
    -- adopt it instead of letting the proximity sweep spawn a duplicate.
    local vehicleCoords = vector3(coords.x, coords.y, coords.z)

    State.parkIndex[vehicleId] = {
        plate   = plate,
        coords  = vehicleCoords,
        heading = heading,
        locked  = 0,
        owner   = player.charId,
    }

    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if entity ~= 0 and DoesEntityExist(entity) then
        Entity(entity).state:set(Config.StatebagPrefix .. 'props', json.encode(props), true)

        State.spawnedVehicles[vehicleId] = {
            entity  = entity,
            netId   = netId,
            plate   = plate,
            coords  = vehicleCoords,
            heading = heading,
            props   = props,
            locked  = false,
            owner   = player.charId,
        }
    end

    PublishParkingState()

    Debug('Vehicle parked: %s (ID: %s)', plate, vehicleId)
    NostrPark(GetPlayerDisplayName(src), plate, coords)

    State.playerParkingLocks[src] = nil
    return true
end)

lib.callback.register('rde_parking:isVehicleParked', function(src, plate)
    plate       = TrimPlate(plate)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rde_parked_vehicles WHERE plate = ?', { plate })
    return count and count > 0
end)

-- ═══════════════════════════════════════════════════
--  🔒  Lock Sync Rate Limiting  (anti-exploit)
-- ═══════════════════════════════════════════════════

local LockLocks = {}

local function CanLock(src)
    local now  = GetGameTimer()
    local last = LockLocks[src]
    if last and (now - last) < Config.LockCooldown then return false end
    return true
end

-- ═══════════════════════════════════════════════════
--  🌐  Network Events
-- ═══════════════════════════════════════════════════

RegisterNetEvent('rde_parking:syncLock', function(netId, locked, plate)
    local src = source

    if not CanLock(src) then
        Debug('Lock sync rejected (cooldown): %s', src)
        return
    end
    LockLocks[src] = GetGameTimer()

    local player = GetPlayerCharacter(src)
    if not player then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    plate  = TrimPlate(plate)
    locked = locked and true or false

    -- 🛡️ Server validates EVERYTHING — the original version trusted the
    -- client's plate/netId blindly, letting anyone lock/unlock ANY vehicle.
    -- Confirm the requester actually owns this plate before touching anything.
    local owned = MySQL.scalar.await('SELECT 1 FROM vehicles WHERE plate = ? AND owner = ?', { plate, player.charId })
    if not owned then
        Debug('Lock sync rejected (not owner): %s by %s', plate, src)
        return
    end

    SetVehicleDoorsLocked(vehicle, locked and 2 or 1)

    -- 🔄 Single sync path — setting the entity statebag replicates to ALL
    -- clients automatically. No second TriggerClientEvent here (this used
    -- to fire both, which is the Hall-of-Shame "double broadcast" anti-pattern).
    Entity(vehicle).state:set(Config.StatebagPrefix .. 'locked', locked, true)

    local result = MySQL.single.await('SELECT vehicle_id FROM rde_parked_vehicles WHERE plate = ?', { plate })
    if result then
        MySQL.update.await('UPDATE rde_parked_vehicles SET locked = ? WHERE plate = ?', { DbBool(locked), plate })

        if State.spawnedVehicles[result.vehicle_id] then
            State.spawnedVehicles[result.vehicle_id].locked = locked
        end
        if State.parkIndex[result.vehicle_id] then
            State.parkIndex[result.vehicle_id].locked = locked and 1 or 0
        end

        PublishParkingState()
        Debug('Lock synced: %s (locked=%s)', plate, locked)
    end
end)

RegisterNetEvent('rde_parking:unparkVehicle', function(plate)
    local src    = source
    local player = GetPlayerCharacter(src)
    if not player then return end

    plate = TrimPlate(plate)

    local result = MySQL.single.await([[
        SELECT pv.vehicle_id
        FROM rde_parked_vehicles pv
        JOIN vehicles v ON pv.vehicle_id = v.id
        WHERE pv.plate = ? AND v.owner = ?
    ]], { plate, player.charId })

    if result then
        local vehicleId = result.vehicle_id
        MySQL.query.await('DELETE FROM rde_parked_vehicles WHERE vehicle_id = ?', { vehicleId })

        -- 🔗 Direct MySQL clear — consistent with parkVehicle's direct MySQL write.
        --    Also calls oxVeh:setStored(nil, false) as belt-and-suspenders for ox_core tracking.
        MySQL.update.await('UPDATE vehicles SET stored = NULL WHERE id = ?', { vehicleId })
        local oxVeh = GetOxVehicle(vehicleId)
        if oxVeh then pcall(function() oxVeh:setStored(nil, false) end) end

        State.spawnedVehicles[vehicleId] = nil
        State.parkIndex[vehicleId]       = nil

        TriggerClientEvent('rde_parking:vehicleUnparked', src, plate)
        NostrUnpark(GetPlayerDisplayName(src), plate)
        PublishParkingState()
        Debug('Vehicle unparked: %s (ID: %s)', plate, vehicleId)
    end
end)

-- ═══════════════════════════════════════════════════
--  🔗  rde_carservice INTEGRATION
--
--  When carservice delivers or picks up a vehicle, it fires server-side
--  AddEventHandler events that this block reacts to. This is the single
--  sync path that keeps both systems in agreement about what is "parked",
--  "in the world", or "in a garage" at any given moment.
--
--  vehicleDelivered: carservice moved the vehicle from garage → world.
--    Clear rde_parked_vehicles + State so the parking system treats it as
--    a fresh, unmanaged entity. Also notify the client to clear parkedCache
--    for this plate — without this, the player can't park the delivered
--    vehicle because parkedCache[plate] = true blocks ParkVehicle.
--
--  vehiclePickedUp: carservice moved the vehicle from world → garage.
--    The NPC driver took the entity away, so its entity will be cleaned up
--    by entityRemoved. We only need to remove the DB entry and State refs
--    so the proximity sweep doesn't attempt to respawn it from the stale
--    rde_parked_vehicles row on the next tick.
-- ═══════════════════════════════════════════════════

local function ClearParkedByPlate(plate, notifySource)
    if not plate or plate == '' then return end
    plate = TrimPlate(plate)

    local row = MySQL.single.await('SELECT vehicle_id FROM rde_parked_vehicles WHERE plate = ?', { plate })
    if not row then
        Debug('ClearParkedByPlate: plate %s not in rde_parked_vehicles — no-op', plate)
        return
    end

    local vehicleId = row.vehicle_id

    MySQL.query.await('DELETE FROM rde_parked_vehicles WHERE plate = ?', { plate })

    -- Only delete the entity if it's still the rde_parking-spawned one
    -- (identified by the rde_parking statebag). carservice may have
    -- already driven it away or spawned its own entity for this plate.
    local spawnedData = State.spawnedVehicles[vehicleId]
    if spawnedData and DoesEntityExist(spawnedData.entity) then
        local st = Entity(spawnedData.entity).state
        if st[Config.StatebagPrefix .. 'parked'] then
            DeleteEntity(spawnedData.entity)
            Debug('ClearParkedByPlate: deleted stale rde_parking entity for %s', plate)
        end
    end

    State.spawnedVehicles[vehicleId] = nil
    State.parkIndex[vehicleId]       = nil

    PublishParkingState()
    Debug('ClearParkedByPlate: cleared parked state for plate=%s', plate)

    -- Notify the requesting player's client to drop parkedCache[plate].
    -- Other clients don't have it in their parkedCache (it's per-character).
    if notifySource and notifySource > 0 then
        TriggerClientEvent('rde_parking:clearParkedCache', notifySource, plate)
    end
end

AddEventHandler('rde_carservice:vehicleDelivered', function(src, plate)
    Debug('rde_carservice:vehicleDelivered → plate=%s src=%s', plate, src)
    ClearParkedByPlate(plate, src)
end)

AddEventHandler('rde_carservice:vehiclePickedUp', function(src, plate)
    Debug('rde_carservice:vehiclePickedUp → plate=%s src=%s', plate, src)
    -- carservice already set stored=DefaultGarage; we only clear the parking row/State.
    ClearParkedByPlate(plate, src)
end)

-- Fired by rde_carservice BEFORE delivery starts when the vehicle is detected as
-- parked via rde_parking.
--
-- WHY NO DeleteEntity HERE:
-- Any server-side DeleteEntity propagates to ALL clients and frees the entity
-- handle in GTA's pool. If this happens while the carservice CLIENT is calling
-- CreateVehicle() for the delivery vehicle (progress bar = 2s, model load = 1s,
-- so CreateVehicle() happens ~3-5s after this event), GTA may hand the newly
-- freed handle to the delivery vehicle — making State.driverVehicle point to an
-- entity that the network then confirms as "deleted". The delivery tracking thread
-- detects DoesEntityExist(State.driverVehicle) = false → cancels. Even a 5s
-- SetTimeout isn't safe because CreateVehicle timing varies with model cache state.
--
-- SAFE APPROACH: delete from DB + clear parkIndex so the proximity SPAWN loop
-- won't re-create the entity. Keep State.spawnedVehicles[vehicleId] so the
-- existing proximity DESPAWN loop can remove the entity naturally after
-- despawnGraceMs (default 30s) once no players are nearby. By that point the
-- carservice delivery is long established with its own stable handle.
AddEventHandler('rde_carservice:prepareDeliveryOfParked', function(src, plate)
    Debug('rde_carservice:prepareDeliveryOfParked → plate=%s src=%s', plate, src)
    if not plate or plate == '' then return end
    plate = TrimPlate(plate)

    local row = MySQL.single.await('SELECT vehicle_id FROM rde_parked_vehicles WHERE plate = ?', { plate })
    if not row then
        Debug('prepareDeliveryOfParked: plate %s not in rde_parked_vehicles — no-op', plate)
        return
    end

    local vehicleId = row.vehicle_id

    -- Delete DB row: proximity spawn loop won't re-create this vehicle.
    MySQL.query.await('DELETE FROM rde_parked_vehicles WHERE plate = ?', { plate })

    -- Clear park index: removed from spawn candidates.
    -- DO NOT clear State.spawnedVehicles[vehicleId] — keep it so the proximity
    -- DESPAWN loop can clean up the entity safely after despawnGraceMs.
    State.parkIndex[vehicleId] = nil

    PublishParkingState()

    -- Tell the client to drop parkedCache[plate] so the parking ox_target
    -- options reset correctly once the carservice delivery completes.
    TriggerClientEvent('rde_parking:clearParkedCache', src, plate)
    Debug('prepareDeliveryOfParked: DB cleared for plate=%s, entity handed to proximity despawn', plate)
end)

-- ═══════════════════════════════════════════════════
--  👤  Player Handlers
-- ═══════════════════════════════════════════════════

AddEventHandler('ox:playerLoaded', function(src, userId, charId)
    Debug('Player loaded: %s (charId: %s)', src, charId)
    SetTimeout(5000, function()
        local player = GetPlayerCharacter(src)
        if not player then return end

        -- Send owned vehicles for ownership cache
        local vehicles = MySQL.query.await([[
            SELECT id as vehicleId, plate, model
            FROM vehicles WHERE owner = ?
        ]], { charId })

        if vehicles and #vehicles > 0 then
            TriggerClientEvent('rde_parking:updateOwnershipCache', src, vehicles)
        end

        -- Send parked plates so canInteract works without DB calls
        local parked = MySQL.query.await([[
            SELECT pv.plate
            FROM rde_parked_vehicles pv
            JOIN vehicles v ON pv.vehicle_id = v.id
            WHERE v.owner = ?
        ]], { charId })

        local plates = {}
        if parked then
            for _, row in ipairs(parked) do
                plates[#plates + 1] = row.plate
            end
        end
        TriggerClientEvent('rde_parking:updateParkedCache', src, plates)

        -- 🆕 Proximity sweep right now, so vehicles near this player's
        -- spawn point appear immediately instead of waiting for the next tick.
        RunProximitySweep()
    end)
end)

-- ⚠️  BUG-FIX (kept from original): capture source BEFORE any yields to avoid shadowing
AddEventHandler('playerDropped', function()
    local src = source
    State.playerParkingLocks[src] = nil
    LockLocks[src]                = nil
    Debug('Locks released for disconnected player: %s', src)
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    for vehicleId, data in pairs(State.spawnedVehicles) do
        if data.entity == entity then
            State.spawnedVehicles[vehicleId] = nil
            Debug('Vehicle removed from cache: %s', vehicleId)
            PublishParkingState()
            break
        end
    end
end)

-- ═══════════════════════════════════════════════════
--  🗑️  Auto-Delete Scheduler
-- ═══════════════════════════════════════════════════

if Config.AutoDeleteParkedVehicles and Config.AutoDeleteAfterDays > 0 then
    CreateThread(function()
        while true do
            Wait(86400000) -- 24 hours
            DeleteOldParkedVehicles()
        end
    end)
end

-- ═══════════════════════════════════════════════════
--  👑  Admin Commands  (lib.addCommand — RDE standard)
-- ═══════════════════════════════════════════════════

lib.addCommand('parkingstats', {
    help       = 'Show parking system statistics',
    restricted = 'group.admin',
}, function(src)
    local spawned = TableCount(State.spawnedVehicles)
    local indexed = TableCount(State.parkIndex)
    local dbCount = MySQL.scalar.await('SELECT COUNT(*) FROM rde_parked_vehicles') or 0

    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'ℹ️ Parking System Stats',
        description = ('🚗 **Spawned (nearby):** %d\n📍 **Indexed (total):** %d\n💾 **DB Parked:** %d'):format(
            spawned, indexed, dbCount),
        type     = 'info',
        duration = 10000,
    })
end)

lib.addCommand('parkingreload', {
    help       = 'Reload all parked vehicles',
    restricted = 'group.admin',
}, function(src)
    for _, data in pairs(State.spawnedVehicles) do
        if DoesEntityExist(data.entity) then DeleteEntity(data.entity) end
    end
    State.spawnedVehicles    = {}
    State.playerParkingLocks = {}

    LoadParkingIndex()
    RunProximitySweep()
    PublishParkingState()

    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Parking Reload', description = 'All vehicles reloaded', type = 'success',
    })
    Debug('Admin reload triggered by %s', src)
end)

lib.addCommand('parkingcleanup', {
    help       = 'Delete vehicles older than AutoDeleteAfterDays',
    restricted = 'group.admin',
}, function(src)
    DeleteOldParkedVehicles()
    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Cleanup Complete', description = 'Old parked vehicles removed', type = 'success',
    })
end)

-- ═══════════════════════════════════════════════════
--  🚀  Startup Banner
-- ═══════════════════════════════════════════════════

CreateThread(function()
    local version     = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
    local libVersion  = GetResourceMetadata('ox_lib',  'version', 0) or '?'
    local coreVersion = GetResourceMetadata('ox_core', 'version', 0) or '?'

    print('^5═══════════════════════════════════════════════════════^7')
    print('^5██████╗  █████╗ ██████╗ ██╗  ██╗██╗███╗   ██╗ ██████╗^7')
    print('^5██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██║████╗  ██║██╔════╝^7')
    print('^5██████╔╝███████║██████╔╝█████╔╝ ██║██╔██╗ ██║██║  ███╗^7')
    print('^5██╔═══╝ ██╔══██║██╔══██╗██╔═██╗ ██║██║╚██╗██║██║   ██║^7')
    print('^5██║     ██║  ██║██║  ██║██║  ██╗██║██║ ╚████║╚██████╔╝^7')
    print('^5╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝^7')
    print('^5═══════════════════════════════════════════════════════^7')
    print('^5  RDE Parking System ^3v' .. version .. '^7')
    print(('^5  ox_lib ^3%s^5  •  ox_core ^3%s^7'):format(libVersion, coreVersion))
    print('^5═══════════════════════════════════════════════════════^7')

    if Config.Debug then
        print('^3[PARKING]^7 ^1DEBUG MODE ENABLED^7')
        print(('  🌐 Locale:           ^2%s^7'):format(Config.Locale))
        print(('  📅 Auto-Delete:      ^2%d days^7'):format(Config.AutoDeleteAfterDays))
        print(('  📏 Spawn distance:   ^2%.1fm^7'):format(Config.SpawnDistance))
        print(('  📡 Proximity sweep:  ^2every %dms^7'):format(Config.Performance.proximityCheckInterval))
        print('  Commands: /parkingstats  /parkingreload  /parkingcleanup')
    end

    print('^2[PARKING]^7 Server ready! 🅿️')
    print('^5═══════════════════════════════════════════════════════^7')
end)

Debug('Server initialised | Locale: %s', Config.Locale)
