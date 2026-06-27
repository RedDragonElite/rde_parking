fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'rde_parking'
author      'RDE | SerpentsByte'
version     '1.1.1'
description 'Next-Gen Parking & Car Lock System — ox_core Exclusive, Proximity-Loaded'

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    '/server:7290',
    'ox_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

-- Optional: rde_nostr_log for decentralized logging
optional_dependencies {
    'rde_nostr_log',
}
