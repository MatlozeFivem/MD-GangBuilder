ESX = exports["es_extended"]:getSharedObject()

local F7MenuOpen = false
local mainMenuF7 = RageUI.CreateMenu("Gang Menu", "Interactions")
local citizenMenuF7 = RageUI.CreateSubMenu(mainMenuF7, "Actions Citoyens", "Interactions")
local vehicleMenuF7 = RageUI.CreateSubMenu(mainMenuF7, "Actions Véhicules", "Interactions")
local bossMenuF7 = RageUI.CreateSubMenu(mainMenuF7, "Gestion Boss", "Interactions")

local IsDragging = false
local DragTarget = nil
local DragStatus = { isDragged = false, dragger = nil }
local isHooded = false
local hoodProp = nil

-- Appliquer le theme rouge
for _, m in ipairs({mainMenuF7, citizenMenuF7, vehicleMenuF7, bossMenuF7}) do
    m:SetRectangleBanner(Config.MenuColor.r, Config.MenuColor.g, Config.MenuColor.b, Config.MenuColor.a)
end

mainMenuF7.Closed = function() F7MenuOpen = false end

function OpenF7Menu()
    if F7MenuOpen then F7MenuOpen = false RageUI.Visible(mainMenuF7, false) return end
    F7MenuOpen = true
    RageUI.Visible(mainMenuF7, true)

    Citizen.CreateThread(function()
        while F7MenuOpen do
            Wait(0)
            RageUI.IsVisible(mainMenuF7, true, true, true, function()
                RageUI.Button("Actions Citoyens", nil, {RightLabel = "→"}, true, {}, citizenMenuF7)
                RageUI.Button("Actions Véhicules", nil, {RightLabel = "→"}, true, {}, vehicleMenuF7)
                RageUI.Button("Gestion Entreprise", nil, {RightLabel = "→"}, true, {}, bossMenuF7)
            end)

            RageUI.IsVisible(citizenMenuF7, true, true, true, function()
                RageUI.Separator("--- Interactions Joueurs ---")
                RageUI.Button("Fouiller", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('search', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })
                RageUI.Button("Prendre la carte d'identité", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('idcard', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })

                RageUI.Separator("--- Roleplay Avancé ---")
                RageUI.Button(IsDragging and "Arrêter d'escorter" or "Escorter", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('escort', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })

                RageUI.Button("Mettre / Enlever la cagoule", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('hood', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })

                RageUI.Button("Mettre dans le véhicule", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('put_in_vehicle', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })

                RageUI.Button("Sortir du véhicule", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            ExecuteAction('out_vehicle', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })
                
                RageUI.Button(isHostage and "Libérer l'otage" or "Prendre en otage", nil, {}, true, {
                    onSelected = function()
                        if isHostage then
                            ExecuteHostageAction(nil)
                        else
                            local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                            if closestPlayer ~= -1 and closestDistance <= 2.0 then
                                ExecuteAction('hostage', GetPlayerServerId(closestPlayer))
                            else
                                ESX.ShowNotification("Aucun joueur a proximité")
                            end
                        end
                    end
                })
            end)

            RageUI.IsVisible(vehicleMenuF7, true, true, true, function()
                RageUI.Separator("--- Actions Véhicules ---")
                RageUI.Button("Crocheter le véhicule", nil, {}, true, {
                    onSelected = function()
                        local vehicle = ESX.Game.GetVehicleInDirection()
                        if DoesEntityExist(vehicle) then
                            ExecuteAction('lockpick', vehicle)
                        else
                            ESX.ShowNotification("Aucun véhicule en face")
                        end
                    end
                })
            end)

            RageUI.IsVisible(bossMenuF7, true, true, true, function()
                RageUI.Button("Recruter", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            TriggerServerEvent('md_gangbuilder:bossAction', 'recruit', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })
                RageUI.Button("Virer", nil, {}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            TriggerServerEvent('md_gangbuilder:bossAction', 'fire', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("Aucun joueur a proximité")
                        end
                    end
                })
            end)
        end
    end)
end

function ExecuteAction(action, target)
    local playerPed = PlayerPedId()
    if action == 'search' then
        if lib.progressBar({
            duration = Config.F7Menu.SearchTime,
            label = 'Fouille en cours...',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true },
            anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base' },
        }) then
            TriggerServerEvent('md_gangbuilder:searchPlayer', target)
        end
    elseif action == 'idcard' then
        TriggerServerEvent('md_gangbuilder:requestIdCard', target)
    elseif action == 'escort' then
        TriggerServerEvent('md_gangbuilder:escort', target)
        IsDragging = not IsDragging
    elseif action == 'put_in_vehicle' then
        TriggerServerEvent('md_gangbuilder:putInVehicle', target)
    elseif action == 'out_vehicle' then
        TriggerServerEvent('md_gangbuilder:outVehicle', target)
    elseif action == 'hood' then
        TriggerServerEvent('md_gangbuilder:setHood', target)
    elseif action == 'hostage' then
        ExecuteHostageAction(target)
    elseif action == 'lockpick' then
        if lib.progressBar({
            duration = Config.F7Menu.LockpickTime,
            label = 'Crochetage en cours...',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true },
            anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
        }) then
            SetVehicleDoorsLocked(target, 1)
            SetVehicleDoorsLockedForAllPlayers(target, false)
            ESX.ShowNotification("Véhicule crocheté")
        end
    end
end

-- Key mapping for F7
lib.addKeybind({
    name = 'gang_menu_f7',
    description = 'Ouvrir le menu gang',
    defaultKey = 'F7',
    onPressed = function()
        local job2 = ESX.GetPlayerData().job2
        if not job2 or job2.name == 'unemployed' then return end

        ESX.TriggerServerCallback('md_gangbuilder:getGangs', function(gangs)
            if gangs[job2.name] then
                OpenF7Menu()
            end
        end)
    end
})

RegisterNetEvent('md_gangbuilder:showIDCard')
AddEventHandler('md_gangbuilder:showIDCard', function(data)
    -- Simple display of identity data
    local message = ("Nom: %s %s\nNé le: %s\nSexe: %s"):format(data.firstname, data.lastname, data.dateofbirth, data.sex == 'm' and 'Masculin' or 'Féminin')
    ESX.ShowNotification(message)
end)

-- Target Handling for Advanced Interactions
RegisterNetEvent('md_gangbuilder:dragPlayer')
AddEventHandler('md_gangbuilder:dragPlayer', function(draggerId)
    DragStatus.isDragged = not DragStatus.isDragged
    DragStatus.dragger = draggerId

    Citizen.CreateThread(function()
        while DragStatus.isDragged do
            Wait(0)
            local draggerPed = GetPlayerPed(GetPlayerFromServerId(DragStatus.dragger))
            local playerPed = PlayerPedId()
            if not IsPedSittingInAnyVehicle(draggerPed) then
                AttachEntityToEntity(playerPed, draggerPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            else
                DragStatus.isDragged = false
                DetachEntity(playerPed, true, false)
            end
            
            if IsPedDeadOrDying(draggerPed, true) then
                DragStatus.isDragged = false
                DetachEntity(playerPed, true, false)
            end
        end
        DetachEntity(PlayerPedId(), true, false)
    end)
end)

RegisterNetEvent('md_gangbuilder:putInVehicle')
AddEventHandler('md_gangbuilder:putInVehicle', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then
        local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
        if DoesEntityExist(vehicle) then
            local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
            local freeSeat = nil

            for i = maxSeats - 1, 0, -1 do
                if IsVehicleSeatFree(vehicle, i) then
                    freeSeat = i
                    break
                end
            end

            if freeSeat then
                TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
            end
        end
    end
end)

RegisterNetEvent('md_gangbuilder:outVehicle')
AddEventHandler('md_gangbuilder:outVehicle', function()
    local playerPed = PlayerPedId()
    if IsPedSittingInAnyVehicle(playerPed) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 16)
    end
end)

RegisterNetEvent('md_gangbuilder:toggleHood')
AddEventHandler('md_gangbuilder:toggleHood', function()
    isHooded = not isHooded
    local playerPed = PlayerPedId()

    if isHooded then
        -- Attach prop
        local model = `prop_money_bag_01` -- Visual representation of a "hood" (simple bag)
        ESX.Streaming.RequestModel(model)
        hoodProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, true)
        -- Sinking even deeper (negative offset to bring it down)
        AttachEntityToEntity(hoodProp, playerPed, GetPedBoneIndex(playerPed, 31086), -0.05, 0.02, 0.0, 0.0, 90.0, 0.0, true, true, false, true, 1, true)
        
        -- Black screen effect
        Citizen.CreateThread(function()
            while isHooded do
                Wait(0)
                DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
            end
        end)
    else
        if DoesEntityExist(hoodProp) then
            DeleteEntity(hoodProp)
            hoodProp = nil
        end
    end
end)

-- Hostage Logic
local isHostage = false
local currentHostageTarget = nil

function ExecuteHostageAction(target)
    local playerPed = PlayerPedId()
    
    if isHostage then
        -- Libérer l'otage actuel par le menu
        isHostage = false
        if currentHostageTarget then
            TriggerServerEvent('md_gangbuilder:hostageSync', currentHostageTarget, 'stop')
        end
        ClearPedTasks(playerPed)
        currentHostageTarget = nil
        ESX.ShowNotification("Otage libéré")
    else
        -- Commencer la prise d'otage
        if not target then return end
        
        isHostage = true
        currentHostageTarget = target
        Citizen.CreateThread(function()
            local lib = "anim@gangops@hostage@"
            ESX.Streaming.RequestAnimDict(lib)
            
            -- Dragger animation
            TaskPlayAnim(playerPed, lib, "perp_idle", 8.0, -8.0, -1, 49, 0, false, false, false)
            TriggerServerEvent('md_gangbuilder:hostageSync', target, 'start')
            
            while isHostage do
                Wait(0)
                -- Release via key [E] or death
                if IsDisabledControlJustPressed(0, 38) or IsPedDeadOrDying(playerPed) then
                    isHostage = false
                    if currentHostageTarget then
                        TriggerServerEvent('md_gangbuilder:hostageSync', currentHostageTarget, 'stop')
                    end
                    ClearPedTasks(playerPed)
                    currentHostageTarget = nil
                    break
                end
            end
        end)
    end
end

RegisterNetEvent('md_gangbuilder:hostageSyncTarget')
AddEventHandler('md_gangbuilder:hostageSyncTarget', function(draggerId, type)
    local playerPed = PlayerPedId()
    local draggerPed = GetPlayerPed(GetPlayerFromServerId(draggerId))
    local lib = "anim@gangops@hostage@"
    
    if type == 'start' then
        ESX.Streaming.RequestAnimDict(lib)
        AttachEntityToEntity(playerPed, draggerPed, 0, -0.24, 0.11, 0.0, 0.5, 0.5, 0.0, false, false, false, false, 2, true)
        TaskPlayAnim(playerPed, lib, "victim_idle", 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        DetachEntity(playerPed, true, false)
        ClearPedTasks(playerPed)
    end
end)
