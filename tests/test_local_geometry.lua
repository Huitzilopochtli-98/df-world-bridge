local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local geom=require('world-bridge.local-geometry')
local function key(x,y)return x..','..y end
local route={{x=65,y=4},{x=66,y=4},{x=67,y=4}}
local bounds={region_x=1064,region_y=71,width=192,height=192}
local r=geom.footprint(route,bounds,3)
assert(#r.centerline==192 and #r.tiles==576)
assert(r.centerline[1].distance==744 and r.centerline[192].distance==935)
local adjacent=geom.footprint(route,{region_x=1068,region_y=71,width=192,height=192},3)
assert(#adjacent.centerline==192 and adjacent.centerline[1].distance==936)
assert(adjacent.centerline[1].distance==r.centerline[192].distance+1)
local seen={};for _,p in ipairs(r.tiles) do seen[key(p.x,p.y)]=true;assert(p.y>=71 and p.y<=73) end
for x=0,191 do for y=71,73 do assert(seen[key(x,y)]) end end
local reverse=geom.footprint({route[3],route[2],route[1]},bounds,3)
assert(#reverse.tiles==#r.tiles);for _,p in ipairs(reverse.tiles) do assert(seen[key(p.x,p.y)]) end
local away=geom.footprint(route,{region_x=0,region_y=0,width=192,height=192},3);assert(#away.tiles==0)
local corner=geom.footprint({{x=10,y=10},{x=11,y=10},{x=11,y=11}},
 {region_x=11*16+7,region_y=10*16+7,width=144,height=144},3)
assert(#corner.centerline>0 and #corner.tiles>#corner.centerline)
local turn_tiles={};for _,p in ipairs(corner.tiles) do turn_tiles[key(p.x,p.y)]=true end
for x=71,73 do for y=71,73 do assert(turn_tiles[key(x,y)],'turn lacks three-wide clearance') end end
local backwards=geom.footprint({{x=11,y=11},{x=11,y=10},{x=10,y=10}},
 {region_x=11*16+7,region_y=10*16+7,width=144,height=144},3)
assert(#backwards.tiles==#corner.tiles)
for _,p in ipairs(backwards.tiles) do assert(turn_tiles[key(p.x,p.y)],'reversing a corner changes its footprint') end
assert(not pcall(geom.footprint,route,bounds,2))
print('local bridge geometry tests passed')
