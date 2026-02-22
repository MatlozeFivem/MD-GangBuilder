ESX = exports["es_extended"]:getSharedObject()

local PointMenuOpen = false
local mainMenu = RageUI.CreateMenu("Gang", "Interactions")
local cloakroomMenu = RageUI.CreateSubMenu(mainMenu, "Vestiaire", "Selectionnez votre tenue")
local garageMenu = RageUI.CreateSubMenu(mainMenu, "Garage", "Actions du garage")
local bossMenu = RageUI.CreateSubMenu(mainMenu, "Gestion Boss", "Actions du patron")
local membersMenu = RageUI.CreateSubMenu(bossMenu, "Membres", "Gestion des membres")

local outfits = {}
local currentPointPos = nil
local gangMembers = {}

local function GetGradeLabel(gangName, gradeNum)
    if Gangs[gangName] and Gangs[gangName].grades then
        for _, v in ipairs(Gangs[gangName].grades) do
            if tonumber(v.grade) == tonumber(gradeNum) then
                return v.label
            end
        end
    end
    return "Grade " .. gradeNum
end

-- Appliquer le theme rouge
for _, m in ipairs({mainMenu, cloakroomMenu, garageMenu, bossMenu, membersMenu}) do
    m:SetRectangleBanner(Config.MenuColor.r, Config.MenuColor.g, Config.MenuColor.b, Config.MenuColor.a)
end

mainMenu.Closed = function() PointMenuOpen = false end

function OpenRagePointMenu(type, pos)
    if PointMenuOpen then PointMenuOpen = false RageUI.Visible(mainMenu, false) return end
    
    currentPointPos = pos
    PointMenuOpen = true
    RageUI.Visible(mainMenu, true)

    -- No outfit fetching needed for now

    Citizen.CreateThread(function()
        while PointMenuOpen do
            Wait(0)
            RageUI.IsVisible(mainMenu, true, true, true, function()
                if type == 'cloakroom' then
                    RageUI.Button("Vestiaire", nil, {RightLabel = "~r~Exécuter ~s~>"}, true, {}, cloakroomMenu)
                elseif type == 'garage' or type == 'garage_spawn' or type == 'garage_store' then
                    RageUI.Button("Garage", nil, {RightLabel = "~r~Exécuter ~s~>"}, true, {}, garageMenu)
                elseif type == 'boss' then
                    RageUI.Button("Gestion Boss", nil, {RightLabel = "~r~Exécuter ~s~>"}, true, {}, bossMenu)
                end
            end)

            -- Cloakroom Menu
            RageUI.IsVisible(cloakroomMenu, true, true, true, function()
                local playerJob2 = ESX.GetPlayerData().job2
                
                RageUI.Button("Tenue Civil", "Remettre votre tenue de base", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                            TriggerEvent('skinchanger:loadSkin', skin)
                        end)
                    end
                })

                if playerJob2 and Config.Outfits[playerJob2.name] then
                    local outfit = Config.Outfits[playerJob2.name]
                    RageUI.Button(outfit.label or "Tenue de Gang", "Enfiler votre tenue de service", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                        onSelected = function()
                            TriggerEvent('skinchanger:getSkin', function(skin)
                                if skin.sex == 0 then
                                    if outfit.male then
                                        TriggerEvent('skinchanger:loadClothes', skin, outfit.male)
                                    end
                                else
                                    if outfit.female then
                                        TriggerEvent('skinchanger:loadClothes', skin, outfit.female)
                                    end
                                end
                            end)
                        end
                    })
                end
            end)

            -- Garage Menu
            RageUI.IsVisible(garageMenu, true, true, true, function()
                local playerJob2 = ESX.GetPlayerData().job2
                
                -- Only show spawn options if at garage_spawn or old garage point
                if type == 'garage' or type == 'garage_spawn' then
                    if playerJob2 and Gangs[playerJob2.name] and Gangs[playerJob2.name].vehicles then
                        local authorizedVehicles = Gangs[playerJob2.name].vehicles
                        
                        if #authorizedVehicles > 0 then
                            RageUI.Separator("--- Véhicules Disponibles ---")
                            for _, vehicleModel in ipairs(authorizedVehicles) do
                                RageUI.Button(vehicleModel:upper(), "Sortir ce vehicule", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                                    onSelected = function()
                                        if ESX.Game.IsSpawnPointClear(vector3(currentPointPos.x, currentPointPos.y, currentPointPos.z), 3.0) then
                                            ESX.Game.SpawnVehicle(vehicleModel, vector3(currentPointPos.x, currentPointPos.y, currentPointPos.z), currentPointPos.w or 0.0, function(vehicle)
                                                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                                                
                                                -- Apply gang color
                                                local gangData = Gangs[playerJob2.name]
                                                if gangData and gangData.color then
                                                    local colorId = gangData.color
                                                    SetVehicleColours(vehicle, colorId, colorId)
                                                end
                                                
                                                ESX.ShowNotification("~g~Véhicule sorti")
                                            end)
                                        else
                                            ESX.ShowNotification("~r~Zone encombrée")
                                        end
                                    end
                                })
                            end
                        else
                            RageUI.Separator("~r~Aucun véhicule configuré")
                        end
                    end
                end

                -- Only show store options if at garage_store or old garage point
                if type == 'garage' or type == 'garage_store' then
                    RageUI.Separator("--- Actions ---")
                    RageUI.Button("Ranger le vehicule", "Supprimer le vehicule actuel", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                        onSelected = function()
                            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                            if veh ~= 0 then
                                ESX.Game.DeleteVehicle(veh)
                                ESX.ShowNotification("~g~Véhicule rangé")
                            else
                                ESX.ShowNotification("~r~Vous n'êtes pas dans un véhicule")
                            end
                        end
                    })
                end
            end)

            -- Boss Menu
            RageUI.IsVisible(bossMenu, true, true, true, function()
                RageUI.Button("Recruter", "Recruter le joueur le plus proche", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            TriggerServerEvent('md_gangbuilder:bossAction', 'recruit', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("~r~Aucun joueur à proximité")
                        end
                    end
                })

                RageUI.Button("Virer", "Virer le joueur le plus proche", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                        if closestPlayer ~= -1 and closestDistance <= 3.0 then
                            TriggerServerEvent('md_gangbuilder:bossAction', 'fire', GetPlayerServerId(closestPlayer))
                        else
                            ESX.ShowNotification("~r~Aucun joueur à proximité")
                        end
                    end
                })


                RageUI.Separator("--- Gestion RH ---")
                RageUI.Button("Liste des Membres", "Voir et gérer tous les membres", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        local playerJob2 = ESX.GetPlayerData().job2
                        ESX.TriggerServerCallback('md_gangbuilder:getMembers', function(members)
                            gangMembers = members
                            RageUI.Visible(membersMenu, true)
                        end, playerJob2.name)
                    end
                })
            end)

            -- Members Management Submenu
            RageUI.IsVisible(membersMenu, true, true, true, function()
                local playerJob2 = ESX.GetPlayerData().job2
                if #gangMembers > 0 then
                    for i, member in ipairs(gangMembers) do
                        local gradeLabel = GetGradeLabel(playerJob2.name, member.grade)
                        RageUI.Button(member.name, "Grade: " .. gradeLabel, {RightLabel = "~r~Actions ~s~>"}, true, {
                            onSelected = function()
                                local actionConfirm = KeyboardInput("Action: PROMOUVOIR, RETROGRADER, VIRER", "", 15)
                                if actionConfirm then
                                    local action = actionConfirm:upper()
                                    if action == "PROMOUVOIR" then
                                        TriggerServerEvent('md_gangbuilder:updateMemberRank', playerJob2.name, member.identifier, member.grade + 1)
                                        RageUI.GoBack()
                                    elseif action == "RETROGRADER" then
                                        if member.grade > 0 then
                                            TriggerServerEvent('md_gangbuilder:updateMemberRank', playerJob2.name, member.identifier, member.grade - 1)
                                            RageUI.GoBack()
                                        else
                                            ESX.ShowNotification("~r~Déjà au grade minimum")
                                        end
                                    elseif action == "VIRER" then
                                        local confirmFire = KeyboardInput("Taper OUI pour confirmer", "", 5)
                                        if confirmFire and confirmFire:upper() == "OUI" then
                                            TriggerServerEvent('md_gangbuilder:fireMember', playerJob2.name, member.identifier)
                                            table.remove(gangMembers, i)
                                            RageUI.GoBack()
                                        end
                                    end
                                end
                            end
                        })
                    end
                else
                    RageUI.Separator("~r~Aucun membre trouvé")
                end
            end)
        end
    end)
end

-- Helper for keyboard input
function KeyboardInput(TextEntry, ExampleText, MaxStringLength)
    AddTextEntry('FMMC_KEY_TIP1', TextEntry .. ':')
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", ExampleText, "", "", "", MaxStringLength)
    while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do
        Wait(0)
    end
    if UpdateOnscreenKeyboard() ~= 2 then
        local result = GetOnscreenKeyboardResult()
        Wait(500)
        return result
    else
        Wait(500)
        return nil
    end
end
