-- ==========================================
-- qbx_pthud | Nitro Client Script
-- Nitro boost + purge sistemi
-- Author: Mirage (ND_Nitro tabanlı)
-- ==========================================

local display        = false
local preventNitro   = false
local purge          = {}
local nosActivated, purgeActivated = false, false
local keybindNos, keybindPurge
local vehicleModel, vehicleMaxSpeed
local screenEffect   = false
local blueFlames     = {}

---@param status boolean
local function setHUD(status)
    display = status
end

local function enableScreenEffect(enable)
    if enable then
        screenEffect = true
        SetTimecycleModifier("rply_motionblur")
        ShakeGameplayCam("SKY_DIVING_SHAKE", 0.25)
        return
    end
    screenEffect = false
    StopGameplayCamShaking(true)
    SetTransitionTimecycleModifier("default", 0.35)
end

---@param checkDriver boolean
---@return boolean
local function isInVehicle(checkDriver)
    return checkDriver and cache.seat == -1 and cache.vehicle or cache.vehicle
end

---@param veh entity
---@return boolean
local function vehicleHasNitro(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    local value = Entity(veh).state.nd_nitro_nos
    return value and value > 0
end

---@param setType string
---@param value number
local function vehicleSetValue(setType, value)
    local veh = isInVehicle(true)
    if not veh or not DoesEntityExist(veh) then return end
    Entity(veh).state:set(("nd_nitro_%s"):format(setType), value, true)
end

---@param veh entity
---@param setType string
---@param value boolean
local function vehicleActivate(veh, setType, value)
    if not veh or not DoesEntityExist(veh) then return end
    Entity(veh).state:set(("nd_nitro_activated_%s"):format(setType), value, true)
end

---@param veh number
---@return number, number
local function vehicleGetValues(veh)
    if not veh or not DoesEntityExist(veh) then return 0, 0 end
    local state = Entity(veh).state
    return state.nd_nitro_nos or 0, state.nd_nitro_purge or 0
end

local function vehicleAddNitro()
    vehicleSetValue("nos", 100.0)
    vehicleSetValue("purge", 0.0)
    setHUD(true)
end

local function startedNos(veh)
    local noslvl, purgelvl = vehicleGetValues(veh)
    if purgelvl < 100 then
        vehicleSetValue("purge", math.min(purgelvl + 4.0, 100))
        if preventNitro then preventNitro = false end
    else
        if Config.Nitro.RequirePurge then
            preventNitro = true
            return vehicleActivate(veh, "flames", false)
        end
    end
    local lvl = math.max(noslvl - 1.0, 0)
    vehicleSetValue("nos", lvl)
    if lvl <= 0 then
        vehicleActivate(veh, "flames", false)
        vehicleActivate(veh, "purge", false)
        setHUD(false)
    end
end

local function startedPurge(veh)
    local noslvl, purgelvl = vehicleGetValues(veh)
    if purgelvl < 100 then preventNitro = false end
    if purgelvl > 0 then
        vehicleSetValue("purge", math.max(purgelvl - 15.0, 0))
    else
        local lvl = math.max(noslvl - 5.0, 0)
        vehicleSetValue("nos", lvl)
        if lvl <= 0 then
            vehicleActivate(veh, "flames", false)
            vehicleActivate(veh, "purge", false)
            setHUD(false)
        end
    end
end

local function nitroCheck(veh)
    if not DoesEntityExist(veh) then return false end
    local noslvl, purgelvl = vehicleGetValues(veh)
    if noslvl <= 0 or purgelvl >= 100 then return false end

    local speed = GetEntitySpeed(veh)
    local mph   = speed * 2.236936
    local model = GetEntityModel(veh)
    if model ~= vehicleModel then
        vehicleModel    = model
        vehicleMaxSpeed = GetVehicleModelMaxSpeed(model)
    end

    if mph < 5.0 then
        SetControlNormal(0, 71, 0.5)
    else
        local multiplier = 2.0 * vehicleMaxSpeed / math.max(speed, 0.01)
        SetVehicleCheatPowerIncrease(veh, multiplier)
    end

    if screenEffect and mph < 15.0 then
        enableScreenEffect(false)
    elseif not screenEffect and mph > 15.0 then
        enableScreenEffect(true)
    end
    return true
end

local function displayNitro(veh)
    local noslvl = vehicleGetValues(veh)
    if not noslvl or noslvl <= 0 then return end
    setHUD(true)
end

-- ==========================================
-- BLUE FLAMES
-- ==========================================
function CreateBlueFlames(veh)
    if blueFlames[veh] then return end
    blueFlames[veh] = {}
    local bones = {"exhaust","exhaust_2","exhaust_3","exhaust_4","exhaust_5","exhaust_6"}
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(0) end
    for _, bone in pairs(bones) do
        local boneIndex = GetEntityBoneIndexByName(veh, bone)
        if boneIndex ~= -1 then
            UseParticleFxAsset("core")
            local ptfx = StartParticleFxLoopedOnEntityBone("veh_backfire", veh, 0,0,0, 0,0,0, boneIndex, 2.0, false, false, false)
            SetParticleFxLoopedColour(ptfx, 0.0, 0.3, 1.0, false)
            table.insert(blueFlames[veh], ptfx)
        end
    end
end

function StopBlueFlames(veh)
    if blueFlames[veh] then
        for _, ptfx in pairs(blueFlames[veh]) do
            StopParticleFxLooped(ptfx, 0)
            RemoveParticleFx(ptfx, 0)
        end
        blueFlames[veh] = nil
    end
end

-- ==========================================
-- EXPORTS & KEYBINDS
-- ==========================================
exports("nos", function(data, slot)
    local veh = isInVehicle(true)
    if not veh or not DoesEntityExist(veh) then return end
    if data then exports.ox_inventory:useItem(data) end
    vehicleAddNitro()
end)

keybindNos = lib.addKeybind({
    name        = "nd_nitro_boost",
    description = "Nitro: Boost",
    defaultKey  = "LSHIFT",
    onPressed = function(self)
        if not IsControlPressed(0, 71) then Wait(10) end
        local veh = isInVehicle(true)
        if preventNitro or not veh or not DoesEntityExist(veh) or not vehicleHasNitro(veh) or keybindNos.disabled then return end
        if not display then setHUD(true) end
        self.isPressed = true
        keybindPurge:disable(true)
        lib.requestNamedPtfxAsset("veh_xs_vehicle_mods")
        vehicleActivate(veh, "flames", true)
        CreateThread(function()
            while self.isPressed and isInVehicle(true) == veh and DoesEntityExist(veh) do
                Wait(1000)
                startedNos(veh)
            end
        end)
    end,
    onReleased = function(self)
        if screenEffect then enableScreenEffect(false) end
        self.isPressed = false
        local veh = isInVehicle(true)
        if not veh or not DoesEntityExist(veh) or not vehicleHasNitro(veh) then return end
        keybindPurge:disable(false)
        vehicleActivate(veh, "flames", false)
    end
})

keybindPurge = lib.addKeybind({
    name        = "nd_nitro_purge",
    description = "Nitro: Purge",
    defaultKey  = "LMENU",
    onPressed = function(self)
        local veh = isInVehicle(true)
        if not veh or not DoesEntityExist(veh) or not vehicleHasNitro(veh) or keybindPurge.disabled then return end
        if not display then setHUD(true) end
        self.isPressed = true
        keybindNos:disable(true)
        vehicleActivate(veh, "purge", true)
        CreateThread(function()
            while self.isPressed and isInVehicle(true) == veh and DoesEntityExist(veh) do
                Wait(1000)
                startedPurge(veh)
            end
        end)
    end,
    onReleased = function(self)
        self.isPressed = false
        local veh = isInVehicle(true)
        if not veh or not DoesEntityExist(veh) or not vehicleHasNitro(veh) then return end
        keybindNos:disable(false)
        vehicleActivate(veh, "purge", false)
    end
})

-- ==========================================
-- CACHE HANDLERS
-- ==========================================
AddEventHandler("onResourceStart", function(resourceName)
    if cache.resource ~= resourceName then return end
    Wait(500)
    displayNitro(cache.vehicle)
end)

lib.onCache("vehicle", function(value)
    if not value and screenEffect then enableScreenEffect(false) end
    local isDriver = value and GetPedInVehicleSeat(value, -1) == cache.ped
    if not isDriver or not value then return setHUD(false) end
    displayNitro(value)
end)

lib.onCache("seat", function(seat)
    if seat ~= -1 then return setHUD(false) end
    displayNitro(cache.vehicle)
end)

-- ==========================================
-- STATEBAG: NİTRO FLAMES
-- ==========================================
AddStateBagChangeHandler("nd_nitro_activated_flames", nil, function(bagName, key, value, reserved, replicated)
    if replicated or value == nil then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or not DoesEntityExist(entity) then return end

    lib.requestNamedPtfxAsset("veh_xs_vehicle_mods")
    SetVehicleNitroEnabled(entity, value)
    EnableVehicleExhaustPops(entity, not value)
    SetVehicleBoostActive(entity, value)

    if value then
        CreateBlueFlames(entity)
    else
        StopBlueFlames(entity)
    end

    local driver    = isInVehicle(true)  == entity
    local passenger = isInVehicle(false) == entity
    if not value then
        if driver then SetVehicleCheatPowerIncrease(entity, 1.0) end
        if (driver or passenger) and screenEffect then enableScreenEffect(false) end
        return
    end

    if not driver and not passenger then return end
    CreateThread(function()
        local state = Entity(entity).state
        while state.nd_nitro_activated_flames and nitroCheck(entity) do Wait(0) end
        if screenEffect then enableScreenEffect(false) end
    end)
end)

-- ==========================================
-- STATEBAG: PURGE PARTIKÜL
-- ==========================================
AddStateBagChangeHandler("nd_nitro_activated_purge", nil, function(bagName, key, value, reserved, replicated)
    if replicated or value == nil then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or not DoesEntityExist(entity) then return end

    if not value then
        local cp = purge[entity]
        if cp then
            if cp.left  then StopParticleFxLooped(cp.left)  end
            if cp.right then StopParticleFxLooped(cp.right) end
        end
        purge[entity] = nil
        return
    end

    local function spawnPurgeParticles(ox, oy, oz, rotY)
        lib.requestNamedPtfxAsset("core")
        UseParticleFxAssetNextCall("core")
        local left  = StartParticleFxLoopedOnEntity("ent_sht_steam", entity, ox - 0.5, oy, oz, 40.0, rotY, 0.0, 0.3, false, false, false)
        UseParticleFxAssetNextCall("core")
        local right = StartParticleFxLoopedOnEntity("ent_sht_steam", entity, ox + 0.5, oy, oz, 40.0, -rotY, 0.0, 0.3, false, false, false)
        purge[entity] = {left = left, right = right}
        PlaySoundFromEntity(-1, "Air_Release", entity, "DLC_Biker_Computer_Sounds", false, 0)
    end

    local bonnet = GetEntityBoneIndexByName(entity, "bonnet")
    if bonnet ~= -1 then
        local pos = GetWorldPositionOfEntityBone(entity, bonnet)
        local off = GetOffsetFromEntityGivenWorldCoords(entity, pos.x, pos.y, pos.z)
        spawnPurgeParticles(off.x, off.y + 0.05, off.z, -20.0)
        return
    end

    local engine = GetEntityBoneIndexByName(entity, "engine")
    if engine ~= -1 then
        local pos = GetWorldPositionOfEntityBone(entity, engine)
        local off = GetOffsetFromEntityGivenWorldCoords(entity, pos.x, pos.y, pos.z)
        spawnPurgeParticles(off.x, off.y - 0.2, off.z + 0.2, 20.0)
    end
end)

-- ==========================================
-- QBCore Item: Nitro kurulumu
-- ==========================================
-- Config'e göre nitro takılabilir mi? (elektrikli / sınıf / model engeli)
local function modelInList(model, list)
    for _, name in ipairs(list or {}) do
        if model == joaat(name) then return true end
    end
    return false
end

local function CanInstallNitro(veh)
    local cfg   = Config.Nitro
    local model = GetEntityModel(veh)

    if modelInList(model, cfg.AllowedModels) then return true end
    if modelInList(model, cfg.BlockedModels) then return false end

    local class = GetVehicleClass(veh)
    if cfg.BlockedClasses and cfg.BlockedClasses[class] then return false end

    if cfg.BlockElectric then
        -- Sınıfı motor/bisiklet/tekne olmayıp tek vitesli araç = elektrikli (client.lua ile aynı mantık)
        local autoElectric = GetVehicleHighGear(veh) == 1 and class ~= 8 and class ~= 13 and class ~= 14
        if autoElectric or modelInList(model, cfg.ElectricModels) then return false end
    end
    return true
end

RegisterNetEvent('nitrous:client:Install', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
        if not CanInstallNitro(veh) then
            exports['qb-core']:GetCoreObject().Functions.Notify(Config.Nitro.BlockedMessage or "Bu araca nitro takılamaz!", "error")
            return
        end
        local state = Entity(veh).state
        if state.nd_nitro_nos and state.nd_nitro_nos >= 100 then
            exports['qb-core']:GetCoreObject().Functions.Notify("Bu aracın nitrosu zaten tamamen dolu!", "error")
            return
        end
        local text = state.nd_nitro_nos and "Nitro Yenileniyor..." or "Nitro Tesisatı Kuruluyor..."
        exports['qb-core']:GetCoreObject().Functions.Progressbar("install_nos", text, 5000, false, true, {
            disableMovement = false, disableCarMovement = true, disableMouse = false, disableCombat = true,
        }, {}, {}, {}, function()
            TriggerServerEvent('nitrous:server:Apply', VehToNet(veh))
        end, function()
            exports['qb-core']:GetCoreObject().Functions.Notify("İptal edildi.", "error")
        end)
    else
        exports['qb-core']:GetCoreObject().Functions.Notify("Bir aracın sürücü koltuğunda olmalısın!", "error")
    end
end)
