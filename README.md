# PK Sync

## Requirements

https://github.com/Bromvlieg/gm_bromsock

you'll probably need to compile the binary yourself if you're running GNU/Linux for which you can use the following:

https://github.com/AlmightyLaxz/gm_bromsock_docker_build

## Install

put pksync.lua in lua/autorun/server/pksync.lua

and bromsock in lua/bin/gmsv_bromsock_linux.dll

## Usage

runs on tcp port 27057

sync_connect 123.123.123.123

must be at least 1 player on each server

## Troubleshooting

"Couldn't include file 'includes/modules/bromsock.lua' (File not found)" means you fucked up or need to recompile it

also this code is trash so gl debugging it when it inevitably breaks
