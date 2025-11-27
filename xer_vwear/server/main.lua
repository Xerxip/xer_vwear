-- server/main.lua (with fixes: tire subtraction, thresholds, validation, logging, decimal wear, use plate as key)

local QBCore = exports['qb-core']:GetCoreObject()
local Cache = {}
local RequestCooldowns = {}  -- Per-player cooldown for data requests (anti-spam)

-- Helper: Send log to Discord webhook or console
local function SendLog(message)
    if Config.DiscordWebhook ~= "" then
        local embed = {
            {
                ["color"] = 16711680,  -- Red
                ["title"] = "Vehicle Wear Log",
                ["description"] = message,
                ["footer"] = {["text"] = "xer_vwear v3.3 - " .. os.date("%Y-%m-%d %H:%M:%S")}
            }
        }
        PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({username = "Vehicle Wear", embeds = embed}), { ['Content-Type'] = 'application/json' })
    else
        print("^3[xer_vwear] " .. message)
    end
end

-- Helper for closest vehicle (server-side)
local function GetClosestVehicleFromPlayer(src)
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    local veh = GetClosestVehicle(pos.x, pos.y, pos.z, 5.0, 0, 70)  -- Native, radius 5m
    if not DoesEntityExist(veh) then return false end
    return true, veh
end

RegisterNetEvent('xer_vwear:server:loadWear', function(plate)
    local src = source
    -- Rate-limit: 5s cooldown per player
    if RequestCooldowns[src] and GetGameTimer() - RequestCooldowns[src] < 5000 then return end
    RequestCooldowns[src] = GetGameTimer()

    print("[DEBUG] Load wear triggered for plate: " .. plate .. " by player " .. src)  -- Debug: load start

    plate = QBCore.Shared.Trim(plate)
    if Cache[plate] then 
        return TriggerClientEvent('xer_vwear:client:syncCache', src, Cache[plate])
    end
    MySQL.query('SELECT mileage, wear_engine, wear_transmission, wear_brakes, wear_suspension, wear_tires FROM vehicle_wear WHERE plate = ?', {plate}, function(res)
        local data
        if res[1] then
            data = {
                plate = plate,
                mileage = res[1].mileage or 0,
                wear_engine = res[1].wear_engine or 0.0,
                wear_transmission = res[1].wear_transmission or 0.0,
                wear_brakes = res[1].wear_brakes or 0.0,
                wear_suspension = res[1].wear_suspension or 0.0,
                wear_tires = res[1].wear_tires or 100.0
            }
            print("[DEBUG] Loaded existing data for plate: " .. plate .. ", tires: " .. data.wear_tires)  -- Debug: loaded existing
        else
            -- No entry: Insert defaults for new vehicle
            data = {
                plate = plate,
                mileage = 0,
                wear_engine = 0.0,
                wear_transmission = 0.0,
                wear_brakes = 0.0,
                wear_suspension = 0.0,
                wear_tires = 100.0
            }
            MySQL.insert('INSERT INTO vehicle_wear (plate, mileage, wear_engine, wear_transmission, wear_brakes, wear_suspension, wear_tires) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                plate, data.mileage, data.wear_engine, data.wear_transmission, data.wear_brakes, data.wear_suspension, data.wear_tires
            })
            print("[DEBUG] Inserted new row for plate: " .. plate)  -- Debug: insert
        end
        Cache[plate] = data
        TriggerClientEvent('xer_vwear:client:syncCache', src, data)
    end)
end)

RegisterNetEvent('xer_vwear:server:updateMileageAndWear', function(plate, dist, agg)
    local src = source
    -- Security: Validate inputs
    if type(dist) ~= "number" or dist < 0 or dist > 500 then  -- Max ~300km/h * 10s / 3.6
        SendLog("Suspicious update from player " .. GetPlayerName(src) .. " (" .. src .. "): Invalid dist " .. tostring(dist))
        return
    end
    if type(agg) ~= "boolean" then
        SendLog("Suspicious update from player " .. GetPlayerName(src) .. " (" .. src .. "): Invalid agg " .. tostring(agg))
        return
    end

    plate = QBCore.Shared.Trim(plate)
    if not Cache[plate] then return end
    local c = Cache[plate]
    local km_driven = dist / 1000
    if km_driven < 0.01 then return end
    local m = agg and Config.AggressiveMultiplier or 1.0

    -- Save old values for threshold check
    local old_mileage = c.mileage
    local old_engine = c.wear_engine
    local old_trans = c.wear_transmission
    local old_brakes = c.wear_brakes
    local old_susp = c.wear_suspension
    local old_tires = c.wear_tires

    -- Update mileage and wears (keep as float)
    c.mileage = c.mileage + km_driven
    c.wear_engine = math.min(100.0, c.wear_engine + (Config.WearRates.engine * km_driven / 100 * m))
    c.wear_transmission = math.min(100.0, c.wear_transmission + (Config.WearRates.transmission * km_driven / 100 * m))
    c.wear_brakes = math.min(100.0, c.wear_brakes + (Config.WearRates.brakes * km_driven / 100 * m))
    c.wear_suspension = math.min(100.0, c.wear_suspension + (Config.WearRates.suspension * km_driven / 100 * m))
    c.wear_tires = math.max(0.0, c.wear_tires - (Config.WearRates.tires * km_driven / 100 * m))  -- FIX: Subtract for tires (health)

    -- Check if changed enough for DB update
    local changed = (c.mileage - old_mileage >= Config.MileageThreshold) or
                    (math.abs(c.wear_engine - old_engine) >= Config.WearThreshold) or
                    (math.abs(c.wear_transmission - old_trans) >= Config.WearThreshold) or
                    (math.abs(c.wear_brakes - old_brakes) >= Config.WearThreshold) or
                    (math.abs(c.wear_suspension - old_susp) >= Config.WearThreshold) or
                    (math.abs(c.wear_tires - old_tires) >= Config.WearThreshold)

    if not changed then return end

    -- Update DB (no floor, keep decimals)
    MySQL.update('UPDATE vehicle_wear SET mileage = ?, wear_engine = ?, wear_transmission = ?, wear_brakes = ?, wear_suspension = ?, wear_tires = ? WHERE plate = ?', {
        c.mileage, c.wear_engine, c.wear_transmission,
        c.wear_brakes, c.wear_suspension, c.wear_tires, plate
    })
    TriggerClientEvent('xer_vwear:client:syncCache', -1, c)

    if Config.Debug then
        print("^2[DEBUG] Updated wear for " .. plate .. ": Mileage=" .. c.mileage .. ", Tires=" .. c.wear_tires)
    end
end)

RegisterNetEvent('xer_vwear:server:requestData', function(plate)
    local src = source
    -- Rate-limit: Reuse loadWear's cooldown
    if RequestCooldowns[src] and GetGameTimer() - RequestCooldowns[src] < 5000 then return end
    RequestCooldowns[src] = GetGameTimer()

    plate = QBCore.Shared.Trim(plate)
    if Cache[plate] then 
        TriggerClientEvent('xer_vwear:client:syncCache', src, Cache[plate])
    end
end)

RegisterNetEvent('xer_vwear:server:syncOnExit', function(plate)
    plate = QBCore.Shared.Trim(plate)
    if not Cache[plate] then return end
    
    local c = Cache[plate]
    MySQL.update('UPDATE vehicle_wear SET mileage = ?, wear_engine = ?, wear_transmission = ?, wear_brakes = ?, wear_suspension = ?, wear_tires = ? WHERE plate = ?', {
        c.mileage, c.wear_engine, c.wear_transmission,
        c.wear_brakes, c.wear_suspension, c.wear_tires, plate
    })
    
    Cache[plate] = nil
end)

-- Admin command to reset vehicle wear/mileage
QBCore.Commands.Add("resetvehiclewear", "Reset wear & mileage of a vehicle (Admin only)", {
    { name = "plate", help = "Vehicle plate (optional - if empty, uses closest vehicle)" }
}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not QBCore.Functions.HasPermission(src, "admin") then
        return TriggerClientEvent('QBCore:Notify', src, "You don't have permission!", "error")
    end

    local plate = args[1] and QBCore.Shared.Trim(string.upper(args[1])) or nil

    if not plate then
        -- No plate: Get closest vehicle
        local success, targetVeh = GetClosestVehicleFromPlayer(src)
        if not success then
            return TriggerClientEvent('QBCore:Notify', src, "No vehicle nearby!", "error")
        end
        plate = QBCore.Shared.Trim(string.upper(GetVehicleNumberPlateText(targetVeh)))
    end

    -- Reset DB (decimals)
    MySQL.update('UPDATE vehicle_wear SET mileage = 0, wear_engine = 0.0, wear_transmission = 0.0, wear_brakes = 0.0, wear_suspension = 0.0, wear_tires = 100.0 WHERE plate = ?', { plate })

    -- Reset cache
    if Cache[plate] then
        Cache[plate].mileage = 0
        Cache[plate].wear_engine = 0.0
        Cache[plate].wear_transmission = 0.0
        Cache[plate].wear_brakes = 0.0
        Cache[plate].wear_suspension = 0.0
        Cache[plate].wear_tires = 100.0
        TriggerClientEvent('xer_vwear:client:syncCache', -1, Cache[plate])
    end

    TriggerClientEvent('QBCore:Notify', src, ("Vehicle %s reset!"):format(plate), "success")
    SendLog("Admin " .. GetPlayerName(src) .. " (" .. src .. ") reset vehicle " .. plate)
end, "admin")