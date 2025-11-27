-- client/modules/brakes.lua (minor: early exit if not braking)
local ptfx = {}
local soundId = nil
local lockupTimer = 0
local lastWear = 0

RegisterNetEvent('xer_vwear:brakes:apply', function(wear)
    if math.abs(wear - lastWear) < 1 then return end
    lastWear = wear

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then 
        for i=1,4 do if ptfx[i] then StopParticleFxLooped(ptfx[i], false); ptfx[i]=nil end end
        if soundId then StopSound(soundId); ReleaseSoundId(soundId); soundId=nil end
        lockupTimer = 0
        return 
    end

    -- Progressive brake power
    local power = wear >= 95 and 0.25 or (wear >= 90 and 0.5 or (wear >= 70 and 0.75 or 1.0))
    SetVehicleHandlingFloat(veh, "CHandlingData", "fBrakeForce", power)

    CreateThread(function()
        while GetVehiclePedIsIn(ped, false) == veh do
            Wait(0)
            if IsControlPressed(0, 72) and wear >= 70 then  -- Brake input
                local scale = 0.1 + ((wear) / 300)  -- Bad wear = more smoke
                for i, bone in ipairs({"wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr"}) do
                    local boneId = GetEntityBoneIndexByName(veh, bone)
                    if boneId ~= -1 and not ptfx[i] then
                        UseParticleFxAsset("core")
                        ptfx[i] = StartParticleFxLoopedOnEntityBone("wheel_fric_hard_dusty", veh, boneId, 0.0, -0.4, 0.3, 0.0, 0.0, 180.0, scale, false, false, false)
                    end
                end

                if not soundId then
                    soundId = GetSoundId()
                    PlaySoundFromEntity(soundId, "TYRE_SCREECH_LOOPING", veh, "DLC_BTL_Casino_Heist_Sounds", true, 70)
                end

                if wear >= 95 then
                    lockupTimer = lockupTimer + 1
                    if lockupTimer > math.random(100, 250) then
                        TriggerEvent('QBCore:Notify', 'BRAKES LOCKED UP!', 'error')
                        SetVehicleHandbrake(veh, true)
                        Wait(700)
                        SetVehicleHandbrake(veh, false)
                        lockupTimer = 0
                    end
                end
            else
                -- Cleanup non-braking
                for i=1,4 do if ptfx[i] then StopParticleFxLooped(ptfx[i], false); ptfx[i]=nil end end
                if soundId then StopSound(soundId); ReleaseSoundId(soundId); soundId=nil end
                Wait(100)  -- Efficiency: Sleep longer when not braking
            end
        end
    end)
end)

RegisterNetEvent('xer_vwear:brakes:cleanup', function()
    for i=1,4 do if ptfx[i] then StopParticleFxLooped(ptfx[i], false); ptfx[i]=nil end end
    if soundId then StopSound(soundId); ReleaseSoundId(soundId); soundId=nil end
    lockupTimer = 0
end)