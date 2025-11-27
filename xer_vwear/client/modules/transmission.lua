-- client/modules/transmission.lua
local transmissionActive = false
local lastWear = 0

RegisterNetEvent('xer_vwear:transmission:apply', function(wear)
    if math.abs(wear - lastWear) < 1 then return end
    lastWear = wear

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    -- Stop everything if repaired or not in vehicle
    if not veh or wear < 85 then
        transmissionActive = false
        return
    end

    CreateThread(function()
        while GetVehiclePedIsIn(ped, false) == veh do
            Wait(math.random(10000, 25000))

            if math.random() < 0.7 then
                -- Transmission slip effect
                SetVehicleCurrentGear(veh, 0)
                Wait(1000)
                SetVehicleCurrentGear(veh, GetVehicleCurrentGear(veh) + 1)

                -- Only activate the HUD warning
                transmissionActive = true
            end
        end

        -- Left the vehicle → remove warning
        transmissionActive = false
    end)

    -- Persistent top-right HUD text (only thing that shows)
    CreateThread(function()
        while true do
            Wait(0)
            if not transmissionActive then break end

            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.0, 0.45)
            SetTextColour(255, 35, 35, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextRightJustify(true)
            SetTextWrap(0.0, 0.96)
            SetTextEntry("STRING")
            AddTextComponentString("~r~TRANSMISSION SLIPPING!")
            DrawText(0.96, 0.04)   -- Perfect top-right position
        end
    end)
end)

RegisterNetEvent('xer_vwear:transmission:cleanup', function()
    transmissionActive = false
end)