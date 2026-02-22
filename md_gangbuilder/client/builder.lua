ESX = exports["es_extended"]:getSharedObject()


local open = false
local mainMenu = RageUI.CreateMenu("Gang Builder", "Administration")
local createMenu = RageUI.CreateSubMenu(mainMenu, "Creer un Gang", "Configuration")
local editMenu = RageUI.CreateSubMenu(mainMenu, "Modifier un Gang", "Configuration")
local editPermissionsMenu = RageUI.CreateSubMenu(editMenu, "Modifier les Permissions", "Grades minimum requis")
local gradesMenu = RageUI.CreateSubMenu(createMenu, "Gestion des Grades", "Liste des grades")
local vehiclesMenu = RageUI.CreateSubMenu(createMenu, "Gestion des Vehicules", "Liste des vehicules")
local permissionsMenu = RageUI.CreateSubMenu(createMenu, "Gestion des Permissions", "Grades minimum requis")
local editGradesMenu = RageUI.CreateSubMenu(editMenu, "Gestion des Grades", "Liste des grades")
local editVehiclesMenu = RageUI.CreateSubMenu(editMenu, "Gestion des Vehicules", "Liste des vehicules")

local selectedGang = nil

-- Appliquer le thème rouge transparent à tous les menus
local allMenus = {mainMenu, createMenu, editMenu, editPermissionsMenu, gradesMenu, vehiclesMenu, permissionsMenu, editGradesMenu, editVehiclesMenu}
for _, m in ipairs(allMenus) do
    m:SetRectangleBanner(Config.MenuColor.r, Config.MenuColor.g, Config.MenuColor.b, Config.MenuColor.a)
end

mainMenu.Closed = function() open = false end

local gangName = ""
local gangLabel = ""
local tempGrades = {
    {grade = 0, name = 'recruit', label = 'Recrue', salary = 0},
    {grade = 1, name = 'member', label = 'Membre', salary = 0},
    {grade = 2, name = 'boss', label = 'Chef', salary = 0}
}
local tempVehicles = {}
local tempPermissions = {
    cloakroom = 0,
    garage = 0,
    stash = 0,
    boss = 2
}
local tempColorIndex = 1
local tempBlipEnabled = false
local tempBlipVisIndex = 1
local tempMarkerIndex = 1
local tempPoints = {}

-- Pre-calculate labels for RageUI.List
local ColorLabels = {}
for _, c in ipairs(Config.GangColors) do table.insert(ColorLabels, c.label) end

local BlipVisLabels = {}
for _, v in ipairs(Config.BlipVisibility) do table.insert(BlipVisLabels, v.label) end

local MarkerLabels = {}
for _, m in ipairs(Config.MarkerList) do table.insert(MarkerLabels, m.label) end

function OpenBuilderMenu()
    if open then 
        open = false 
        RageUI.CloseAll()
        return 
    end
    open = true
    RageUI.Visible(mainMenu, true)

    ESX.TriggerServerCallback('md_gangbuilder:getGangs', function(cb)
        Gangs = cb
    end)
end

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if open then
            if not RageUI.Visible(mainMenu) and 
               not RageUI.Visible(createMenu) and 
               not RageUI.Visible(editMenu) and 
               not RageUI.Visible(editPermissionsMenu) and 
               not RageUI.Visible(gradesMenu) and 
               not RageUI.Visible(vehiclesMenu) and 
               not RageUI.Visible(permissionsMenu) and 
               not RageUI.Visible(editGradesMenu) and 
               not RageUI.Visible(editVehiclesMenu) then
                open = false
            end

            RageUI.IsVisible(mainMenu, true, true, true, function()
                RageUI.Button("Creer un nouveau gang", nil, {RightLabel = "~r~Exécuter ~s~>"}, true, {}, createMenu)
                
                RageUI.Separator("--- Gangs Existants ---")
                for name, data in pairs(Gangs) do
                    RageUI.Button(data.label, "ID: " .. name, {RightLabel = "~r~Exécuter ~s~>"}, true, {
                        onSelected = function()
                            selectedGang = name
                        end
                    }, editMenu)
                end
            end)

            RageUI.IsVisible(createMenu, true, true, true, function()
                RageUI.Button("Nom technique (ex: ballas)", "Sera utilise pour le job (Pas d'espaces/majuscules)", {RightLabel = (gangName ~= "" and gangName or "Non défini")}, true, {
                    onSelected = function()
                        local result = KeyboardInput("Nom technique", "", 20)
                        if result and result ~= "" then 
                            gangName = result:lower():gsub("%s+", "") 
                        end
                    end
                })
                RageUI.Button("Nom d'affichage (ex: The Ballas)", "Nom visible par les joueurs", {RightLabel = (gangLabel ~= "" and gangLabel or "Non défini")}, true, {
                    onSelected = function()
                        local result = KeyboardInput("Nom d'affichage", "", 20)
                        if result and result ~= "" then 
                            gangLabel = result
                        end
                    end
                })

                RageUI.Button("Configurer les Grades", "Ajouter des ranks personnalises", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, gradesMenu)
                RageUI.Button("Configurer les Vehicules", "Liste des vehicules autorises", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, vehiclesMenu)
                RageUI.Button("Configurer les Permissions", "Grades requis pour chaque point", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, permissionsMenu)

                RageUI.Separator("--- Apparence ---")
                RageUI.List("Couleur Principale", ColorLabels, tempColorIndex, "Utilisez les fleches pour changer la couleur", {}, true, function(Hovered, Selected, SelectedAction, Index)
                end, function(Index, Item)
                    tempColorIndex = Index
                end)

                RageUI.Separator("--- Blips ---")
                RageUI.Button("Activer Blips", "Affiche les points du gang sur la map", {RightLabel = tempBlipEnabled and "~g~OUI" or "~r~NON"}, true, {
                    onSelected = function()
                        tempBlipEnabled = not tempBlipEnabled
                    end
                })
                if tempBlipEnabled then
                    RageUI.List("Visibilité Blips", BlipVisLabels, tempBlipVisIndex, "Qui peut voir les blips du gang", {}, true, function(Hovered, Selected, SelectedAction, Index)
                    end, function(Index, Item)
                        tempBlipVisIndex = Index
                    end)
                end

                RageUI.Separator("--- Markers ---")
                RageUI.List("Style des markers", MarkerLabels, tempMarkerIndex, "Apparence visuelle des points au sol", {}, true, function(Hovered, Selected, SelectedAction, Index)
                end, function(Index, Item)
                    tempMarkerIndex = Index
                end)

                RageUI.Separator("---")
                local canValidate = (gangName ~= "" and gangLabel ~= "" and #tempGrades > 0)

                RageUI.Button("~g~Valider la creation", "Vous configurerez les points ensuite", {RightLabel = "~r~Exécuter ~s~>"}, canValidate, {
                    onSelected = function()
                        local selColor = Config.GangColors[tempColorIndex]
                        local selVis = Config.BlipVisibility[tempBlipVisIndex]
                        TriggerServerEvent('md_gangbuilder:createGang', {
                            name = gangName, 
                            label = gangLabel, 
                            grades = tempGrades, 
                            vehicles = tempVehicles,
                            permissions = tempPermissions,
                            color = selColor.id,
                            blip_enabled = tempBlipEnabled,
                            blip_visibility = selVis.value,
                            marker_type = Config.MarkerList[tempMarkerIndex].id
                        })
                        gangName, gangLabel = "", ""
                        tempGrades = {
                            {grade = 0, name = 'recruit', label = 'Recrue', salary = 0},
                            {grade = 1, name = 'member', label = 'Membre', salary = 0},
                            {grade = 2, name = 'boss', label = 'Chef', salary = 0}
                        }
                        tempVehicles = {}
                        tempPermissions = {cloakroom = 0, garage = 0, stash = 0, boss = 2}
                        tempColorIndex = 1
                        tempBlipEnabled = false
                        tempBlipVisIndex = 1
                        tempMarkerIndex = 1
                        -- Close the builder menu entirely
                        open = false
                        RageUI.CloseAll()
                    end
                })
            end)

            -- Permissions Management
            RageUI.IsVisible(permissionsMenu, true, true, true, function()
                for k, label in pairs(Config.PointsLabels) do
                    RageUI.Button("Minimum Grade: " .. label, "Grade minimum pour accéder à ce point", {RightLabel = tempPermissions[k]}, true, {
                        onSelected = function()
                            local gNum = KeyboardInput("Grade minimum (ex: 1)", tostring(tempPermissions[k]), 2)
                            if gNum and tonumber(gNum) then
                                tempPermissions[k] = tonumber(gNum)
                            end
                        end
                    })
                end
            end)

            -- Grades Management
            RageUI.IsVisible(gradesMenu, true, true, true, function()
                RageUI.Button("~g~Ajouter un Grade", nil, {RightLabel = "+"}, true, {
                    onSelected = function()
                        local gNum = KeyboardInput("Numéro du grade (ex: 3)", "", 2)
                        local gName = KeyboardInput("Nom technique (ex: lieutenant)", "", 20)
                        local gLabel = KeyboardInput("Label d'affichage (ex: Lieutenant)", "", 20)
                        
                        if gNum and gName and gLabel then
                            table.insert(tempGrades, {grade = tonumber(gNum), name = gName, label = gLabel, salary = 0})
                        end
                    end
                })

                RageUI.Separator("--- Liste des Grades ---")
                for i, v in ipairs(tempGrades) do
                    RageUI.Button("[" .. v.grade .. "] " .. v.label, "Technique: " .. v.name, {RightLabel = "~r~Supprimer"}, true, {
                        onSelected = function()
                            table.remove(tempGrades, i)
                        end
                    })
                end
            end)

            -- Vehicles Management
            RageUI.IsVisible(vehiclesMenu, true, true, true, function()
                RageUI.Button("~g~Ajouter un Véhicule", nil, {RightLabel = "+"}, true, {
                    onSelected = function()
                        local vName = KeyboardInput("Modèle du véhicule (ex: sultan)", "", 20)
                        if vName then
                            table.insert(tempVehicles, vName)
                        end
                    end
                })

                RageUI.Separator("--- Liste des Véhicules ---")
                for i, v in ipairs(tempVehicles) do
                    RageUI.Button(v, nil, {RightLabel = "~r~Supprimer"}, true, {
                        onSelected = function()
                            table.remove(tempVehicles, i)
                        end
                    })
                end
            end)

            RageUI.IsVisible(editMenu, true, true, true, function()
                if not selectedGang or not Gangs[selectedGang] then return end
                local g = Gangs[selectedGang]

                RageUI.Button("Gestion des Grades", "Ajouter, modifier ou supprimer des grades", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, editGradesMenu)
                RageUI.Button("Gestion des Véhicules", "Ajouter ou supprimer des véhicules", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, editVehiclesMenu)
                RageUI.Button("Modifier les Permissions", "Grades requis pour chaque point", {RightLabel = "~r~Exécuter ~s~>"}, true, {}, editPermissionsMenu)

                RageUI.Separator("--- Apparence ---")
                local tempEditColorIdx = 1
                for i, c in ipairs(Config.GangColors) do
                    if c.id == (g.color or 0) then tempEditColorIdx = i break end
                end

                RageUI.List("Couleur", ColorLabels, tempEditColorIdx, "Changer la couleur principale", {}, true, function(Hovered, Selected, Chosen, Index)
                end, function(Index, Item)
                    tempEditColorIdx = Index
                    TriggerServerEvent('md_gangbuilder:updateColor', selectedGang, Config.GangColors[Index].id)
                end)

                RageUI.Separator("--- Blips ---")
                local currentBlipLabel = "Inconnu"
                for _, v in ipairs(Config.BlipVisibility) do
                    if v.value == g.blip_visibility then
                        currentBlipLabel = v.label
                        break
                    end
                end

                RageUI.Button("Blips: " .. (g.blip_enabled and "~g~Actifs" or "~r~Inactifs"), "Cliquez pour activer/désactiver les blips", {RightLabel = g.blip_enabled and "~g~OUI" or "~r~NON"}, true, {
                    onSelected = function()
                        TriggerServerEvent('md_gangbuilder:updateBlip', selectedGang, not g.blip_enabled, g.blip_visibility)
                    end
                })

                if g.blip_enabled then
                    local tempEditBlipIdx = 1
                    for i, v in ipairs(Config.BlipVisibility) do
                        if v.value == g.blip_visibility then tempEditBlipIdx = i break end
                    end

                    RageUI.List("Visibilité Blips", BlipVisLabels, tempEditBlipIdx, "Qui peut voir les blips", {}, true, function(Hovered, Selected, Chosen, Index)
                    end, function(Index, Item)
                        tempEditBlipIdx = Index
                        TriggerServerEvent('md_gangbuilder:updateBlip', selectedGang, g.blip_enabled, Config.BlipVisibility[Index].value)
                    end)
                end

                RageUI.Separator("--- Markers ---")
                local tempEditMarkerIdx = 1
                for i, m in ipairs(Config.MarkerList) do
                    if m.id == (g.marker_type or 1) then tempEditMarkerIdx = i break end
                end

                RageUI.List("Style Marker", MarkerLabels, tempEditMarkerIdx, "Changer l'apparence des points", {}, true, function(Hovered, Selected, Chosen, Index)
                end, function(Index, Item)
                    tempEditMarkerIdx = Index
                    TriggerServerEvent('md_gangbuilder:updateMarkerType', selectedGang, Config.MarkerList[Index].id)
                end)
                RageUI.Separator("--- Points Geographiques ---")
                for k, label in pairs(Config.PointsLabels) do
                    RageUI.Button("Definir " .. label, "Place le point a votre position actuelle", {RightLabel = g[k] and "~g~Defini" or "~r~Non defini"}, true, {
                        onSelected = function()
                            local ped = PlayerPedId()
                            local vec = GetEntityCoords(ped)
                            local heading = GetEntityHeading(ped)
                            local coords = {x = vec.x, y = vec.y, z = vec.z, w = heading}
                            TriggerServerEvent('md_gangbuilder:setPoint', selectedGang, k, coords)
                        end
                    })
                end

                RageUI.Separator("--- Zone Dangereuse ---")
                RageUI.Button("~r~Supprimer le Gang", "~r~Cette action est irreversible", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        local confirm = KeyboardInput("Tapez le nom du gang pour confirmer", "", 30)
                        if confirm and confirm == selectedGang then
                            TriggerServerEvent('md_gangbuilder:deleteGang', selectedGang)
                            selectedGang = nil
                            RageUI.GoBack()
                        else
                            ESX.ShowNotification("~r~Nom incorrect, suppression annulée")
                        end
                    end
                })
            end)

            RageUI.IsVisible(editGradesMenu, true, true, true, function()
                if not selectedGang or not Gangs[selectedGang] then return end
                local g = Gangs[selectedGang]
                local grades = g.grades or {}

                RageUI.Button("~g~Ajouter un Grade", nil, {RightLabel = "+"}, true, {
                    onSelected = function()
                        local gNum = KeyboardInput("Numéro du grade (ex: 3)", "", 2)
                        local gName = KeyboardInput("Nom technique (ex: lieutenant)", "", 20)
                        local gLabel = KeyboardInput("Label d'affichage (ex: Lieutenant)", "", 20)
                        
                        if gNum and gName and gLabel then
                            table.insert(grades, {grade = tonumber(gNum), name = gName, label = gLabel, salary = 0})
                            TriggerServerEvent('md_gangbuilder:updateGrades', selectedGang, grades)
                        end
                    end
                })

                RageUI.Separator("--- Liste des Grades ---")
                for i, v in ipairs(grades) do
                    RageUI.Button("[" .. v.grade .. "] " .. v.label, "Cliquez pour modifier | Suppr pour supprimer", {RightLabel = "~r~Supprimer"}, true, {
                        onSelected = function()
                             local confirm = KeyboardInput("Modifier? (OUI pour label, SALAIRE pour salaire)", "", 10)
                             if confirm then
                                 if confirm:upper() == "OUI" then
                                     local newLabel = KeyboardInput("Nouveau Label", v.label, 20)
                                     if newLabel then v.label = newLabel end
                                 elseif confirm:upper() == "SALAIRE" then
                                     local newSalary = KeyboardInput("Nouveau Salaire", tostring(v.salary), 10)
                                     if newSalary and tonumber(newSalary) then v.salary = tonumber(newSalary) end
                                 elseif confirm:upper() == "SUPPRIMER" then
                                     table.remove(grades, i)
                                 end
                                 TriggerServerEvent('md_gangbuilder:updateGrades', selectedGang, grades)
                             end
                        end
                    })
                end
            end)

            RageUI.IsVisible(editVehiclesMenu, true, true, true, function()
                if not selectedGang or not Gangs[selectedGang] then return end
                local g = Gangs[selectedGang]
                local vehicles = g.vehicles or {}

                RageUI.Button("~g~Ajouter un Véhicule", nil, {RightLabel = "+"}, true, {
                    onSelected = function()
                        local vName = KeyboardInput("Modèle du véhicule (ex: sultan)", "", 20)
                        if vName then
                            table.insert(vehicles, vName)
                            TriggerServerEvent('md_gangbuilder:updateVehicles', selectedGang, vehicles)
                        end
                    end
                })

                RageUI.Separator("--- Liste des Véhicules ---")
                for i, v in ipairs(vehicles) do
                    RageUI.Button(v, nil, {RightLabel = "~r~Supprimer"}, true, {
                        onSelected = function()
                            table.remove(vehicles, i)
                            TriggerServerEvent('md_gangbuilder:updateVehicles', selectedGang, vehicles)
                        end
                    })
                end
            end)

            RageUI.IsVisible(editPermissionsMenu, true, true, true, function()
                if not selectedGang or not Gangs[selectedGang] then return end
                local g = Gangs[selectedGang]
                local perms = g.permissions or {cloakroom = 0, garage = 0, stash = 0, boss = 2}

                for k, label in pairs(Config.PointsLabels) do
                    RageUI.Button("Minimum Grade: " .. label, "Grade minimum pour accéder à ce point", {RightLabel = perms[k]}, true, {
                        onSelected = function()
                            local gNum = KeyboardInput("Grade minimum (ex: 1)", tostring(perms[k]), 2)
                            if gNum and tonumber(gNum) then
                                perms[k] = tonumber(gNum)
                                TriggerServerEvent('md_gangbuilder:updatePermissions', selectedGang, perms)
                            end
                        end
                    })
                end
            end)
        end
    end
end)

-- Keyboard input helper
function KeyboardInput(TextEntry, ExampleText, MaxStringLength)
	AddTextEntry('FMMC_KEY_TIP1', TextEntry)
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

RegisterNetEvent('md_gangbuilder:updateGangs')
AddEventHandler('md_gangbuilder:updateGangs', function(updatedGangs)
    Gangs = updatedGangs
end)

RegisterNetEvent('md_gangbuilder:openBuilder')
AddEventHandler('md_gangbuilder:openBuilder', function()
    OpenBuilderMenu()
end)

-- Post-creation point setup menu
local setupMenu = RageUI.CreateMenu("Configuration", "Definir les points du gang")
local setupOpen = false
local setupGang = nil

setupMenu:SetRectangleBanner(Config.MenuColor.r, Config.MenuColor.g, Config.MenuColor.b, Config.MenuColor.a)
setupMenu.Closed = function() setupOpen = false end

RegisterNetEvent('md_gangbuilder:openPointSetup')
AddEventHandler('md_gangbuilder:openPointSetup', function(gangName)
    if setupOpen then return end
    setupGang = gangName
    setupOpen = true
    RageUI.Visible(setupMenu, true)

    Citizen.CreateThread(function()
        while setupOpen do
            Wait(0)
            RageUI.IsVisible(setupMenu, true, true, true, function()
                if not setupGang or not Gangs[setupGang] then return end

                RageUI.Separator("~g~Gang cree ! Placez les points")

                for k, label in pairs(Config.PointsLabels) do
                    local isSet = Gangs[setupGang][k] and true or false
                    RageUI.Button("Definir " .. label, "Se placer puis cliquer", {RightLabel = isSet and "~g~Defini" or "~r~Non defini"}, true, {
                        onSelected = function()
                            local ped = PlayerPedId()
                            local vec = GetEntityCoords(ped)
                            local heading = GetEntityHeading(ped)
                            local coords = {x = vec.x, y = vec.y, z = vec.z, w = heading}
                            TriggerServerEvent('md_gangbuilder:setPoint', setupGang, k, coords)
                            ESX.ShowNotification("~g~" .. label .. " défini !")
                        end
                    })
                end

                RageUI.Separator("---")
                RageUI.Button("~g~Terminer", "Vous pourrez modifier les points plus tard", {RightLabel = "~r~Exécuter ~s~>"}, true, {
                    onSelected = function()
                        setupOpen = false
                        RageUI.Visible(setupMenu, false)
                        ESX.ShowNotification("~g~Configuration terminée !")
                    end
                })
            end)
        end
    end)
end)
