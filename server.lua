-- ==========================================
-- qbx_pthud | Server Script
-- Stres sistemi + Nitro item
-- Author: Mirage
-- ==========================================

local QBCore             = exports['qb-core']:GetCoreObject()
local notifyCooldowns    = {}
local relieveCooldowns   = {}

-- ==========================================
-- STRES
-- ==========================================
RegisterNetEvent('hud:server:GainStress', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local newStress = (Player.PlayerData.metadata['stress'] or 0) + amount
    if newStress > 100 then newStress = 100 end
    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)

    local t = os.time()
    if not notifyCooldowns[src] or (t - notifyCooldowns[src] > 30) then
        TriggerClientEvent('QBCore:Notify', src, "Stres seviyeniz yükseliyor...", 'error', 3500)
        notifyCooldowns[src] = t
    end
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local newStress = (Player.PlayerData.metadata['stress'] or 0) - amount
    if newStress < 0 then newStress = 0 end
    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)

    local t = os.time()
    if not relieveCooldowns[src] or (t - relieveCooldowns[src] > 30) then
        TriggerClientEvent('QBCore:Notify', src, "Stresiniz azaldı, rahatlıyorsunuz.", 'success', 3500)
        relieveCooldowns[src] = t
    end
end)

-- ==========================================
-- NİTRO ITEM
-- ==========================================
QBCore.Functions.CreateUseableItem('nitrous', function(source, item)
    TriggerClientEvent('nitrous:client:Install', source)
end)

RegisterNetEvent('nitrous:server:Apply', function(netId)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    local veh    = NetworkGetEntityFromNetworkId(netId)
    if veh and veh > 0 then
        if Player.Functions.RemoveItem('nitrous', 1) then
            Entity(veh).state:set('nd_nitro_nos', 100.0, true)
            Entity(veh).state:set('nd_nitro_purge', 0.0, true)
            TriggerClientEvent('QBCore:Notify', src, 'Nitro başarıyla kuruldu / yenilendi!', 'success')
        end
    end
end)

-- ==========================================
-- ADMIN KONTROLÜ  (/hud menüsü + /developermode)
-- ==========================================
local function IsAdmin(src)
    if IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'admin') then
        return true
    end
    for _, perm in ipairs({ 'admin', 'god' }) do
        local ok, has = pcall(QBCore.Functions.HasPermission, src, perm)
        if ok and has then return true end
    end
    return false
end

lib.callback.register('qbx_pthud:isAdmin', function(src)
    return IsAdmin(src)
end)
