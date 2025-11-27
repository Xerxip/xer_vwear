local QBCore = exports['qb-core']:GetCoreObject()
local Cache = {}

RegisterNetEvent('xer_vwear:server:repairPart', function(plate, part)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Mechanic duty check
    if Player.PlayerData.job.name ~= "mechanic" or not Player.PlayerData.job.onduty then
        return TriggerClientEvent('QBCore:Notify', src, "You are not a mechanic on duty!", "error")
    end

    local cost = Config.RepairCost[part]
    if not cost then
        return TriggerClientEvent('QBCore:Notify', src, "Invalid repair part!", "error")
    end

    if not Player.Functions.RemoveMoney('bank', cost) then
        return TriggerClientEvent('QBCore:Notify', src, "Not enough money in bank!", "error")
    end

    -- Update DB using plate
    MySQL.update('UPDATE vehicle_wear SET wear_'..part..' = ? WHERE plate = ?', {(part == "tires") and 100.0 or 0.0, plate}, function(affected)
        if affected == 0 then
            Player.Functions.AddMoney('bank', cost)
            return TriggerClientEvent('QBCore:Notify', src, "Repair failed! Vehicle not found.", "error")
        end

        -- Reload data
        MySQL.query('SELECT * FROM vehicle_wear WHERE plate = ?', {plate}, function(res)
            if res and res[1] then
                local freshData = {
                    plate = plate,
                    mileage = res[1].mileage or 0,
                    wear_engine = res[1].wear_engine or 0.0,
                    wear_transmission = res[1].wear_transmission or 0.0,
                    wear_brakes = res[1].wear_brakes or 0.0,
                    wear_suspension = res[1].wear_suspension or 0.0,
                    wear_tires = res[1].wear_tires or 100.0
                }
                Cache[plate] = freshData
                TriggerClientEvent('xer_vwear:client:syncCache', -1, freshData)
                TriggerClientEvent('QBCore:Notify', src, "Repair successful! (-$"..cost..")", "success")
            end
        end)
    end)
end)
