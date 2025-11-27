-- client/modules/tires.lua (minor: check if all tires burst before retry)
local burstCooldown = {}
local smokePtfx = {}
local lastWear = 0

local function getRandomBurstableTire(veh)
    for i = 0, 7 do
        if not IsVehicleTyreBurst(veh, i, false) then
            return i
        end
    end
    return nil
end

RegisterNetEvent('xer_vwear:tires:apply', function(wear)
    if math.abs(wear - lastWear) < 1 then return end
    lastWear = wear

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or not DoesEntityExist(veh) then return end

    wear = math.max(0.0, math.min(100.0, wear or 100.0))

    local plate = QBCore.Functions.GetPlate(veh)

    -- Cleanup old smoke
    for _, ptfx in ipairs(smokePtfx) do
        if ptfx then StopParticleFxLooped(ptfx, false) end
    end
    smokePtfx = {}

    -- === TIRE BURST ===
    if wear <= 8 then
        if not burstCooldown[plate] then
            local tire = getRandomBurstableTire(veh)
            if tire then  -- Only if there's a tire left to burst
                burstCooldown[plate] = true

                SetVehicleTyreBurst(veh, tire, true, 1000.0)
                TriggerEvent('QBCore:Notify', 'A tire has burst!', 'error')
                PlaySoundFrontend(-1, "ScreenFlash", "MissionFailedSounds", true)

                SetTimeout(15000, function()
                    burstCooldown[plate] = nil
                end)
            end
        end
    end

    -- === Optional: Light smoke for worn tires ===
    if wear <= 30 and wear > 8 then
        UseParticleFxAsset("core")
        local validTires = {0,1,2,3,4,5,6,7}
        for i, tireIndex in ipairs(validTires) do
            if not IsVehicleTyreBurst(veh, tireIndex, false) then
                smokePtfx[i] = StartParticleFxLoopedOnEntity(
                    "veh_tyresmoke",
                    veh,
                    0.0, 0.0, -0.4,
                    0.0, 0.0, 0.0,
                    1.2, false, false, false
                )
            end
        end
    end
end)

RegisterNetEvent('xer_vwear:tires:cleanup', function()
    burstCooldown = {}
    for _, ptfx in ipairs(smokePtfx) do
        if ptfx then StopParticleFxLooped(ptfx, false) end
    end
    smokePtfx = {}
end)