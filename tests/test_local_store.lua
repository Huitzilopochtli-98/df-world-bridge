local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local store=require('world-bridge.local-store')
local function entry(site,z)return {project_id=1,site_id=site,region_x=10,region_y=20,region_z=30,width=48,height=48,deck_z=z,absolute_z=30+z,material_type=0,material_index=5,
 cells={{x=0,y=0,z=z,kind='deck',before_tile=0,after_tile=489,before_water=0,source=false}}}end
local a=entry(1,4);local data={version=1,entries={a}}
assert(store.validate(data))
data.entries[2]=entry(1,4);assert(not store.validate(data))
data.entries[2]=entry(2,5);assert(not store.validate(data))
data.entries[2]=entry(2,4);assert(store.validate(data))
a.cells[2]=a.cells[1];assert(not store.validate(data));a.cells[2]=nil
a.cells[1].before_water=8;assert(not store.validate(data));a.cells[1].before_water=0
data.entries[4]=entry(4,4);assert(not store.validate(data));data.entries[4]=nil
local db;local persistent={getWorldData=function(_,default)return db or default end,saveWorldData=function(_,v)db=v end}
store.save(persistent,data);assert(#store.load(persistent).entries==2)
print('local placement ledger tests passed')
