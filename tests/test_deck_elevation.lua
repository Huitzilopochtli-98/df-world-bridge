local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local elevation=require('world-bridge.deck-elevation')
local path={{x=1,y=2},{x=2,y=2},{x=2,y=3}}
assert(elevation.choose(path,function(x,y)assert(x==2 and y==2);return 100 end)==101)
assert(elevation.choose(path,function()return 106 end)==107)
local long={{x=1,y=2},{x=2,y=2},{x=3,y=2},{x=4,y=2}}
local function varied(x)return x==2 and 106 or 109 end
assert(elevation.choose(long,varied)==110)
assert(elevation.choose({long[4],long[3],long[2],long[1]},varied)==110)
for _,value in ipairs{false,-1,1.5,math.huge} do
    assert(not pcall(elevation.choose,path,function()return value end))
end
assert(not pcall(elevation.choose,path,function()return nil end))
assert(not pcall(elevation.choose,{path[1],path[2]},function()return 100 end))
print('world water surface and deck elevation tests passed')
