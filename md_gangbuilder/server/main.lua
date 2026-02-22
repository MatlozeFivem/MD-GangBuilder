ESX = exports["es_extended"]:getSharedObject()

local Gangs = {}

local function SyncGangsWithESX()
    print("[md_gangbuilder] Starting Sync with ESX database...")
    for name, data in pairs(Gangs) do
        -- 1. Preparation: Handle legacy data (Synchronous)
        local needsUpdate = false
        local formattedGrades = {}
        for k, v in pairs(data.grades) do
            local gradeNum = tonumber(v.grade)
            if not gradeNum then
                if k == 'recruit' then gradeNum = 0
                elseif k == 'member' then gradeNum = 1
                elseif k == 'boss' then gradeNum = 2
                else gradeNum = tonumber(k) or 0 end
                v.grade = gradeNum
                v.name = v.name or k
                v.salary = v.salary or 0
                needsUpdate = true
            end
            table.insert(formattedGrades, v)
        end

        if needsUpdate then
            data.grades = formattedGrades
            MySQL.update.await('UPDATE md_gangs SET grades = ? WHERE name = ?', {json.encode(data.grades), name})
            print(("[md_gangbuilder] Data migration: Corrected grades for gang %s"):format(name))
        end

        -- 2. Database Sync (Using await for absolute certainty)
        local jobExists = MySQL.scalar.await('SELECT name FROM jobs WHERE name = ?', {name})
        if not jobExists then
            print(("[md_gangbuilder] Sync: Creating ESX job %s"):format(name))
            MySQL.insert.await('INSERT INTO jobs (name, label) VALUES (?, ?)', {name, data.label})
        end
        
        for _, v in pairs(data.grades) do
            local gradeNum = tonumber(v.grade) or 0
            local gradeExists = MySQL.scalar.await('SELECT id FROM job_grades WHERE job_name = ? AND grade = ?', {name, gradeNum})
            if not gradeExists then
                print(("[md_gangbuilder] Sync: Adding ESX grade %s for job %s"):format(gradeNum, name))
                MySQL.insert.await('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                    name, gradeNum, v.name or 'recruit', v.label or 'Recrue', v.salary or 0, '{}', '{}'
                })
            end
        end
    end

    -- 3. Force ESX to Refresh its internal cache from the database we just filled
    if ESX.RefreshJobs then
        ESX.RefreshJobs()
        print("[md_gangbuilder] ESX Jobs have been refreshed successfully.")
    else
        print("[md_gangbuilder] WARNING: ESX.RefreshJobs() not found. Please restart the server or use /refreshjobs.")
    end
end

local function SendToDiscord(gangName, title, message)
    local webhook = (Config.Webhooks and Config.Webhooks[gangName]) or nil
    
    if not webhook or webhook == "" then return end

    local embed = {
        {
            ["color"] = 16711680,
            ["title"] = "**"..title.."**",
            ["description"] = message,
            ["footer"] = {
                ["text"] = "MD Gang Builder - " .. os.date("%d/%m/%Y [%H:%M:%S]"),
            },
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({username = "MD GangBuilder", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Log stash opening
AddEventHandler('ox_inventory:onInventoryOpen', function(source, inventory)
    if inventory and inventory.type == 'stash' then
        local gangName = string.gsub(inventory.id, '_stash', '')
        if Gangs[gangName] then
            local xPlayer = ESX.GetPlayerFromId(source)
            if xPlayer then
                SendToDiscord(gangName, "Coffre", ("Le joueur **%s** a ouvert le coffre du gang."):format(xPlayer.getName()))
            end
        end
    end
end)

-- Load gangs on startup (SYNCHRONOUS to ensure jobs exist before players connect)
CreateThread(function()
    -- Wait for MySQL to be ready
    MySQL.ready.await()
    
    local results = MySQL.query.await('SELECT * FROM md_gangs', {})
    if results then
        for i=1, #results do
            local row = results[i]
            print(("[md_gangbuilder] Loading gang: %s"):format(row.name))
            Gangs[row.name] = {
                label = row.label,
                grades = json.decode(row.grades),
                cloakroom = row.cloakroom and json.decode(row.cloakroom) or nil,
                garage_spawn = row.garage_spawn and json.decode(row.garage_spawn) or (row.garage and json.decode(row.garage) or nil),
                garage_store = row.garage_store and json.decode(row.garage_store) or (row.garage and json.decode(row.garage) or nil),
                stash = row.stash and json.decode(row.stash) or nil,
                boss = row.boss and json.decode(row.boss) or nil,
                vehicles = row.vehicles and json.decode(row.vehicles) or {},
                permissions = row.permissions and json.decode(row.permissions) or {cloakroom = 0, garage_spawn = 0, garage_store = 0, stash = 0, boss = 2},
                webhook = row.webhook,
                color = row.color or 0,
                blip_enabled = (row.blip_enabled and row.blip_enabled == 1) and true or false,
                blip_visibility = row.blip_visibility or 'members',
                marker_type = row.marker_type or Config.MarkerType or 1,
                outfits = row.outfits and json.decode(row.outfits) or {}
            }

            -- Register stash with ox_inventory
            exports.ox_inventory:RegisterStash(row.name .. '_stash', row.label, 50, 100000)
        end
        print(("[md_gangbuilder] Loaded %d gangs from database"):format(#results))
    end
    
    -- Sync BEFORE any player can load — this is critical for job2 persistence
    SyncGangsWithESX()
    print("[md_gangbuilder] Gang jobs are now available in ESX. Players can connect safely.")
    
    -- Create md_gang_members table if not exists
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `md_gang_members` (
            `identifier` VARCHAR(60) NOT NULL PRIMARY KEY,
            `gang` VARCHAR(50) NOT NULL,
            `grade` INT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- Auto-add new columns to existing md_gangs table
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `color` INT DEFAULT 0") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `blip_enabled` TINYINT DEFAULT 0") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `blip_visibility` VARCHAR(20) DEFAULT 'members'") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `outfits` LONGTEXT DEFAULT NULL") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `garage_spawn` LONGTEXT DEFAULT NULL") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `garage_store` LONGTEXT DEFAULT NULL") end)
    pcall(function() MySQL.query.await("ALTER TABLE md_gangs ADD COLUMN `marker_type` INT DEFAULT 1") end)

    print("[md_gangbuilder] Database ready.")
end)

-- Track gang membership: when job2 changes, save to our own table
AddEventHandler('esx:setJob2', function(playerId, job2, lastJob2)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.getIdentifier()
    
    -- Check if this job2 is a gang (check DB, not just in-memory Gangs table)
    local isGang = MySQL.scalar.await('SELECT name FROM md_gangs WHERE name = ?', {job2.name})
    
    if isGang then
        -- Player joined a gang → save membership
        MySQL.insert('INSERT INTO md_gang_members (identifier, gang, grade) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE gang = VALUES(gang), grade = VALUES(grade)', {
            identifier, job2.name, job2.grade
        })
        print(("[md_gangbuilder] ✓ Saved membership: %s → %s (grade %s)"):format(xPlayer.getName(), job2.name, job2.grade))
    else
        -- Player set to non-gang job → remove membership if they had one
        MySQL.query('DELETE FROM md_gang_members WHERE identifier = ?', {identifier})
    end
end)

-- Restore gang membership on player load
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
    Wait(3000) -- Wait for SyncGangsWithESX to finish
    
    local identifier = xPlayer.getIdentifier()
    local result = MySQL.query.await('SELECT gang, grade FROM md_gang_members WHERE identifier = ?', {identifier})
    
    if result and result[1] then
        local savedGang = result[1].gang
        local savedGrade = tostring(result[1].grade)
        local currentJob2 = xPlayer.getJob2()
        
        print(("[md_gangbuilder] Player %s loaded. Current job2: %s, Saved gang: %s"):format(xPlayer.getName(), currentJob2.name, savedGang))
        
        if currentJob2.name ~= savedGang and ESX.DoesJobExist(savedGang, savedGrade) then
            xPlayer.setJob2(savedGang, tonumber(savedGrade) or 0)
            print(("[md_gangbuilder] ✓ Restored job2 '%s' (grade %s) for %s"):format(savedGang, savedGrade, xPlayer.getName()))
        end
    else
        print(("[md_gangbuilder] Player %s has no saved gang membership."):format(xPlayer.getName()))
    end
end)

-- Debug command to see ESX Jobs
ESX.RegisterCommand('debugjobs', 'admin', function(xPlayer, args, showError)
    local jobName = args.job or xPlayer.getJob().name
    if ESX.Jobs[jobName] then
        print(("[md_gangbuilder] DEBUG: Content of ESX.Jobs[%s]"):format(jobName))
        for k, v in pairs(ESX.Jobs[jobName].grades) do
            print(("- Grade %s: %s (%s)"):format(k, v.label, v.name))
        end
        if xPlayer then xPlayer.showNotification("~g~Debug infos envoyées dans la console serveur.") end
    else
        print(("[md_gangbuilder] DEBUG: ESX.Jobs[%s] does not exist!"):format(jobName))
    end
end, true, {
    help = "Vérifier le cache des jobs ESX",
    arguments = {
        {name = 'job', help = "Nom du job à vérifier", type = 'string'}
    }
})

-- Create gang
RegisterNetEvent('md_gangbuilder:createGang')
AddEventHandler('md_gangbuilder:createGang', function(data)
    local _source = source -- Capture source before async callback
    local xPlayer = ESX.GetPlayerFromId(_source)
    local group = xPlayer.getGroup()
    print(("[md_gangbuilder] createGang attempt by %s (Group: %s)"):format(xPlayer.getName(), group))

    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then 
        print("[md_gangbuilder] createGang DENIED: Insufficient permissions")
        return 
    end

    if Gangs[data.name] then
        xPlayer.showNotification("Ce nom de gang existe déjà")
        return
    end

    local customGrades = data.grades
    local customVehicles = data.vehicles or {}
    local customPermissions = data.permissions or {cloakroom = 0, garage_spawn = 0, garage_store = 0, stash = 0, boss = 2}
    local customWebhook = data.webhook or ""
    local customColor = data.color or 0
    local customBlipEnabled = data.blip_enabled and 1 or 0
    local customBlipVisibility = data.blip_visibility or 'members'
    local customMarkerType = data.marker_type or 1

    MySQL.insert('INSERT INTO md_gangs (name, label, grades, vehicles, permissions, webhook, color, blip_enabled, blip_visibility, marker_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name, data.label, json.encode(customGrades), json.encode(customVehicles), json.encode(customPermissions), customWebhook, customColor, customBlipEnabled, customBlipVisibility, customMarkerType
    }, function(id)
        if id then
            Gangs[data.name] = {
                label = data.label,
                grades = customGrades,
                vehicles = customVehicles,
                permissions = customPermissions,
                webhook = customWebhook,
                color = customColor,
                blip_enabled = data.blip_enabled or false,
                blip_visibility = customBlipVisibility,
                marker_type = customMarkerType,
                outfits = {}
            }

            -- Integrate with ESX Jobs
            MySQL.insert('INSERT INTO jobs (name, label) VALUES (?, ?)', {data.name, data.label})
            for k, v in pairs(customGrades) do
                MySQL.insert('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                    data.name, v.grade, v.name, v.label, v.salary or 0, '{}', '{}'
                })
            end

            -- Refresh ESX Job Cache from database
            ESX.RefreshJobs()
            print(("[md_gangbuilder] Gang '%s' created"):format(data.name))

            -- Register stash for new gang
            exports.ox_inventory:RegisterStash(data.name .. '_stash', data.label, 50, 100000)
            xPlayer.showNotification(("Gang %s créé avec succès"):format(data.label))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
            -- Open point setup menu on creator's client
            TriggerClientEvent('md_gangbuilder:openPointSetup', _source, data.name)
        end
    end)
end)

-- Set point
RegisterNetEvent('md_gangbuilder:setPoint')
AddEventHandler('md_gangbuilder:setPoint', function(gangName, pointType, coords)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()

    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    -- Ensure coords is a proper table
    local saveCoords = {x = coords.x, y = coords.y, z = coords.z, w = coords.w}
    print(("[md_gangbuilder] setPoint: %s -> %s = %s"):format(gangName, pointType, json.encode(saveCoords)))

    MySQL.update(('UPDATE md_gangs SET %s = ? WHERE name = ?'):format(pointType), {
        json.encode(saveCoords), gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName][pointType] = saveCoords
            xPlayer.showNotification(("Point %s défini pour le gang %s"):format(pointType, gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Delete Gang
RegisterNetEvent('md_gangbuilder:deleteGang')
AddEventHandler('md_gangbuilder:deleteGang', function(gangName)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('DELETE FROM md_gangs WHERE name = ?', {gangName}, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName] = nil
            xPlayer.showNotification(("~g~Gang %s supprimé avec succès"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Update Webhook
RegisterNetEvent('md_gangbuilder:updateWebhook')
AddEventHandler('md_gangbuilder:updateWebhook', function(gangName, webhook)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('UPDATE md_gangs SET webhook = ? WHERE name = ?', {
        webhook, gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].webhook = webhook
            xPlayer.showNotification(("Webhook mis à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Update Permissions
RegisterNetEvent('md_gangbuilder:updatePermissions')
AddEventHandler('md_gangbuilder:updatePermissions', function(gangName, permissions)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('UPDATE md_gangs SET permissions = ? WHERE name = ?', {
        json.encode(permissions), gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].permissions = permissions
            xPlayer.showNotification(("Permissions mises à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Update Color
RegisterNetEvent('md_gangbuilder:updateColor')
AddEventHandler('md_gangbuilder:updateColor', function(gangName, colorId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('UPDATE md_gangs SET color = ? WHERE name = ?', {
        colorId, gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].color = colorId
            xPlayer.showNotification(("~g~Couleur mise à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Update Grades
RegisterNetEvent('md_gangbuilder:updateGrades')
AddEventHandler('md_gangbuilder:updateGrades', function(gangName, grades)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    -- Update database
    MySQL.update('UPDATE md_gangs SET grades = ? WHERE name = ?', {
        json.encode(grades), gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].grades = grades
            
            -- Sync with ESX: clear old grades first to handle deletions/renames
            MySQL.query('DELETE FROM job_grades WHERE job_name = ?', {gangName}, function()
                -- Now re-sync (this will recreate everything properly)
                SyncGangsWithESX()
                xPlayer.showNotification(("Grades mis à jour pour %s"):format(gangName))
                TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
            end)
        end
    end)
end)

-- Update Vehicles
RegisterNetEvent('md_gangbuilder:updateVehicles')
AddEventHandler('md_gangbuilder:updateVehicles', function(gangName, vehicles)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    -- Update database
    MySQL.update('UPDATE md_gangs SET vehicles = ? WHERE name = ?', {
        json.encode(vehicles), gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].vehicles = vehicles
            xPlayer.showNotification(("Liste des véhicules mise à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)


-- Update Marker Type
RegisterNetEvent('md_gangbuilder:updateMarkerType')
AddEventHandler('md_gangbuilder:updateMarkerType', function(gangName, markerId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('UPDATE md_gangs SET marker_type = ? WHERE name = ?', {
        markerId, gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].marker_type = markerId
            xPlayer.showNotification(("~g~Type de marker mis à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Update Blip Settings
RegisterNetEvent('md_gangbuilder:updateBlip')
AddEventHandler('md_gangbuilder:updateBlip', function(gangName, enabled, visibility)
    local xPlayer = ESX.GetPlayerFromId(source)
    local group = xPlayer.getGroup()
    if group ~= 'owner' and group ~= 'superadmin' and group ~= 'admin' and group ~= 'fondateur' and group ~= 'devloppeur' then return end

    if not Gangs[gangName] then return end

    MySQL.update('UPDATE md_gangs SET blip_enabled = ?, blip_visibility = ? WHERE name = ?', {
        enabled and 1 or 0, visibility, gangName
    }, function(affectedRows)
        if affectedRows > 0 then
            Gangs[gangName].blip_enabled = enabled
            Gangs[gangName].blip_visibility = visibility
            xPlayer.showNotification(("~g~Blip mis à jour pour %s"):format(gangName))
            TriggerClientEvent('md_gangbuilder:updateGangs', -1, Gangs)
        end
    end)
end)

-- Request Identity Card
RegisterNetEvent('md_gangbuilder:requestIdCard')
AddEventHandler('md_gangbuilder:requestIdCard', function(target)
    local xTarget = ESX.GetPlayerFromId(target)
    if xTarget then
        MySQL.query('SELECT firstname, lastname, dateofbirth, sex FROM users WHERE identifier = ?', {
            xTarget.identifier
        }, function(result)
            if result[1] and result[1].firstname then
                TriggerClientEvent('md_gangbuilder:showIDCard', source, result[1])
            else
                -- Fallback if identity tables are empty
                TriggerClientEvent('md_gangbuilder:showIDCard', source, {
                    firstname = xTarget.getName(),
                    lastname = "",
                    dateofbirth = "Inconnu",
                    sex = "Inconnu"
                })
            end
        end)
    end
end)

-- Search Player
RegisterNetEvent('md_gangbuilder:searchPlayer')
AddEventHandler('md_gangbuilder:searchPlayer', function(target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)

    if not xPlayer or not xTarget then return end

    -- Check if they are in the same gang or if they have permission
    -- For now, let's keep it simple as it's an F7 menu action for gang members
    exports.ox_inventory:forceOpenInventory(source, 'player', target)
end)

-- Boss actions (recruit/fire)
RegisterNetEvent('md_gangbuilder:bossAction')
AddEventHandler('md_gangbuilder:bossAction', function(type, target)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(target)

    if not xPlayer or not xTarget then return end
    local jobName = xPlayer.job2.name
    local playerGrade = xPlayer.job2.grade
    if not Gangs[jobName] or not Gangs[jobName].permissions then return end
    
    local minBossGrade = tonumber(Gangs[jobName].permissions.boss) or 2
    if playerGrade < minBossGrade then return end

    if type == 'recruit' then
        xTarget.setJob2(xPlayer.job2.name, 0)
        xPlayer.showNotification(("Vous avez recruté %s"):format(xTarget.getName()))
        xTarget.showNotification(("Vous avez été recruté par %s"):format(xPlayer.job2.label))
        SendToDiscord(xPlayer.job2.name, "Recrutement", ("Le joueur **%s** a été recruté par **%s**."):format(xTarget.getName(), xPlayer.getName()))
    elseif type == 'fire' then
        if xTarget.job2.name == xPlayer.job2.name then
            xTarget.setJob2('unemployed', 0)
            xPlayer.showNotification(("Vous avez viré %s"):format(xTarget.getName()))
            xTarget.showNotification(("Vous avez été viré de %s"):format(xPlayer.job2.label))
            SendToDiscord(xPlayer.job2.name, "Licenciement", ("Le joueur **%s** a été viré par **%s**."):format(xTarget.getName(), xPlayer.getName()))
        else
            xPlayer.showNotification("Ce joueur n'est pas dans votre gang")
        end
    end
end)

-- Get all members of a gang (offline included)
ESX.RegisterServerCallback('md_gangbuilder:getMembers', function(source, cb, gangName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb({}) return end
    
    local jobName = xPlayer.job2.name
    local playerGrade = xPlayer.job2.grade
    
    if not Gangs[gangName] or xPlayer.job2.name ~= gangName then
        cb({})
        return
    end

    local minBossGrade = tonumber(Gangs[gangName].permissions and Gangs[gangName].permissions.boss) or 2
    if playerGrade < minBossGrade then
        cb({})
        return
    end

    MySQL.query('SELECT identifier, firstname, lastname, job2_grade FROM users WHERE job2 = ?', {gangName}, function(results)
        local members = {}
        local processed = {}

        -- Add DB results
        for i=1, #results do
            local identifier = results[i].identifier
            processed[identifier] = true
            table.insert(members, {
                identifier = identifier,
                name = (results[i].firstname or "Inconnu") .. " " .. (results[i].lastname or ""),
                grade = results[i].job2_grade
            })
        end

        -- Add online players that might not be in DB yet
        local xPlayers = ESX.GetExtendedPlayers('job2', gangName)
        for _, xTarget in ipairs(xPlayers) do
            if not processed[xTarget.identifier] then
                table.insert(members, {
                    identifier = xTarget.identifier,
                    name = xTarget.getName(),
                    grade = xTarget.job2.grade
                })
                processed[xTarget.identifier] = true
            end
        end

        cb(members)
    end)
end)

-- Update member rank at distance
RegisterNetEvent('md_gangbuilder:updateMemberRank')
AddEventHandler('md_gangbuilder:updateMemberRank', function(gangName, targetIdentifier, newGrade)
    local xPlayer = ESX.GetPlayerFromId(source)
    local jobName = xPlayer.job2.name
    local playerGrade = xPlayer.job2.grade
    
    if not xPlayer or xPlayer.job2.name ~= gangName then return end
    
    local minBossGrade = tonumber(Gangs[gangName] and Gangs[gangName].permissions and Gangs[gangName].permissions.boss) or 2
    if playerGrade < minBossGrade then return end

    local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
    if targetPlayer then
        targetPlayer.setJob2(gangName, newGrade)
        xPlayer.showNotification("~g~Grade mis à jour (Joueur en ligne)")
    else
        MySQL.update('UPDATE users SET job2_grade = ? WHERE identifier = ?', {newGrade, targetIdentifier}, function(affectedRows)
            if affectedRows > 0 then
                xPlayer.showNotification("~g~Grade mis à jour (Joueur hors-ligne)")
            end
        end)
    end
end)

-- Fire member at distance
RegisterNetEvent('md_gangbuilder:fireMember')
AddEventHandler('md_gangbuilder:fireMember', function(gangName, targetIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    local jobName = xPlayer.job2.name
    local playerGrade = xPlayer.job2.grade
    
    if not xPlayer or xPlayer.job2.name ~= gangName then return end

    local minBossGrade = tonumber(Gangs[gangName] and Gangs[gangName].permissions and Gangs[gangName].permissions.boss) or 2
    if playerGrade < minBossGrade then return end

    local targetPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)
    if targetPlayer then
        targetPlayer.setJob2('unemployed', 0)
        xPlayer.showNotification("~g~Joueur viré (En ligne)")
    else
        MySQL.update('UPDATE users SET job2 = ?, job2_grade = ? WHERE identifier = ?', {'unemployed', 0, targetIdentifier}, function(affectedRows)
            if affectedRows > 0 then
                xPlayer.showNotification("~g~Joueur viré (Hors-ligne)")
            end
        end)
    end
end)

-- Advanced Interaction Sync
RegisterNetEvent('md_gangbuilder:escort')
AddEventHandler('md_gangbuilder:escort', function(target)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job2.name == 'unemployed' then return end
    TriggerClientEvent('md_gangbuilder:dragPlayer', target, source)
end)

RegisterNetEvent('md_gangbuilder:putInVehicle')
AddEventHandler('md_gangbuilder:putInVehicle', function(target)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job2.name == 'unemployed' then return end
    TriggerClientEvent('md_gangbuilder:putInVehicle', target)
end)

RegisterNetEvent('md_gangbuilder:outVehicle')
AddEventHandler('md_gangbuilder:outVehicle', function(target)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job2.name == 'unemployed' then return end
    TriggerClientEvent('md_gangbuilder:outVehicle', target)
end)

RegisterNetEvent('md_gangbuilder:setHood')
AddEventHandler('md_gangbuilder:setHood', function(target)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job2.name == 'unemployed' then return end
    TriggerClientEvent('md_gangbuilder:toggleHood', target)
end)

RegisterNetEvent('md_gangbuilder:hostageSync')
AddEventHandler('md_gangbuilder:hostageSync', function(target, type)
    TriggerClientEvent('md_gangbuilder:hostageSyncTarget', target, source, type)
end)

-- Get gangs for client
ESX.RegisterServerCallback('md_gangbuilder:getGangs', function(source, cb)
    cb(Gangs)
end)

-- Command to open the builder
ESX.RegisterCommand('gangbuilder', 'user', function(xPlayer, args, showError)
    local group = xPlayer.getGroup()
    print(("[md_gangbuilder] Command /gangbuilder called by %s (Group: %s)"):format(xPlayer.getName(), group))
    
    if group == 'owner' or group == 'superadmin' or group == 'admin' or group == 'fondateur' or group == 'devloppeur' then
        xPlayer.triggerEvent('md_gangbuilder:openBuilder')
    else
        xPlayer.showNotification("~r~Vous n'avez pas accès à cette commande.")
    end
end, false, {help = "Ouvrir le menu de création de gang"})
