local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local svc=require('world-bridge.service')
local store=require('world-bridge.store')
local function copy(t)
    if type(t)~='table' then return t end
    local v={};for k,x in pairs(t) do v[k]=copy(x) end;return v
end
local db={}
local persistent={getWorldData=function(k,d)return copy(db[k] or d) end,
    saveWorldData=function(k,v)db[k]=copy(v) end}
local now=100
local env={persistent=persistent,site_id=7,world={world_width=3,world_height=1},
    classify=function(x) return x==1 and 'water' or 'land' end,now=function()return now end,
    construction={apply=function(_,p,commit) commit({road_id=10,bridge_ids={11}});return {road_id=10,bridge_ids={11}} end}}
local p=assert(svc.create(env,{x=0,y=0},{x=2,y=0}))
assert(p.id==0 and p.required_blocks==100 and p.duration_ticks==14*1200)
assert(not svc.create(env,{x=0,y=0},{x=2,y=0}))
local d=store.load(persistent);p=d.projects[1].project
p.supplied_blocks=100;p.started_tick=100;p.state='building';store.save(persistent,d)
assert(svc.advance(env,0).state=='building')
now=16899;assert(svc.advance(env,0).state=='building')
now=16900;assert(svc.advance(env,0).state=='complete')
assert(store.load(persistent).projects[1].project.construction.road_id==10)
env.construction.apply=function()error('must not run twice') end
assert(svc.advance(env,0).state=='complete')
env.site_id=8;assert(not pcall(svc.advance,env,0))
env.site_id=7
local failed=store.load(persistent)
local p2=require('world-bridge.project').create(1,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},1,1)
p2.supplied_blocks=1;p2.started_tick=0;p2.state='building'
failed.next_id=2;failed.projects[2]={owner_site_id=7,project=p2};store.save(persistent,failed)
env.construction.apply=function() error('simulated failure') end
local result,err=svc.advance(env,1)
assert(not result and err:match('simulated failure'))
assert(store.load(persistent).projects[2].project.state=='ready')
-- Saved projects retain their original accounting rather than being repriced.
local old=require('world-bridge.project').create(2,{{x=0,y=0},{x=1,y=0},{x=2,y=0}},20,33600)
failed=store.load(persistent);failed.next_id=3;failed.projects[3]={owner_site_id=7,project=old};store.save(persistent,failed)
local saved=store.load(persistent).projects[3].project
assert(saved.required_blocks==20 and saved.duration_ticks==33600)
-- Pricing scales with water tiles, excluding both shores.
local empty={getWorldData=function(_,default)return copy(default) end}
local larger={persistent=empty,world={world_width=5,world_height=1},
 classify=function(x)return (x==0 or x==4) and 'land' or 'water' end}
local multi=assert(svc.plan(larger,{x=0,y=0},{x=4,y=0}))
assert(multi.required_blocks==300 and multi.duration_ticks==42*1200)
print('project orchestration tests passed')
