-- client/modules/suspension.lua (minor: added early exit)
local bottomOutThread = nil
local lastWear = 0

RegisterNetEvent('xer_vwear:suspension:apply', function(wear)
    if math.abs(wear - lastWear) < 1 then return end
    lastWear = wear

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    -- Cleanup if not in vehicle or repaired
    if not veh or not DoesEntityExist(veh) or wear < 70 then
        if bottomOutThread then
            bottomOutThread = false
        end
        -- Reset to normal height when repaired or exited
        SetVehicleSuspensionHeight(veh, 0.0)
        return
    end

    -- Negative = lowered, Positive = raised
    -- High wear = bad = more drop
    local suspensionDrop = 0.0

    if wear >= 95 then
        suspensionDrop = -0.22    -- Completely slammed / broken
    elseif wear >= 85 then
        suspensionDrop = -0.18
    elseif wear >= 70 then
        suspensionDrop = -0.12
    elseif wear >= 50 then
        suspensionDrop = -0.06
    end

    -- Apply the drop
    SetVehicleSuspensionHeight(veh, suspensionDrop)

    -- Bottoming-out effects only when really bad (>= 70%)
    if wear < 70 then
        if bottomOutThread then bottomOutThread = false end
        return
    end

    -- Start spark/scrape effects when suspension is trashed
    if not bottomOutThread then
        bottomOutThread = true
        CreateThread(function()
            while bottomOutThread and GetVehiclePedIsIn(ped, false) == veh do
                Wait(120)

                local velocity = GetEntityVelocity(veh)
                local speed = #(velocity)
                local zVel = velocity.z

                -- Trigger on bumps / landing hard
                if math.abs(zVel) > 3.2 or (speed > 8.0 and math.abs(zVel) > 1.8) then
                    -- Sparks + scrape sound
                    UseParticleFxAsset("core")
                    StartParticleFxLoopedOnEntity("veh_light_red_trail", veh, 0.0, 0.0, -0.9, 0.0, 0.0, 0.0, 1.8, false, false, false)

                    PlaySoundFromEntity(-1, "SCRAPE_METAL_LONG", veh, "DLC_HEISTS_BIOLAB_FINALE_SOUNDS", false, 0)
                    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.08)

                    -- Extra body damage if suspension is completely shot
                    if wear >= 95 then
                        local current = GetVehicleBodyHealth(veh)
                        SetVehicleBodyHealth(veh, current - 0.6)
                    end
                end
            end
            bottomOutThread = nil
        end)
    end
end)

RegisterNetEvent('xer_vwear:suspension:cleanup', function()
    bottomOutThread = false
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh and DoesEntityExist(veh) then
        SetVehicleSuspensionHeight(veh, 0.0)
    end
end)