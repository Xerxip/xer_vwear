-- client/modules/engine.lua (minor: prevent misfire if engine off)
local smokePtfx = nil
local misfireActive = false
local lastWear = 0

RegisterNetEvent('xer_vwear:engine:apply', function(wear)
    if math.abs(wear - lastWear) < 1 then return end
    lastWear = wear

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then 
        if smokePtfx then StopParticleFxLooped(smokePtfx, false); smokePtfx = nil end
        misfireActive = false
        return 
    end

    -- Clean up any old smoke
    if smokePtfx then 
        StopParticleFxLooped(smokePtfx, false)
        smokePtfx = nil
    end

    -- === REALISTIC ENGINE SMOKE ===
    if wear >= 70 then
        UseParticleFxAsset("core")

        local fxName, scale, alpha

        if wear >= 95 then
            fxName = "veh_exhaust_misfire"
            scale  = 1.4
            alpha  = 0.9
        elseif wear >= 85 then
            fxName = "exp_grd_grenade_smoke"
            scale  = 0.9
            alpha  = 0.7
        else
            fxName = "ent_sht_steam"
            scale  = 0.8
            alpha  = 0.6
        end

        smokePtfx = StartParticleFxLoopedOnEntity(
            fxName, veh,
            0.0, 1.8, -0.3,
            0.0, 0.0, 0.0,
            scale, false, false, false
        )

        SetParticleFxLoopedAlpha(smokePtfx, alpha)
        SetParticleFxLoopedColour(smokePtfx, 0.1, 0.1, 0.1, false)
    end

    -- === NEW: REAL ENGINE POWER LOSS BASED ON WEAR % ===
    local powerMult = 1.0 -- default = no loss

    if wear >= 95 then
        powerMult = 0.45      -- heavily damaged
    elseif wear >= 85 then
        powerMult = 0.65      -- strong loss
    elseif wear >= 70 then
        powerMult = 0.80      -- slight power loss
    end

    -- Apply power and torque reduction
    SetVehicleCheatPowerIncrease(veh, powerMult)
    SetVehicleEnginePowerMultiplier(veh, (powerMult - 1.0) * 100.0)
    SetVehicleEngineTorqueMultiplier(veh, powerMult)

    -- === MISFIRE LOGIC ===
    if wear >= 95 then
        if not misfireActive then
            misfireActive = true
            CreateThread(function()
                while misfireActive and GetVehiclePedIsIn(ped, false) == veh do
                    Wait(math.random(3000, 7000))
                    if math.random() < 0.75 and GetIsVehicleEngineRunning(veh) then  -- Added: Check if engine running
                        SetVehicleEngineOn(veh, false, true, true)
                        Wait(200)
                        SetVehicleEngineOn(veh, true, false, true)
                    end
                end
            end)
        end
    else
        misfireActive = false
    end
end)

RegisterNetEvent('xer_vwear:engine:cleanup', function()
    if smokePtfx then 
        StopParticleFxLooped(smokePtfx, false)
        smokePtfx = nil 
    end
    misfireActive = false
end)