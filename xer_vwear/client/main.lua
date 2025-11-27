-- client/main.lua - MIT DEINER IDEE: AUSSTEIGEN → CACHE LEEREN + SERVER SYNC (with minor efficiency tweaks)
QBCore = exports['qb-core']:GetCoreObject()

local uiVisible = false
local currentPlate = nil
local currentVehicle = nil
local lastPos = nil
local CurrentData = {}  -- Per plate

RegisterNetEvent('xer_vwear:client:syncCache', function(data)
    if not data or not data.plate then return end
    CurrentData[data.plate] = data

    if uiVisible and currentPlate == data.plate then
        SendNUIMessage({ action = "update", data = data })
    end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and QBCore.Functions.GetPlate(veh) == data.plate and GetPedInVehicleSeat(veh, -1) == ped then
        TriggerEvent('xer_vwear:engine:apply', data.wear_engine or 0.0)
        TriggerEvent('xer_vwear:tires:apply', data.wear_tires or 100.0)
        TriggerEvent('xer_vwear:brakes:apply', data.wear_brakes or 0.0)
        TriggerEvent('xer_vwear:suspension:apply', data.wear_suspension or 0.0)
        TriggerEvent('xer_vwear:transmission:apply', data.wear_transmission or 0.0)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.UpdateInterval)

        local ped = PlayerPedId()
        local inVeh = IsPedInAnyVehicle(ped, false)
        
        if inVeh then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local plate = QBCore.Functions.GetPlate(veh)

                if currentVehicle ~= veh then
                    currentVehicle = veh
                    lastPos = GetEntityCoords(veh)
                    TriggerServerEvent('xer_vwear:server:loadWear', plate)
                end

                local pos = GetEntityCoords(veh)
                local dist = lastPos and #(pos - lastPos) or 0.0
                lastPos = pos

                if dist > 0 then
                    local speedKmh = GetEntitySpeed(veh) * 3.6
                    local rpm = GetVehicleCurrentRpm(veh) or 0.0
                    local isAggressive = speedKmh > 120 or rpm > 0.7
                    TriggerServerEvent('xer_vwear:server:updateMileageAndWear', plate, dist, isAggressive)
                end
            end
        else
            -- AUSSTEIGEN: DEINE IDEE – sende Daten zum Server und leere local cache
            if currentVehicle then
                if currentPlate then
                    TriggerServerEvent('xer_vwear:server:syncOnExit', currentPlate)  -- Neu: Sende zum Server
                    CurrentData[currentPlate] = nil  -- Leere local cache
                end
                currentVehicle = nil
                lastPos = nil
                currentPlate = nil
            end
            Wait(500)  -- Slight delay when not in vehicle for efficiency
        end
    end
end)

local function ToggleUI()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not IsPedInAnyVehicle(ped, false) or GetPedInVehicleSeat(veh, -1) ~= ped then
        return QBCore.Functions.Notify("You must be driving!", "error")
    end

    currentPlate = QBCore.Functions.GetPlate(veh)
    uiVisible = not uiVisible
    SetNuiFocus(uiVisible, uiVisible)
    SendNUIMessage({ action = uiVisible and "showUI" or "hideUI" })

    if uiVisible then
        if CurrentData[currentPlate] then
            SendNUIMessage({ action = "update", data = CurrentData[currentPlate] })
        else
            TriggerServerEvent('xer_vwear:server:requestData', currentPlate)
        end
    end
end

RegisterCommand(Config.ShowCommand, ToggleUI)
RegisterKeyMapping(Config.ShowCommand, 'Open Vehicle Status HUD', 'keyboard', 'INSERT')

RegisterNUICallback('closeUI', function(_, cb)
    uiVisible = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "hideUI" })
    cb('ok')
end)

RegisterNetEvent('xer_vwear:client:physicalRepair', function(netId, part)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or not DoesEntityExist(veh) then return end

    if part == "engine" then
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
    elseif part == "tires" then
        for i = 0, 7 do
            SetVehicleTyreFixed(veh, i)
        end
    elseif part == "brakes" then
        SetVehicleHandlingFloat(veh, "CHandlingData", "fBrakeForce", 1.0)
    elseif part == "suspension" then
        SetVehicleSuspensionHeight(veh, 0.0)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiVisible then ToggleUI() end
    TriggerEvent('xer_vwear:engine:cleanup')
    TriggerEvent('xer_vwear:tires:cleanup')
    TriggerEvent('xer_vwear:brakes:cleanup')
    TriggerEvent('xer_vwear:suspension:cleanup')
    TriggerEvent('xer_vwear:transmission:cleanup')
end)