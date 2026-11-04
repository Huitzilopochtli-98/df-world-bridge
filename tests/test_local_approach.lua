local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local approaches=require('world-bridge.local-approach')
local route={{x=65,y=4},{x=66,y=4},{x=67,y=4}}
local map={region_x=1064,region_y=71,width=192,height=192,z_count=10}
local deck={};for x=0,191 do for y=71,73 do deck[#deck+1]={x=x,y=y,z=5} end end
local planned={deck=deck,pillars={}}
local function probe(x,y,z)
 return {shape=(y==76 and z==2) and 'natural_floor' or 'open',occupied=false,liquid='none',walk_group=1}
end
local a=assert(approaches.find(route,map,5,probe,planned,1))
assert(a.base.y==76 and a.base.z==2 and #a.stairs==4 and #a.deck==2)
assert(a.stairs[1].kind=='stair_up' and a.stairs[4].kind=='stair_down')
assert(not approaches.find(route,map,5,probe,planned,2))
local function wet(x,y,z)local p=probe(x,y,z);if y==76 then p.liquid='water' end;return p end
assert(not approaches.find(route,map,5,wet,planned,1))
local function blocked(x,y,z)local p=probe(x,y,z);if y==74 and z==5 then p.occupied=true end;return p end
assert(not approaches.find(route,map,5,blocked,planned,1))
print('local shore approach tests passed')
