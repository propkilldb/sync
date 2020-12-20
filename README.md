# PK Sync

## Requirements

https://github.com/FredyH/GWSockets

## Install

put pksync.lua in lua/autorun/server/pksync.lua

and bromsock in lua/bin/gmsv_gwsockets_linux.dll

## Usage

runs on tcp port 27057

sync_connect 123.123.123.123

must be at least 1 player on each server

bot_zombie 1 on all servers to prevent bots glitching around

## Troubleshooting

"Couldn't include file 'includes/modules/bromsock.lua' (File not found)" means you probably didnt install gwsockets right

also this code is trash so gl debugging it when it inevitably breaks
