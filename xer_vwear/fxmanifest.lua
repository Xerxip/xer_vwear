fx_version 'cerulean'
game 'gta5'

author 'You & Grok'
description 'Ultimate Modular Vehicle Wear System v3.3 (2025 Verified)'
version '3.3.0'

shared_script 'config.lua'

-- CRITICAL: main.lua MUST load FIRST so QBCore is global before any module
client_scripts {
    'client/main.lua',                    -- ← Loads first → creates global QBCore
    'client/target.lua',
    'client/modules/engine.lua',
    'client/modules/transmission.lua',
    'client/modules/brakes.lua',
    'client/modules/suspension.lua',
    'client/modules/tires.lua'            -- ← Now safely sees QBCore
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/repair.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png'
}

lua54 'yes'

dependencies {
    'qb-core',
    'oxmysql',
    'ox_target'
}