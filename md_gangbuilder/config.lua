Config = {}

Config.Locale = 'fr' -- Only French for now as requested
Config.ColorMenuA = 150 -- Transparence du fond (0 = invisible, 255 = opaque)
Config.MenuColor = {r = 150, g = 0, b = 0, a = 200} -- Couleur du bandeau (rouge foncé)

Config.MarkerType = 1
Config.MarkerSize = {x = 1.0, y = 1.0, z = 1.0}
Config.MarkerColor = {r = 255, g = 255, b = 255, a = 100}

Config.PointsLabels = {
    cloakroom = "Vestiaire",
    garage_spawn = "Garage (Sortie)",
    garage_store = "Garage (Rangement)",
    stash = "Coffre",
    boss = "Action Patron"
}

Config.F7Menu = {
    SearchTime = 5000, -- 5 seconds to search
    LockpickTime = 10000 -- 10 seconds to lockpick
}

-- Webhooks Discord par gang (un webhook par gang)
Config.Webhooks = {
     ["vagos"] = "",
}

-- Configuration des blips
Config.Blip = {
    Sprite = 84,       -- Icone du blip (84 = gang)
    Scale = 0.8,       -- Taille
    Display = 2,       -- 2 = minimap + grande map
}

-- Choix de visibilité blip
Config.BlipVisibility = {
    {label = "Personne",           value = "none"},
    {label = "Membres uniquement", value = "members"},
    {label = "Tout le monde",      value = "all"},
}

-- Couleurs principales (← / → pour défiler)
Config.GangColors = {
    {label = "Noir",          id = 0,   blipColor = 40, r = 10,  g = 10,  b = 10},
    {label = "Blanc",         id = 134, blipColor = 4,  r = 255, g = 255, b = 255},
    {label = "Rouge",         id = 27,  blipColor = 1,  r = 255, g = 0,   b = 0},
    {label = "Rouge Foncé",   id = 28,  blipColor = 76, r = 150, g = 0,   b = 0},
    {label = "Orange",        id = 38,  blipColor = 17, r = 255, g = 100, b = 0},
    {label = "Jaune",         id = 42,  blipColor = 28, r = 255, g = 210, b = 0},
    {label = "Vert",          id = 53,  blipColor = 2,  r = 0,   g = 255, b = 0},
    {label = "Vert Foncé",    id = 49,  blipColor = 25, r = 0,   g = 100, b = 0},
    {label = "Bleu",          id = 64,  blipColor = 3,  r = 0,   g = 150, b = 255},
    {label = "Bleu Foncé",    id = 141, blipColor = 54, r = 0,   g = 0,   b = 150},
    {label = "Violet",        id = 71,  blipColor = 27, r = 150, g = 0,   b = 255},
    {label = "Rose",          id = 135, blipColor = 8,  r = 255, g = 20,  b = 147},
    {label = "Marron",        id = 97,  blipColor = 21, r = 139, g = 69,  b = 19},
    {label = "Gris",          id = 4,   blipColor = 20, r = 128, g = 128, b = 128},
    {label = "Or",            id = 158, blipColor = 28, r = 218, g = 165, b = 32},
    {label = "Chrome",        id = 120, blipColor = 4,  r = 192, g = 192, b = 192},
}

-- Types de markers (Visuels au sol)
Config.MarkerList = {
    {label = "Cylindre simple",     id = 1},
    {label = "Sphère",              id = 2},
    {label = "Cône inversé",        id = 3},
    {label = "Couronne",            id = 20},
    {label = "Multi-Cylindres",     id = 21},
    {label = "Cylindre plat",       id = 23},
    {label = "Signal (Vague)",      id = 25},
    {label = "Cercle au sol",       id = 27},
    {label = "Zone au sol",         id = 28},
    {label = "Sac d'argent",        id = 29},
    {label = "V (Vertical)",        id = 30},
    {label = "X (Croix)",           id = 31},
    {label = "Flèche (Haut)",       id = 0}, -- Arrow Up is usually 0
}



-- Configuration des tenues de gang (Vestiaire)
-- Ajoutez ici les tenues pour chaque gang (le nom doit correspondre au nom du gang dans la base)
Config.Outfits = {
    ["mdev"] = {
        label = "Tenue des mdev",
        male = {
            ['tshirt_1'] = 15,  ['tshirt_2'] = 0,
            ['torso_1'] = 15,   ['torso_2'] = 0,
            ['arms'] = 15,
            ['pants_1'] = 10,   ['pants_2'] = 0,
            ['shoes_1'] = 34,   ['shoes_2'] = 0,
            ['chain_1'] = 0,    ['chain_2'] = 0,
        },
        female = {
            ['tshirt_1'] = 15,  ['tshirt_2'] = 0,
            ['torso_1'] = 15,   ['torso_2'] = 0,
            ['arms'] = 15,
            ['pants_1'] = 10,   ['pants_2'] = 0,
            ['shoes_1'] = 34,   ['shoes_2'] = 0,
            ['chain_1'] = 0,    ['chain_2'] = 0,
        }
    },
    -- Exemple pour un autre gang:
    -- ["ballas"] = {
    --     label = "Tenue des Ballas",
    --     male = { ... },
    --     female = { ... }
    -- },
}
