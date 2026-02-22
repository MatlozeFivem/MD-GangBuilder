fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Matloze'
version '1.0.0'



shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    '@es_extended/locale.lua',
    'locales/*.lua'
}

client_scripts {
    'lib/RMenu.lua',
    'lib/menu/RageUI.lua',
    'lib/menu/Menu.lua',
    'lib/menu/MenuController.lua',
    'lib/components/*.lua',
    'lib/menu/elements/*.lua',
    'lib/menu/items/*.lua',
    'lib/menu/panels/*.lua',
    'lib/menu/windows/*.lua',
    'client/points_menu.lua',
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'es_extended',
    'ox_inventory',
    'ox_lib'
}
