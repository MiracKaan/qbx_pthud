-- ==========================================
-- qbx_pthud | Unified Client Script
-- Player HUD + Car HUD + Minimap + Nitro
-- Author: Mirage
-- ==========================================

local QBCore = exports["qb-core"]:GetCoreObject()

-- ==========================================
-- OYUNCU VERİ TAKİBİ
-- ==========================================
local hunger         = 100
local thirst         = 100
local stress         = 0
local isBleeding     = false
local isBoneBroken   = false
local bleedPercent   = 0
local bleedTimer     = 0
local isTalkingOnRadio = false
local pName          = "Unknown"
local pJob           = "Unemployed"
local pCash          = 0
local pBank          = 0
local staminaPenalty = 0.0
local finalStamina   = 100
local cinematicMode  = false
local devmode        = false
local showMinimap    = true

-- ==========================================
-- PLAYER DATA YARDIMCI FONKSİYONU
-- ==========================================
local function updatePlayerDetails(PlayerData)
    if not PlayerData then return end
    if PlayerData.charinfo then
        pName = (PlayerData.charinfo.firstname or "") .. " " .. (PlayerData.charinfo.lastname or "")
    end
    if PlayerData.job then
        local jobName   = PlayerData.job.label or ""
        local gradeName = ""
        if PlayerData.job.grade and PlayerData.job.grade.name then
            gradeName = PlayerData.job.grade.name
        end
        pJob = jobName .. " - " .. gradeName
    end
    if PlayerData.money then
        pCash = PlayerData.money.cash or 0
        pBank = PlayerData.money.bank or 0
    end
end

-- ==========================================
-- QBX EVENT'LERİ
-- ==========================================
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.metadata then
        hunger = PlayerData.metadata['hunger'] or 100
        thirst = PlayerData.metadata['thirst'] or 100
        stress = PlayerData.metadata['stress']  or 0
    end
    updatePlayerDetails(PlayerData)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    if val and val.metadata then
        hunger = val.metadata['hunger'] or hunger
        thirst = val.metadata['thirst'] or thirst
        stress = val.metadata['stress']  or stress
    end
    updatePlayerDetails(val)
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger = newHunger
    thirst = newThirst
end)

RegisterNetEvent('pma-voice:radioActive', function(talking)
    isTalkingOnRadio = talking
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = newStress
end)

AddStateBagChangeHandler('stress', nil, function(bagName, key, value)
    if bagName == ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        stress = value or 0
    end
end)

RegisterNetEvent("hud:client:ToggleCinematic", function(state)
    cinematicMode = state
    SendNUIMessage({ action = "cinematicBars", state = cinematicMode })
end)

-- ==========================================
-- KOMUTLAR
-- ==========================================
-- ==========================================
-- HUD MENÜSÜ  (/hud)  +  KOMUTLAR
--   /hud            → ayar menüsünü açar
--   /togglemap      → minimap aç/kapat
--   /cinematic      → sinematik barlar aç/kapat
--   /developermode  → geliştirici modu (SADECE ADMIN, sunucuda doğrulanır)
-- ==========================================
local menuOpen = false

local function HudNotify(desc, ntype)
    lib.notify({ title = 'HUD', description = desc, type = ntype or 'inform' })
end

local function IsAdmin()
    return lib.callback.await('qbx_pthud:isAdmin', false) == true
end

local function ToggleCinematic()
    cinematicMode = not cinematicMode
    TriggerEvent("hud:client:ToggleCinematic", cinematicMode)
    SendNUIMessage({ action = "cinematicBars", state = cinematicMode })
    return cinematicMode
end

local function ToggleMap()
    showMinimap = not showMinimap
    return showMinimap
end

-- return: yeni durum  |  nil, sebep
local function ToggleDevMode()
    if not IsAdmin() then
        HudNotify('Bu özelliği sadece adminler kullanabilir.', 'error')
        return nil
    end
    devmode = not devmode
    return devmode
end

RegisterCommand("cinematic", function() ToggleCinematic() end, false)
RegisterCommand("togglemap", function() ToggleMap() end, false)
RegisterCommand("developermode", function() ToggleDevMode() end, false)

local function CloseHudMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeHudMenu" })
end

RegisterCommand("hud", function()
    if menuOpen then return CloseHudMenu() end
    menuOpen = true
    local admin = IsAdmin()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action    = "openHudMenu",
        isAdmin   = admin,
        map       = showMinimap,
        cinematic = cinematicMode,
        dev       = devmode,
    })
end, false)

RegisterNUICallback("hudToggle", function(data, cb)
    local key, state = data and data.key, nil
    if key == "map" then
        state = ToggleMap()
    elseif key == "cinematic" then
        state = ToggleCinematic()
    elseif key == "dev" then
        state = ToggleDevMode()   -- admin değilse nil döner
    end
    cb({ state = state })
end)

RegisterNUICallback("hudClose", function(_, cb)
    CloseHudMenu()
    cb("ok")
end)

-- ==========================================
-- İYİLEŞME EVENTLERİ
-- ==========================================
for _, eventName in ipairs(Config.HealingEvents) do
    RegisterNetEvent(eventName, function()
        isBleeding    = false
        isBoneBroken  = false
        bleedPercent  = 0
        bleedTimer    = 0
        ClearEntityLastWeaponDamage(PlayerPedId())
        if Config.EnableStress then
            TriggerServerEvent('hud:server:RelieveStress', 100)
        end
    end)
end

-- ==========================================
-- ANA HUD DÖNGÜSÜ (200ms)
-- ==========================================
CreateThread(function()
    while true do
        Wait(200)

        if not LocalPlayer.state.isLoggedIn then
            SendNUIMessage({ action = "hide" })
            goto continue
        end

        local ped = PlayerPedId()

        -- Kanama / Kırık sıfırla her döngüde
        isBoneBroken = false
        isBleeding   = false

        -- QBX / QB-AMBULANCEJOB Metadata entegrasyonu
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData and PlayerData.metadata then
            local meta = PlayerData.metadata
            if (meta['bleedlevel'] and type(meta['bleedlevel']) == 'number' and meta['bleedlevel'] > 0)
            or (meta['bloodvolume'] and type(meta['bloodvolume']) == 'number' and meta['bloodvolume'] < 100)
            or meta['isbleeding'] or meta['isBleeding'] then
                isBleeding = true
            end

            if meta['injuries'] and type(meta['injuries']) == 'table' then
                for _, damage in pairs(meta['injuries']) do
                    if (type(damage) == 'number' and damage > 0) or (type(damage) == 'boolean' and damage) then
                        isBoneBroken = true
                        break
                    end
                end
            end
            if meta['bone'] or meta['isbroken'] or meta['isBoneBroken'] then
                isBoneBroken = true
            end

            if meta['isdead'] or meta['inlaststand'] then
                isBleeding   = true
                isBoneBroken = true
            end
        end

        -- StateBag kontrolleri (ox_lib / Overextended)
        if LocalPlayer.state.isBleeding then isBleeding = true end
        if LocalPlayer.state.bleedingLevel and type(LocalPlayer.state.bleedingLevel) == 'number' and LocalPlayer.state.bleedingLevel > 0 then
            isBleeding = true
        end
        if LocalPlayer.state.isBoneBroken then isBoneBroken = true end
        if LocalPlayer.state.stress then stress = LocalPlayer.state.stress end

        -- Sağlık bazlı kanama
        local rawHealth = GetEntityHealth(ped)
        if rawHealth < Config.BleedingHealthThreshold then
            isBleeding = true
        end

        -- Revive / Heal failsafe
        if rawHealth >= GetEntityMaxHealth(ped) - 5 then
            isBleeding   = false
            isBoneBroken = false
            bleedPercent = 0
            bleedTimer   = 0
            ClearEntityLastWeaponDamage(ped)
        end

        -- Kanama barı (yavaşça artar/azalır)
        if isBleeding then
            bleedTimer = bleedTimer + 200
            if bleedTimer >= 1000 then
                bleedPercent = math.min(bleedPercent + 1, 100)
                bleedTimer   = 0
            end
        else
            bleedTimer   = 0
            bleedPercent = math.max(bleedPercent - 2, 0)
        end

        -- Stamina
        if IsPedShooting(ped) then
            staminaPenalty = math.min(staminaPenalty + 3.0, 100.0)
        elseif staminaPenalty > 0 and not IsPedSprinting(ped) then
            staminaPenalty = math.max(staminaPenalty - 1.5, 0.0)
        end

        if not IsPauseMenuActive() and not cinematicMode then
            local maxHp   = GetEntityMaxHealth(ped) - 100
            local health  = maxHp > 0 and math.floor((rawHealth - 100) / maxHp * 100) or 0
            health = math.max(0, math.min(100, health))

            local armor  = GetPedArmour(ped)
            local native = 100 - math.floor(GetPlayerSprintStaminaRemaining(PlayerId()))
            finalStamina = math.max(0, math.min(100, math.floor(native - staminaPenalty)))

            local isUnderwater = IsPedSwimmingUnderWater(ped)
            local oxygen = 100
            if isUnderwater then
                oxygen = math.max(0, math.min(100, math.floor(GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10)))
            end

            local isTalking = NetworkIsPlayerTalking(PlayerId())
            local voice = 2
            if LocalPlayer.state.proximity and LocalPlayer.state.proximity.index then
                voice = LocalPlayer.state.proximity.index
            end

            local isAiming   = IsPlayerFreeAiming(PlayerId())
            local weapon     = GetSelectedPedWeapon(ped)
            local hasWeapon  = false
            local ammoInClip = 0
            local ammoTotal  = 0

            if weapon ~= `WEAPON_UNARMED` and weapon ~= 0 then
                hasWeapon = true
                local _, clip = GetAmmoInClip(ped, weapon)
                ammoInClip = clip
                ammoTotal  = math.max(0, GetAmmoInPedWeapon(ped, weapon) - ammoInClip)
            end

            SendNUIMessage({
                action = "update",
                data = {
                    health     = health,
                    armor      = armor,
                    hunger     = hunger,
                    thirst     = thirst,
                    stress     = stress,
                    showStress = Config.EnableStress,
                    stamina    = finalStamina,
                    isUnderwater = isUnderwater,
                    oxygen     = oxygen,
                    isTalking  = isTalking,
                    isRadio    = isTalkingOnRadio,
                    voice      = voice,
                    isAiming   = isAiming,
                    hasWeapon  = hasWeapon,
                    ammoClip   = ammoInClip,
                    ammoTotal  = ammoTotal,
                    bleed      = isBleeding,
                    bleedLevel = bleedPercent,
                    bone       = isBoneBroken,
                    devmode    = devmode,
                    pId        = GetPlayerServerId(PlayerId()),
                    pName      = string.upper(pName),
                    pJob       = string.upper(pJob),
                    pCash      = pCash,
                    pBank      = pBank
                }
            })
        else
            SendNUIMessage({ action = "hide" })
        end
        ::continue::
    end
end)

-- Sprint kilidi (stamina 0'da)
CreateThread(function()
    while true do
        Wait(0)
        if finalStamina <= 0 then
            DisableControlAction(0, 21, true)
        end
    end
end)

-- ==========================================
-- STRES SİSTEMİ
-- ==========================================
local function isWhitelistedWeapon(weapon)
    if not weapon then return false end
    for _, v in pairs(Config.Stress.whitelistedWeapons) do
        if weapon == v then return true end
    end
    return false
end

-- Araç hızına göre stres
CreateThread(function()
    while true do
        Wait(10000)
        if Config.EnableStress and LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh      = GetVehiclePedIsIn(ped, false)
                local vehClass = GetVehicleClass(veh)
                if vehClass ~= 13 and vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 and vehClass ~= 21 then
                    local speed      = GetEntitySpeed(veh) * 3.6
                    local isBuckled  = LocalPlayer.state.seatbelt
                    local threshold  = isBuckled and Config.Stress.minSpeedForStress or Config.Stress.minSpeedForStressUnbuckled
                    if speed >= threshold then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 2))
                    end
                end
            end
        end
    end
end)

-- Silah ateşine göre stres
CreateThread(function()
    while true do
        Wait(0)
        if Config.EnableStress then
            local ped = PlayerPedId()
            if IsPedShooting(ped) then
                local weapon = GetSelectedPedWeapon(ped)
                if not isWhitelistedWeapon(weapon) then
                    if math.random() <= Config.Stress.chance then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                        Wait(5000)
                    end
                end
            end
        else
            Wait(1000)
        end
    end
end)

-- Stres ekran efektleri
local function getBlurIntensity(s)
    if s >= 90 then return 3000
    elseif s >= 80 then return 2700
    elseif s >= 70 then return 2500
    elseif s >= 60 then return 2000
    else return 1500 end
end

local function getEffectInterval(s)
    if s >= 90 then return math.random(15000, 20000)
    elseif s >= 80 then return math.random(20000, 30000)
    elseif s >= 70 then return math.random(30000, 40000)
    elseif s >= 60 then return math.random(40000, 50000)
    else return math.random(50000, 60000) end
end

CreateThread(function()
    while true do
        if Config.EnableStress and stress >= Config.Stress.minForShaking then
            Wait(getEffectInterval(stress))
            if stress >= 100 then
                local ped = PlayerPedId()
                TriggerScreenblurFadeIn(1000.0)
                if not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) then
                    local rt = math.random(2, 4) * 1750
                    SetPedToRagdoll(ped, rt, rt, 0, false, false, false)
                end
                Wait(getBlurIntensity(stress))
                TriggerScreenblurFadeOut(1000.0)
            elseif stress >= Config.Stress.minForShaking then
                TriggerScreenblurFadeIn(1000.0)
                Wait(getBlurIntensity(stress))
                TriggerScreenblurFadeOut(1000.0)
            end
        else
            Wait(2000)
        end
    end
end)

-- Yaralanma kaynaklı stres
CreateThread(function()
    while true do
        Wait(30000)
        if Config.EnableStress and LocalPlayer.state.isLoggedIn then
            if isBleeding or isBoneBroken then
                TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
            end
        end
    end
end)

-- ==========================================
-- ARAÇ HUD (Car HUD)
-- ==========================================

-- Emniyet Kemeri ses bankası
-- Tek denemede yüklenmeyebiliyor (kaynak başlarken ses verisi hazır olmayabilir) → birkaç kez dene
local seatbeltBankLoaded = false
CreateThread(function()
    for _ = 1, 20 do
        if RequestScriptAudioBank("audiodirectory/seatbelt_sounds", false) then
            seatbeltBankLoaded = true
            break
        end
        Wait(500)
    end
    if not seatbeltBankLoaded then
        print("^1[qbx_pthud] seatbelt_sounds ses bankası yüklenemedi (fxmanifest data_file / awc yolunu kontrol et)^7")
    end
end)

local seatbeltOn    = false
local wasInVehicle  = false

RegisterCommand('toggleseatbelt', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh   = GetVehiclePedIsIn(ped, false)
        local class = GetVehicleClass(veh)
        if class ~= 8 and class ~= 13 and class ~= 14 then
            seatbeltOn = not seatbeltOn
            LocalPlayer.state:set("seatbelt", seatbeltOn, true)
            PlaySoundFrontend(-1, seatbeltOn and 'carbuckle' or 'carunbuckle', 'seatbelt_soundset', true)
        end
    end
end, false)
RegisterKeyMapping('toggleseatbelt', 'Emniyet Kemeri Tak/Çıkar', 'keyboard', 'B')

-- Araç veri döngüsü (50ms)
CreateThread(function()
    while true do
        Wait(50)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) and not IsPauseMenuActive() and not cinematicMode then
            wasInVehicle = true
            local veh  = GetVehiclePedIsIn(ped, false)

            local speed    = math.floor(GetEntitySpeed(veh) * 3.6)
            local rpm      = GetVehicleCurrentRpm(veh)
            local gear     = GetVehicleCurrentGear(veh)
            if speed == 0 and gear == 0 then gear = "N"
            elseif gear == 0 then gear = "R" end

            local fuel     = GetVehicleFuelLevel(veh)
            local _, lightsOn, highbeamsOn = GetVehicleLightsState(veh)
            local isLightsOn  = lightsOn == 1 or highbeamsOn == 1
            local seatbelt    = LocalPlayer.state.seatbelt or false
            local lockStatus  = GetVehicleDoorLockStatus(veh)
            local isLocked    = lockStatus == 2 or lockStatus == 3
            local engineHealth = GetVehicleEngineHealth(veh)

            local maxGear  = GetVehicleHighGear(veh)
            local class    = GetVehicleClass(veh)
            local isElectric = maxGear == 1 and class ~= 8 and class ~= 13 and class ~= 14

            local nitroLvl = Entity(veh).state.nd_nitro_nos or 0
            local purgeLvl = Entity(veh).state.nd_nitro_purge or 0

            SendNUIMessage({
                action     = "updateCarHud",
                speed      = speed,
                rpm        = rpm,
                gear       = gear,
                fuel       = fuel,
                lights     = isLightsOn,
                seatbelt   = seatbelt,
                locked     = isLocked,
                engine     = engineHealth,
                isElectric = isElectric,
                nitro      = nitroLvl,
                purge      = purgeLvl
            })
        else
            if wasInVehicle then
                wasInVehicle = false
                if seatbeltOn then
                    seatbeltOn = false
                    LocalPlayer.state:set("seatbelt", false, true)
                end
            end
            SendNUIMessage({ action = "hideCarHud" })
        end
    end
end)

-- Kemer takılıyken araçtan çıkma engeli
-- Araçtaysak HER KARE kontrol edilir (eskiden kemer takıldıktan sonra 500ms boşluk vardı,
-- o sürede F ile inilebiliyordu). Araç dışında 250ms'de bir hafif kontrol.
CreateThread(function()
    while true do
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            Wait(0)
            if seatbeltOn or LocalPlayer.state.seatbelt then
                DisableControlAction(0, 75, true)   -- INPUT_VEH_EXIT (F)
                DisableControlAction(0, 23, true)   -- INPUT_ENTER   (F, araca bin/in)
                DisableControlAction(2, 75, true)
                DisableControlAction(2, 23, true)
            end
        else
            Wait(250)
        end
    end
end)

-- ==========================================
-- MİNİHARİTA & PUSULA
-- ==========================================
CreateThread(function()
    Wait(1500)

    RequestStreamedTextureDict("circlemap", false)
    while not HasStreamedTextureDictLoaded("circlemap") do Wait(10) end

    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemap", "radarmasksm")
    SetMinimapClipType(1)

    -- ============================================================
    -- CSS :root ile BİREBİR aynı oranlar (html/style.css)
    --   --map-size  : 10.5vw   -> ekran GENİŞLİĞİNİN %10.5'i
    --   --map-top   : 10vh     -> ekran YÜKSEKLİĞİNİN %10'u
    --   --map-right : 1vw      -> ekran GENİŞLİĞİNİN %1'i
    -- Hem UI hem minimap bu oranlardan hesaplandığı için çözünürlük
    -- değişince ikisi birlikte ölçeklenir.
    -- ============================================================
    local MAP_SIZE  = 0.105
    local MAP_TOP   = 0.10
    local MAP_RIGHT = 0.013

    -- circlemap.ytd maskesi kare değil. Çember çapına (D) oranlı { genişlik, yükseklik }
    local MINIMAP_K = { 1.095, 0.891 }
    local MASK_K    = { 0.912, 0.690 }  -- üst/alt kesiliyorsa yüksekliği artır
    local BLUR_K    = { 1.280, 0.980 }

    -- Çember çapına oranla kaydırma (çözünürlükle birlikte ölçeklenir)
    local MAP_SHIFT_X = -0.010  -- - sola,  + sağa
    local MAP_SHIFT_Y =  0.018  -- + aşağı, - yukarı

    local function UpdateMinimapCoords()
        local resX, resY = GetActiveScreenResolution()
        if resX == 0 or resY == 0 then return end

        local safeZone = GetSafeZoneSize()
        local sfOff    = (1.0 - safeZone) / 2.0

        -- Çemberin çapı ve merkezi (piksel) — CSS ile aynı formül
        local dPx  = MAP_SIZE * resX
        local cxPx = resX - (MAP_RIGHT * resX) - dPx / 2 + dPx * MAP_SHIFT_X
        local cyPx = (MAP_TOP * resY) + dPx / 2 + dPx * MAP_SHIFT_Y

        -- Merkezli piksel dikdörtgeni -> GTA (safezone düzeltmeli) koordinatı
        local function rect(k)
            local wPx, hPx = dPx * k[1], dPx * k[2]
            local nX = (cxPx - wPx / 2) / resX
            local nY = (cyPx - hPx / 2) / resY
            return (nX - sfOff) / safeZone,
                   (nY - sfOff) / safeZone,
                   (wPx / resX) / safeZone,
                   (hPx / resY) / safeZone
        end

        local x, y, w, h
        x, y, w, h = rect(MINIMAP_K); SetMinimapComponentPosition("minimap",      "L", "T", x, y, w, h)
        x, y, w, h = rect(MASK_K);    SetMinimapComponentPosition("minimap_mask", "L", "T", x, y, w, h)
        x, y, w, h = rect(BLUR_K);    SetMinimapComponentPosition("minimap_blur", "L", "T", x, y, w, h)
    end

    UpdateMinimapCoords()

    local minimap = RequestScaleformMovie("minimap")
    while not HasScaleformMovieLoaded(minimap) do Wait(10) end

    SetRadarBigmapEnabled(true, false)
    Wait(50)
    SetRadarBigmapEnabled(false, false)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    DisplayRadar(true)

    -- Safezone zorunlu: en sağda (1.0) değilse tam ekran uyarı göster.
    -- Ayar ESC menüsünden yapıldığı için pause menüsü açıkken uyarı gizlenir
    -- (yoksa kaydırıcıyı kapatır), menü kapanınca tekrar kontrol edilir.
    CreateThread(function()
        local warningActive = false
        while true do
            Wait(500)
            local bad = GetSafeZoneSize() < 0.99
            local show = bad and not IsPauseMenuActive()
            if show ~= warningActive then
                warningActive = show
                SendNUIMessage({ action = show and "showSafezoneWarning" or "hideSafezoneWarning" })
            end
        end
    end)

    -- Çözünürlük / safezone değişikliği takibi
    CreateThread(function()
        local lastResX, lastResY, lastSZ = 0, 0, 0
        while true do
            Wait(2000)
            local rx, ry = GetActiveScreenResolution()
            local sz     = GetSafeZoneSize()
            if rx ~= lastResX or ry ~= lastResY or sz ~= lastSZ then
                lastResX, lastResY, lastSZ = rx, ry, sz
                UpdateMinimapCoords()
                SetRadarBigmapEnabled(true, false)
                Wait(50)
                SetRadarBigmapEnabled(false, false)
            end
        end
    end)
end)

-- Harita görünürlük döngüsü + native HUD gizleme
CreateThread(function()
    local minimap = RequestScaleformMovie("minimap")
    while true do
        Wait(0)
        -- Native GTA HUD elemanlarını gizle (custom HUD kullandığımız için)
        HideHudComponentThisFrame(1)   -- Araç adı
        HideHudComponentThisFrame(2)   -- Araç sol yardım metni
        HideHudComponentThisFrame(3)   -- Para göstergesi (nakit)
        HideHudComponentThisFrame(4)   -- Nakit değişim bildirimi
        HideHudComponentThisFrame(6)   -- Nişan alma crosshair (custom kullanıyoruz)
        HideHudComponentThisFrame(7)   -- Araç takip ikonu
        HideHudComponentThisFrame(8)   -- Silah çantası
        HideHudComponentThisFrame(9)   -- Silah bileşenleri
        HideHudComponentThisFrame(11)  -- Bölge adı (sol üst)
        HideHudComponentThisFrame(12)  -- Araç sürüş modu (sol)
        HideHudComponentThisFrame(13)  -- Araç kalkış bilgisi
        HideHudComponentThisFrame(14)  -- Sürücü adı
        HideHudComponentThisFrame(15)  -- Kılavuz oku (compass needle replacement)
        HideHudComponentThisFrame(17)  -- Kasa / depo bilgisi
        HideHudComponentThisFrame(18)  -- Müşteri araba göstergesi
        HideHudComponentThisFrame(19)  -- Banka hesap bilgisi
        HideHudComponentThisFrame(20)  -- Asgari ücret
        HideHudComponentThisFrame(21)  -- MP giriş butonu
        HideHudComponentThisFrame(22)  -- MP giriş bildirimi

        local isInvOpen  = LocalPlayer.state.invOpen or false
        local isLoggedIn = LocalPlayer.state.isLoggedIn or false

        if not IsPauseMenuActive() and not cinematicMode and showMinimap and not isInvOpen and isLoggedIn then
            DisplayRadar(true)
            BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
            -- Minimap içindeki GTA'nın kendi "↑ 0.2mi" mesafe yazısını gizle (NUI waypoint kutusu kullanılıyor)
            BeginScaleformMovieMethod(minimap, "HIDE_SATNAV")
            EndScaleformMovieMethod()
        else
            DisplayRadar(false)
        end
    end
end)

-- Pusula veri döngüsü (50ms)
CreateThread(function()
    while true do
        Wait(50)
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local camRot = GetGameplayCamRot(2).z
        local heading = math.floor(360.0 - camRot)
        if heading < 0 then heading = heading + 360 end
        if heading > 360 then heading = heading - 360 end

        local isLoggedIn = LocalPlayer.state.isLoggedIn or false
        if not isLoggedIn then
            SendNUIMessage({ action = "hideCompass" })
            goto skipCompass
        end

        local street1  = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(street1) or ""
        local zone       = GetNameOfZone(coords.x, coords.y, coords.z)
        local zoneLabel  = GetLabelText(zone)
        if not zoneLabel or zoneLabel == "" then zoneLabel = zone end

        local waypointData = nil
        local waypointDir  = "up"
        local waypointBlip = GetFirstBlipInfoId(8)
        if DoesBlipExist(waypointBlip) then
            local wpCoords = GetBlipInfoIdCoord(waypointBlip)
            local dist     = #(coords - wpCoords)
            if dist > 15.0 then
                waypointData = string.format("%.2f mi", dist * 0.000621371)
                local dx = wpCoords.x - coords.x
                local dy = wpCoords.y - coords.y
                if dist > 0 then dx = dx / dist; dy = dy / dist end
                local rad      = math.rad(GetEntityHeading(ped))
                local dotFwd   = (dx * -math.sin(rad)) + (dy * math.cos(rad))
                local dotRight = (dx *  math.cos(rad)) + (dy * math.sin(rad))
                if dotFwd > 0.6 then waypointDir = "up"
                elseif dotFwd < -0.3 then waypointDir = "down"
                elseif dotRight > 0.4 then waypointDir = "right"
                else waypointDir = "left" end
            end
        end

        local isInvOpen = LocalPlayer.state.invOpen or false
        if not IsPauseMenuActive() and not cinematicMode and showMinimap and not isInvOpen then
            SendNUIMessage({
                action      = "updateCompass",
                heading     = heading,
                street      = string.upper(streetName),
                zone        = string.upper(zoneLabel),
                waypoint    = waypointData,
                waypointDir = waypointDir
            })
        else
            SendNUIMessage({ action = "hideCompass" })
        end
        ::skipCompass::
    end
end)
