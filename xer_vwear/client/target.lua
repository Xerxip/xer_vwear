local QBCore = exports['qb-core']:GetCoreObject()

local repairParts = {
    {label = "Engine", value = "engine"},
    {label = "Transmission", value = "transmission"},
    {label = "Brakes", value = "brakes"},
    {label = "Suspension", value = "suspension"},
    {label = "Tires", value = "tires"},
}

CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        local vehicles = QBCore.Functions.GetVehicles()
        for _, veh in pairs(vehicles) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - pos) < 5.0 then
                local plate = QBCore.Functions.GetPlate(veh)
                if plate then
                    -- Add ox_target options directly
                    local options = {}
                    local Player = QBCore.Functions.GetPlayerData()
                    if Player.job.name == "mechanic" and Player.job.onduty then
                        for _, part in pairs(repairParts) do
                            table.insert(options, {
                                name = "repair_"..part.value.."_"..plate,
                                icon = "fa-solid fa-wrench",
                                label = "Repair "..part.label,
                                onSelect = function()
                                    TriggerServerEvent('xer_vwear:server:repairPart', plate, part.value)
                                end
                            })
                        end
                    end

                    if #options > 0 then
                        -- Register target on the vehicle entity
                        exports.ox_target:addTargetEntity(veh, options)
                    end
                end
            end
        end
    end
end)
