local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local plan=require('world-bridge.local-plan')
local route={{x=65,y=4},{x=66,y=4},{x=67,y=4}}
local map={region_x=1064,region_y=71,width=192,height=192,z_count=10}
local function probe(x,y,z)return {shape=z==1 and 'natural_floor' or 'open',occupied=false,liquid=(z==2 or z==3) and 'water' or 'none'} end
local p=assert(plan.plan(route,map,5,probe))
assert(#p.deck==576 and #p.anchors==25 and #p.pillars==100 and p.displaced_water==50 and p.replaced_floors==25)
local replaced=0;for _,pillar in ipairs(p.pillars) do if pillar.replaces_floor then replaced=replaced+1;assert(pillar.z==1) end end
assert(replaced==25)
for _,a in ipairs(p.anchors) do assert(a.z==1) end
local function altered(x,y,z)
 local t=probe(x,y,z);if x==0 and y==71 and z==5 then t.occupied=true end;return t
end
local rejected,err=plan.plan(route,map,5,altered);assert(not rejected and err:match('obstruction'))
local function magma(x,y,z)local t=probe(x,y,z);if x==0 and y==72 and z==2 then t.liquid='magma' end;return t end
rejected,err=plan.plan(route,map,5,magma);assert(not rejected and err:match('hazardous liquid'))
local function blocked(x,y,z)local t=probe(x,y,z);if x==0 and y==72 and z==4 then t.shape='unknown' end;return t end
rejected,err=plan.plan(route,map,5,blocked);assert(not rejected and err:match('support obstructed'))
local function uninspectable()return {} end
rejected,err=plan.plan(route,map,5,uninspectable);assert(not rejected and err:match('inspected safely'))
local empty=assert(plan.plan(route,{region_x=0,region_y=0,width=192,height=192,z_count=10},5,probe));assert(#empty.deck==0)
-- A generated road under the centerline is preserved; lateral piers and
-- deck connectors provide an alternative without touching its records.
local function roadside(x,y,z)
 local t=probe(x,y,z)
 if z==1 and y>=69 and y<=75 then t.occupied=true;t.reason='an existing road' end
 if t.liquid=='water' then t.source=true end
 return t
end
local lateral=assert(plan.plan(route,map,5,roadside,8,{support_offsets={0,4,-4}}))
assert(#lateral.deck==651 and lateral.preserved_sources==50)
for _,a in ipairs(lateral.anchors) do assert(a.y==76) end
for _,p in ipairs(lateral.pillars) do assert(p.y==76) end
print('local deck preflight tests passed')
