--@module = true
-- Workshop files stay in the subscribed mod folder; no installer is run.
function add_lua_path()
    local root=assert(require('script-manager').getModSourcePath('world_bridge'),
        'World Bridge Workshop files were not found. Restart DFHack after subscribing.')
    local pattern=root:gsub('\\','/'):gsub('/+$','')..'/lua/?.lua'
    local present=false
    for entry in package.path:gmatch('[^;]+') do if entry==pattern then present=true;break end end
    if not present then package.path=pattern..';'..package.path end
    return root
end
