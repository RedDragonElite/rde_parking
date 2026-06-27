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
--  📊  State
-- ═══════════════════════════════════════════════════

local State = {
    ownershipCache = {},  -- [plate] = vehicleId
    parkedCache    = {},  -- [plate] = true
    parkCooldown   = 0,
    lockCooldown   = 0,
    busy           = false,
}

-- 🔇 Suppresses re-playing lock effects on the player's OWN action when the
-- statebag echo arrives back from the server a moment later. Replaces the
-- old `triggeredBy == cache.serverId` check from the removed net event.
local RecentLocalLock = {}   -- [netId] = GetGameTimer()

-- 🔇 Avoids re-applying vehicle props more than once per entity when the
-- props statebag handler fires (e.g. on resync).
local AppliedProps = {}      -- [entity] = true

-- ═══════════════════════════════════════════════════
--  🛠️  Utility
-- ═══════════════════════════════════════════════════

local function Debug(...)
    if not Config.Debug then return end
    print(('[^5RDE PARKING^7][^3CLIENT^7] %s'):format(table.concat({...}, ' ')))
end

local function GetVehiclePlate(vehicle)
    return GetVehicleNumberPlateText(vehicle):gsub('%s+', '')
end

local function IsOwnedVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    return State.ownershipCache[GetVehiclePlate(vehicle)] ~= nil
end

local function IsBlacklisted(vehicle)
    return Config.BlacklistedClasses[GetVehicleClass(vehicle)] == true
end

local function IsParkedLocally(vehicle)
    return State.parkedCache[GetVehiclePlate(vehicle)] == true
end

-- ═══════════════════════════════════════════════════
--  🎬  Animation Helper
-- ═══════════════════════════════════════════════════

local function PlayAnim(dict, anim, flag, duration)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, anim, 4.0, -4.0, duration or -1, flag or 0, 0, false, false, false)
end

local function StopAnim(dict, anim)
    StopAnimTask(cache.ped, dict, anim, 2.0)
end

-- ═══════════════════════════════════════════════════
--  🔊  Lock / Park Effects
--  ⚠️  SoundVehicleHornThisFrame MUST be called every frame
--      SetVehicleIndicatorLights = actual blinkers (not headlights)
-- ═══════════════════════════════════════════════════

local function PlayVehicleEffects(vehicle, locking)
    -- 🔊 Sound
    local snd = locking and Config.ParkSound or Config.UnparkSound
    if snd and snd.enabled then
        PlaySoundFrontend(-1, snd.audioName, snd.audioRef, true)
    end

    -- 📯 Horn — must loop every frame for duration
    local hornMs  = locking and 350 or 150   -- double beep lock, short pip unlock
    local hornEnd = GetGameTimer() + hornMs
    repeat
        SoundVehicleHornThisFrame(vehicle)
        Wait(0)
    until GetGameTimer() >= hornEnd

    if locking then
        -- Second beep for lock (double-beep like a real car)
        Wait(120)
        hornEnd = GetGameTimer() + 200
        repeat
            SoundVehicleHornThisFrame(vehicle)
            Wait(0)
        until GetGameTimer() >= hornEnd
    end

    -- 💡 Indicator / hazard flash
    if Config.EnableHornFlash then
        local flashes = locking and Config.FlashCount or 1
        for i = 1, flashes do
            SetVehicleIndicatorLights(vehicle, 0, true)   -- left blinker
            SetVehicleIndicatorLights(vehicle, 1, true)   -- right blinker
            Wait(Config.FlashDelay)
            SetVehicleIndicatorLights(vehicle, 0, false)
            SetVehicleIndicatorLights(vehicle, 1, false)
            if i < flashes then Wait(Config.FlashDelay) end
        end
    end
end

-- ═══════════════════════════════════════════════════
--  🔒  Lock Vehicle
-- ═══════════════════════════════════════════════════

local function LockVehicle(vehicle)
    if State.busy then return end
    if GetGameTimer() - State.lockCooldown < Config.LockCooldown then return end

    local isLocked  = GetVehicleDoorLockStatus(vehicle) >= 2
    local plate     = GetVehiclePlate(vehicle)
    local newLocked = not isLocked
    local netId     = NetworkGetNetworkIdFromEntity(vehicle)

    State.busy = true

    -- 🔑 Key-fob gesture: raise hand and press button (upper body only, flag 50)
    local animDict = 'mp_common'
    local animName = 'givetake1_b'
    PlayAnim(animDict, animName, 50, Config.LockDuration)

    local ok = lib.progressCircle({
        duration     = Config.LockDuration,
        position     = 'bottom',
        label        = isLocked and T('unlocking_vehicle') or T('locking_vehicle'),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = false, car = false, combat = false },
    })

    StopAnim(animDict, animName)

    if ok then
        -- Mark this netId as "just handled locally" so the statebag echo
        -- coming back from the server doesn't replay the effects a second time.
        RecentLocalLock[netId] = GetGameTimer()

        SetVehicleDoorsLocked(vehicle, newLocked and 2 or 1)
        TriggerServerEvent('rde_parking:syncLock', netId, newLocked, plate)

        CreateThread(function()
            PlayVehicleEffects(vehicle, newLocked)
        end)

        lib.notify({
            title    = newLocked and T('vehicle_locked') or T('vehicle_unlocked'),
            type     = 'success',
            duration = 3000,
        })
        State.lockCooldown = GetGameTimer()
        Debug('Lock toggled: %s → locked=%s', plate, newLocked)
    end

    State.busy = false
end

-- ═══════════════════════════════════════════════════
--  🅿️  Park Vehicle
-- ═══════════════════════════════════════════════════

local function ParkVehicle(vehicle)
    if State.busy then return end
    if GetGameTimer() - State.parkCooldown < Config.ParkCooldown then return end

    if IsBlacklisted(vehicle) then
        lib.notify({ title = T('not_your_vehicle'), type = 'error' })
        return
    end

    if not IsOwnedVehicle(vehicle) then
        lib.notify({ title = T('not_your_vehicle'), type = 'error' })
        return
    end

    if Config.RequireEngineOff and GetIsVehicleEngineRunning(vehicle) then
        lib.notify({ title = T('engine_must_be_off'), type = 'error' })
        return
    end

    if GetVehicleBodyHealth(vehicle) < Config.MinHealthToPark then
        lib.notify({ title = T('vehicle_damaged'), type = 'error' })
        return
    end

    if IsParkedLocally(vehicle) then
        lib.notify({ title = T('parking_failed'), type = 'error' })
        return
    end

    -- Exit vehicle first if inside
    if GetVehiclePedIsIn(cache.ped, false) == vehicle then
        TaskLeaveVehicle(cache.ped, vehicle, 0)
        local t = 0
        while GetVehiclePedIsIn(cache.ped, false) == vehicle and t < 40 do
            Wait(100)
            t += 1
        end
    end

    local plate   = GetVehiclePlate(vehicle)
    local coords  = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local props   = lib.getVehicleProperties(vehicle)

    if not props then
        lib.notify({ title = T('parking_failed'), type = 'error' })
        return
    end

    State.busy = true

    -- 📋 Park anim: check clipboard / confirm parking spot
    local parkAnimDict = 'amb@world_human_clipboard@male@base'
    local parkAnimName = 'base'
    PlayAnim(parkAnimDict, parkAnimName, 49, Config.ParkDuration)

    local ok = lib.progressCircle({
        duration     = Config.ParkDuration,
        position     = 'bottom',
        label        = T('parking_vehicle'),
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true },
    })

    StopAnim(parkAnimDict, parkAnimName)

    if ok then
        -- 🆕 netId is now sent along so the server can adopt this exact
        -- entity into its proximity/spawned cache instead of treating it
        -- as "unspawned" (which would have caused a duplicate vehicle the
        -- next time the proximity sweep ran).
        local success = lib.callback.await('rde_parking:parkVehicle', false, plate, coords, heading, props, NetworkGetNetworkIdFromEntity(vehicle))

        if success then
            State.parkedCache[plate] = true

            -- Lock it + effects (vehicle stays in world)
            SetVehicleDoorsLocked(vehicle, 2)
            SetVehicleEngineOn(vehicle, false, true, true)

            PlayVehicleEffects(vehicle, true)   -- double beep + indicator flash

            lib.notify({ title = T('vehicle_parked'), type = 'success', duration = 5000 })
            State.parkCooldown = GetGameTimer()
            Debug('Parked: %s', plate)
        else
            lib.notify({ title = T('parking_failed'), type = 'error' })
        end
    end

    State.busy = false
end

-- ═══════════════════════════════════════════════════
--  🚗  Retrieve Vehicle
-- ═══════════════════════════════════════════════════

local function UnparkVehicle(vehicle)
    if State.busy then return end
    if not IsOwnedVehicle(vehicle) then
        lib.notify({ title = T('not_your_vehicle'), type = 'error' })
        return
    end

    local plate = GetVehiclePlate(vehicle)
    State.busy  = true

    local ok = lib.progressCircle({
        duration     = 1500,
        position     = 'bottom',
        label        = T('retrieving_vehicle'),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = false, combat = false },
    })

    if ok then
        SetVehicleDoorsLocked(vehicle, 1)
        PlayVehicleEffects(vehicle, false)   -- single pip + flash

        State.parkedCache[plate] = nil
        TriggerServerEvent('rde_parking:unparkVehicle', plate)
        Debug('Unparked: %s', plate)
    end

    State.busy = false
end

-- ═══════════════════════════════════════════════════
--  🎯  ox_target
-- ═══════════════════════════════════════════════════
--
-- ⚠️  TWO separate entries for lock/unlock — NOT one entry with dynamic label.
--     ox_target ignores the second return value of canInteract for addGlobalVehicle.
--     Each entry has its own canInteract checking current lock state → correct label
--     AND correct icon always.
--
-- ⚠️  GetResourceState('ox_target') — NOT `exports.ox_target` which is always a table.

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    Wait(100)

    exports.ox_target:addGlobalVehicle({

        -- 🔒 Lock — only shows when vehicle is UNLOCKED
        {
            name        = 'rde_parking_lock',
            icon        = 'fa-solid fa-lock',
            label       = T('target_lock'),
            distance    = Config.LockDistance,
            canInteract = function(entity)
                if GetVehiclePedIsIn(cache.ped, false) ~= 0 then return false end
                if not IsOwnedVehicle(entity) then return false end
                return GetVehicleDoorLockStatus(entity) < 2  -- show only when UNLOCKED
            end,
            onSelect = function(data) LockVehicle(data.entity) end,
        },

        -- 🔓 Unlock — only shows when vehicle is LOCKED
        {
            name        = 'rde_parking_unlock',
            icon        = 'fa-solid fa-lock-open',
            label       = T('target_unlock'),
            distance    = Config.LockDistance,
            canInteract = function(entity)
                if GetVehiclePedIsIn(cache.ped, false) ~= 0 then return false end
                if not IsOwnedVehicle(entity) then return false end
                return GetVehicleDoorLockStatus(entity) >= 2  -- show only when LOCKED
            end,
            onSelect = function(data) LockVehicle(data.entity) end,
        },

        -- 🅿️ Park — owned, not blacklisted, not already parked
        {
            name        = 'rde_parking_park',
            icon        = 'fa-solid fa-square-parking',
            label       = T('target_park'),
            distance    = Config.ParkDistance,
            canInteract = function(entity)
                if not IsOwnedVehicle(entity) then return false end
                if IsBlacklisted(entity) then return false end
                return not IsParkedLocally(entity)
            end,
            onSelect = function(data) ParkVehicle(data.entity) end,
        },

        -- 🚗 Retrieve — owned AND parked
        {
            name        = 'rde_parking_unpark',
            icon        = 'fa-solid fa-car-on',
            label       = T('target_unpark'),
            distance    = Config.ParkDistance,
            canInteract = function(entity)
                if GetVehiclePedIsIn(cache.ped, false) ~= 0 then return false end
                if not IsOwnedVehicle(entity) then return false end
                return IsParkedLocally(entity)
            end,
            onSelect = function(data) UnparkVehicle(data.entity) end,
        },
    })

    Debug('ox_target registered ✅')
end)

-- ═══════════════════════════════════════════════════
--  📨  Network Events
-- ═══════════════════════════════════════════════════

RegisterNetEvent('rde_parking:applyVehicleProps', function(netId, props)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end
    lib.setVehicleProperties(vehicle, props)
    AppliedProps[vehicle] = true
    Debug('Props applied (broadcast) — netId: %s', netId)
end)

RegisterNetEvent('rde_parking:vehicleUnparked', function(plate)
    lib.notify({ title = T('vehicle_unparked'), type = 'success', duration = 4000 })
    Debug('Unparked confirmed: %s', plate)
end)

-- 🔗 rde_carservice INTEGRATION
-- Fired by the parking server when carservice delivers or picks up a vehicle
-- that was previously parked via rde_parking. Clears parkedCache[plate] so
-- the player can park the delivered vehicle without hitting the "IsParkedLocally"
-- guard in ParkVehicle, and so the ox_target options show correctly.
RegisterNetEvent('rde_parking:clearParkedCache', function(plate)
    if not plate or plate == '' then return end
    plate = plate:gsub('%s+', '')
    State.parkedCache[plate] = nil
    Debug('parkedCache cleared for plate=%s (carservice integration)', plate)
end)

RegisterNetEvent('rde_parking:updateOwnershipCache', function(vehicles)
    State.ownershipCache = {}
    for _, v in ipairs(vehicles) do
        State.ownershipCache[v.plate:gsub('%s+', '')] = v.vehicleId
    end
    Debug('Ownership cache: %d vehicles', #vehicles)
end)

RegisterNetEvent('rde_parking:updateParkedCache', function(plates)
    State.parkedCache = {}
    for _, plate in ipairs(plates) do
        State.parkedCache[plate:gsub('%s+', '')] = true
    end
    Debug('Parked cache: %d plates', #plates)
end)

-- ═══════════════════════════════════════════════════
--  🏷️  Statebag Handlers  (RDE OX Standards v2)
--  Single sync path for lock state — the server no longer fires a parallel
--  TriggerClientEvent, it only sets the entity statebag. This handler reacts
--  for every client (including the one who initiated it, hence the
--  RecentLocalLock dedup check) and also for anyone who streams the vehicle
--  in later (late joiners, players returning from far away).
--
--  ⚠️  AddStateBagChangeHandler's keyFilter is an EXACT match, not a prefix
--      match (lesson learned the hard way in rde_crew) — so we pass the
--      full, exact statebag key here, not just Config.StatebagPrefix.
-- ═══════════════════════════════════════════════════

AddStateBagChangeHandler(Config.StatebagPrefix .. 'locked', nil, function(bagName, _, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 2 then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local now   = GetGameTimer()

    SetVehicleDoorsLocked(entity, value and 2 or 1)

    if RecentLocalLock[netId] and (now - RecentLocalLock[netId]) < 2000 then
        -- We already applied this + played effects locally — don't double up.
        return
    end

    CreateThread(function()
        PlayVehicleEffects(entity, value)
    end)
end)

AddStateBagChangeHandler(Config.StatebagPrefix .. 'props', nil, function(bagName, _, value)
    if not value or value == '' then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if AppliedProps[entity] then return end

    local ok, props = pcall(json.decode, value)
    if ok and props then
        lib.setVehicleProperties(entity, props)
        AppliedProps[entity] = true
        Debug('Props applied (statebag) — entity: %s', entity)
    end
end)

AddEventHandler('entityRemoved', function(entity)
    AppliedProps[entity] = nil
end)

-- ═══════════════════════════════════════════════════
--  🚗  Auto-Retrieve on Engine Start
--  Wenn man in einem geparkten Auto sitzt und den
--  Motor startet → automatisch aus DB entfernen
-- ═══════════════════════════════════════════════════

CreateThread(function()
    local lastVehicle   = nil
    local engineWasOff  = true

    while true do
        Wait(500)

        local vehicle = GetVehiclePedIsIn(cache.ped, false)

        if vehicle ~= 0 and IsOwnedVehicle(vehicle) then
            local plate     = GetVehiclePlate(vehicle)
            local engineOn  = GetIsVehicleEngineRunning(vehicle)

            -- Detect engine just turned ON while vehicle is parked
            if IsParkedLocally(vehicle) and engineOn and (vehicle ~= lastVehicle or engineWasOff) then
                Debug('Engine started in parked vehicle %s — auto-retrieving', plate)

                State.parkedCache[plate] = nil
                TriggerServerEvent('rde_parking:unparkVehicle', plate)

                lib.notify({
                    title    = T('vehicle_unparked'),
                    type     = 'success',
                    duration = 3000,
                })
            end

            engineWasOff = not engineOn
            lastVehicle  = vehicle
        else
            engineWasOff = true
            lastVehicle  = nil
        end
    end
end)

-- ═══════════════════════════════════════════════════
--  🧹  Cleanup
-- ═══════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    State.ownershipCache = {}
    State.parkedCache    = {}
    State.busy           = false
end)

Debug('Client initialised | Locale: ' .. Config.Locale)
