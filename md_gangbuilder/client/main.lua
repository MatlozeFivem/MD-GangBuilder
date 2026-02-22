print("[md_gangbuilder] Client script loading...")

ESX = exports["es_extended"]:getSharedObject()

Gangs = {}
PlayerData = {}
local GangBlips = {}

-- Helper: get color config by vehicle color id
function GetGangColorConfig(colorId)
    for _, c in ipairs(Config.GangColors) do
        if c.id == colorId then return c end
    end
    return Config.GangColors[1] -- fallback noir
end

-- Unified source for PlayerData
function UpdatePlayerData()
    local oldData = PlayerData
    PlayerData = ESX.GetPlayerData()
    if not PlayerData.job2 then 
        PlayerData.job2 = {name = 'unemployed', grade = 0} 
    end
    
    -- Print sync status only if it changed
    if not oldData.job2 or oldData.job2.name ~= PlayerData.job2.name or oldData.job2.grade ~= PlayerData.job2.grade then
        print(("[md_gangbuilder] PlayerData Sync: Gang=%s, Grade=%s"):format(PlayerData.job2.name, PlayerData.job2.grade))
    end
end

-- Blip Management
function RefreshGangBlips()
    for _, blip in ipairs(GangBlips) do RemoveBlip(blip) end
    GangBlips = {}

    if not PlayerData or not PlayerData.job2 then return end

    for gangName, gang in pairs(Gangs) do
        if gang.blip_enabled then
            local canSee = false
            if gang.blip_visibility == 'all' then
                canSee = true
            elseif gang.blip_visibility == 'members' and PlayerData.job2.name == gangName then
                canSee = true
            end

            if canSee then
                local colorConfig = GetGangColorConfig(gang.color or 0)
                local blipPos = nil
                local priority = {'boss', 'stash', 'cloakroom', 'garage_spawn', 'garage'}
                for _, p in ipairs(priority) do
                    if gang[p] and type(gang[p]) == 'table' and gang[p].x then
                        blipPos = gang[p]
                        break
                    end
                end

                if blipPos then
                    local blip = AddBlipForCoord(blipPos.x, blipPos.y, blipPos.z)
                    SetBlipSprite(blip, Config.Blip.Sprite)
                    SetBlipDisplay(blip, Config.Blip.Display)
                    SetBlipScale(blip, Config.Blip.Scale)
                    SetBlipColour(blip, colorConfig.blipColor)
                    SetBlipAsShortRange(blip, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentSubstringPlayerName(gang.label)
                    EndTextCommandSetBlipName(blip)
                    table.insert(GangBlips, blip)
                end
            end
        end
    end
end

Citizen.CreateThread(function()
    print("[md_gangbuilder] Waiting for player to be ready...")
    while ESX.GetPlayerData().job == nil do Wait(100) end
    
    UpdatePlayerData()
    
    ESX.TriggerServerCallback('md_gangbuilder:getGangs', function(cb)
        if cb then
            Gangs = cb
            local count = 0
            for _ in pairs(Gangs) do count = count + 1 end
            print("[md_gangbuilder] Successfully requested gangs. Total: " .. count)
            RefreshGangBlips()
        end
    end)
end)

-- Debug command to see your current gang status
RegisterCommand('mddebug', function()
    print("^3--- MD GANGBUILDER EXTENDED DEBUG ---^7")
    UpdatePlayerData()
    
    local j2 = PlayerData.job2
    print("PLAYER DATA:")
    print(" - Name: " .. GetPlayerName(PlayerId()))
    print(" - Job2 Name: " .. tostring(j2.name))
    print(" - Job2 Grade: " .. tostring(j2.grade))
    
    local gang = Gangs[j2.name]
    if not gang then
        local count = 0
        for _ in pairs(Gangs) do count = count + 1 end
        print("^1ERROR: Gang '" .. tostring(j2.name) .. "' NOT FOUND on client table. Loaded count: " .. count .. "^7")
        ESX.ShowNotification("~r~ERREUR: Gang non trouvé sur le client")
        return
    end
    
    print("GANG DATA FOUND:")
    print(" - Label: " .. tostring(gang.label))
    
    local points = {'boss', 'stash', 'cloakroom', 'garage_spawn', 'garage_store'}
    for _, p in ipairs(points) do
        local pos = gang[p]
        if pos and pos.x then
            local pLimit = (gang.permissions and gang.permissions[p]) or 0
            print(("^2 - Point '%s'^7: x=%.2f, y=%.2f, z=%.2f | Requis: %s"):format(p, pos.x, pos.y, pos.z, pLimit))
            if tonumber(j2.grade) >= tonumber(pLimit) then
                print("   ^2-> ACCÈS OK^7")
            else
                print("   ^1-> ACCÈS REFUSÉ (Grade trop bas)^7")
            end
        else
            print(" - Point '" .. p .. "': ^8NON DÉFINI^7")
        end
    end
    
    ESX.ShowNotification("~g~Debug complet envoyé dans la console F8")
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    RefreshGangBlips()
end)

RegisterNetEvent('esx:setJob2')
AddEventHandler('esx:setJob2', function(job2)
    PlayerData.job2 = job2
    print("[md_gangbuilder] Event esx:setJob2 received: " .. tostring(job2.name))
    RefreshGangBlips()
end)

RegisterNetEvent('md_gangbuilder:updateGangs')
AddEventHandler('md_gangbuilder:updateGangs', function(updatedGangs)
    print("[md_gangbuilder] Received updated gangs from server")
    Gangs = updatedGangs
    RefreshGangBlips()
end)

-- Non-point keys to skip in marker loop
local skipKeys = {
    label = true, grades = true, vehicles = true, permissions = true,
    webhook = true, color = true, blip_enabled = true, blip_visibility = true, outfits = true,
    marker_type = true, garage = true
}

-- Markers and Interaction Loop
Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        -- Use the unified PlayerData
        if PlayerData and PlayerData.job2 and Gangs[PlayerData.job2.name] then
            local gang = Gangs[PlayerData.job2.name]
            wait = 500

            for pointType, pos in pairs(gang) do
                if not skipKeys[pointType] and pos and type(pos) == 'table' and pos.x and pos.y and pos.z then
                    local minGrade = tonumber((gang.permissions and gang.permissions[pointType]) or 0) or 0
                    local playerGrade = tonumber(PlayerData.job2.grade or 0)
                    
                    if playerGrade >= minGrade then
                        local dist = #(coords - vector3(pos.x, pos.y, pos.z))

                        if dist < 15.0 then
                            wait = 0
                            local markerType = tonumber(gang.marker_type) or 1
                            local colorCfg = GetGangColorConfig(gang.color or 0)
                            local r, g, b = colorCfg.r or 255, colorCfg.g or 255, colorCfg.b or 255
                            local zOffset = -0.95

                            -- Adjust height for specific markers that are submerged
                            if markerType == 2 or markerType == 3 or markerType == 20 or markerType == 21 or markerType == 29 or markerType == 30 or markerType == 31 then
                                zOffset = -0.50
                            end
                            
                            DrawMarker(markerType, pos.x, pos.y, pos.z + zOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, r, g, b, Config.MarkerColor.a, false, true, 2, false, nil, nil, false)

                            if dist < 1.5 then
                                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour accéder au " .. (Config.PointsLabels[pointType] or pointType))
                                if IsControlJustReleased(0, 38) then
                                    if pointType == 'stash' then
                                        exports.ox_inventory:openInventory('stash', {id = PlayerData.job2.name .. '_stash'})
                                    else
                                        OpenRagePointMenu(pointType, pos)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

print("[md_gangbuilder] Client script FULLY LOADED")
