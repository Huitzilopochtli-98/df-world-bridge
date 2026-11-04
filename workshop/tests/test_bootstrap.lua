local root=assert(arg[1],'pass the WorldBridge source folder')
local old_path=package.path
package.loaded['script-manager']={getModSourcePath=function(id)assert(id=='world_bridge');return 'mods/world-bridge/' end}
assert(loadfile(root..'/workshop/bootstrap.lua'))()
assert(add_lua_path()=='mods/world-bridge/')
assert(package.path=='mods/world-bridge/lua/?.lua;'..old_path)
local once=package.path;add_lua_path();assert(package.path==once,'bootstrap duplicates the path')
package.loaded['script-manager'].getModSourcePath=function()return nil end
assert(not pcall(add_lua_path),'missing Workshop mod must fail clearly')
package.path=old_path
print('Workshop bootstrap tests passed')
