#!/bin/bash
# usage: deploy.sh <tag>
set -e
cd /home/claude/t21/build && python3 build_t21.py
(echo "--!nonstrict"; cat /home/claude/scripts/TwentyOne) > /tmp/check.luau && /home/claude/tools/luau-compile --binary /tmp/check.luau > /dev/null
! grep -q ']====]' /home/claude/scripts/TwentyOne
cp /home/claude/scripts/TwentyOne /mnt/user-data/outputs/TwentyOne_$1.lua
{ printf 'local source = [====[\n'; cat /home/claude/scripts/TwentyOne; printf ']====]\n'; cat <<'T'
local fn, err = loadstring(source, '=TwentyOne')
getgenv().T21Compile = fn and 'ok-@TAG@' or tostring(err)
if not fn then return end
if not isfolder('Potent') then makefolder('Potent') end
if not isfolder('Potent/scripts') then makefolder('Potent/scripts') end
if not isfolder('TwentyOne') then makefolder('TwentyOne') end
writefile('Potent/scripts/TwentyOne.lua', source)
writefile('TwentyOne/TwentyOne.lua', source)
T
} | sed "s/@TAG@/$1/" > /mnt/user-data/outputs/TwentyOne_deploy_$1.lua
ls -la /mnt/user-data/outputs/TwentyOne_*$1.lua
