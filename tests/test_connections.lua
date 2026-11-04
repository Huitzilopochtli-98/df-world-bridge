local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local connections=require('world-bridge.connections')
local entities={
 [1]={civilization=true},[2]={civilization=true},
 [10]={parents={1}},[11]={parents={10}},[12]={parents={1,10}},
 [13]={parents={1,2}},[14]={parents={15}},[15]={parents={14}},
 [16]={parents={1,99}},[17]={parents={}},
}
local owner=connections.owner_resolver(function(id)return entities[id] end)
assert(owner(11)==1 and owner(12)==1 and owner(2)==2)
assert(not owner(13) and not owner(14) and not owner(15) and not owner(16) and not owner(17) and not owner(-1))
entities[10]={parents={2}}
owner=connections.owner_resolver(function(id)return entities[id] end)
assert(owner(11)==2,'current owner must replace the former civilization')
local function classify(x)return (x==2 or x==4) and 'water' or 'land' end
local graph={tile=function(x)return x==2 or x==4 end,
 edge=function(ax,ay,bx,by)return ay==1 and by==1 and math.abs(ax-bx)==1 and ax>=1 and ax<=5 and bx>=1 and bx<=5 end}
local sites={
 {id=1,civ_id=10,x=0,y=0,market=true},{id=2,civ_id=10,x=6,y=0,market=true},
 {id=3,civ_id=20,x=6,y=1,market=true},{id=4,civ_id=30,x=6,y=2,market=false},
 {id=5,civ_id=40,x=0,y=2,market=false},{id=6,civ_id=40,x=5,y=2,market=true},
}
local found,native=connections.find(7,3,{x=0,y=1},classify,graph,sites)
assert(#found==1 and found[1].civ_id==20 and found[1].site_id==3 and native[10] and native[40])
local no={tile=function()return false end,edge=function()return false end}
assert(#connections.find(7,3,{x=0,y=1},classify,no,sites)==0)
-- A real native fort anchor already connects the water tile, so bridge
-- ownership must not be claimed for its existing connections.
found,native=connections.find(7,3,{x=0,y=1},classify,graph,sites,{{x=2,y=1},{x=4,y=1}})
assert(#found==0 and native[20])
print('current territory and bridge connection tests passed')
