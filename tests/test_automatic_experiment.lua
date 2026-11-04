local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local function copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local db={};local persistent={getWorldData=function(k,d)return copy(db[k] or d) end,
    saveWorldData=function(k,v)db[k]=copy(v) end}
local screen={_type='world'};local controllers={};local armies={};local now=100
df={viewscreen_worldst='world',army_controller_goal_type={SITE_INVASION=2},
    global={plotinfo={group_id=42},world={army_controllers={all=controllers},armies={all=armies}}},
    world_site={find=function(id) if id==7 then return {pos={x=1,y=2}} elseif id==11 then return {pos={x=0,y=0}} end end},
    squad={find=function(id)if id==3 then return {entity_id=42} end end},
    army_controller={find=function(id) for _,c in ipairs(controllers) do if c.id==id then return c end end end}}
dfhack={gui={getDFViewscreen=function()return screen end},printerr=function()end}
local restored=false
package.loaded['world-bridge.accessibility-adapter']={update=function()return true end,
    restore=function()restored=true end,is_extended=function(x,y)return x==1 and y==2 end}
local began=0
package.loaded['world-bridge.steering-adapter']={begin=function(_,cid,aid)began=began+1;assert(cid==5 and aid==8) end}
local auto=require('world-bridge.automatic-experiment')
local env={persistent=persistent,now=function()return now end,site_id=11}
auto.update(env) -- establish baseline
controllers[1]={id=5,site_id=7,goal=2,assigned_squads={3}}
auto.update(env)
assert(#db[auto.KEY].missions==1 and began==0)
screen={_type='fort'};armies[1]={id=8,controller_id=5}
auto.update(env)
assert(restored and began==1 and #db[auto.KEY].missions==0)
-- A partial army may wait at home, but must not depart unsteered.
package.loaded['world-bridge.steering-adapter'].begin=function() error('waiting for all assigned squad members') end
db[auto.KEY]={version=1,missions={{controller_id=5,site_id=7}}}
armies[1].pos={x=0,y=0}
auto.update(env)
assert(#db[auto.KEY].missions==1 and not df.global.pause_state)
now=130000;auto.update(env)
assert(not df.global.pause_state and not db[auto.KEY].missions[1].failure)
armies[1].pos.x=48;auto.update(env)
assert(df.global.pause_state and db[auto.KEY].missions[1].failure:match('left the fortress'))
df.global.pause_state=false;auto.update(env);assert(df.global.pause_state)
-- No army cannot depart, so an assigned mission may wait without a timeout.
armies[1]=nil;df.global.pause_state=false;now=2000
db[auto.KEY]={version=1,missions={{controller_id=5,site_id=7}}}
auto.update(env);assert(not df.global.pause_state)
now=320000;auto.update(env)
assert(not df.global.pause_state and #db[auto.KEY].missions==1)
-- A newly assigned raid must be captured even if the guard is dismissed
-- before another scheduler frame, while the overlay still exists.
controllers[1]=nil;armies[1]=nil;db[auto.KEY]={version=1,missions={}}
df.global.pause_state=false;screen={_type='world'};restored=false
auto.update(env)
controllers[1]={id=5,site_id=7,goal=2,assigned_squads={}}
auto.stop(env)
assert(restored and #db[auto.KEY].missions==1 and db[auto.KEY].missions[1].controller_id==5)
screen={_type='fort'};auto.update(env)
assert(#db[auto.KEY].missions==1 and not df.global.pause_state)
now=5000;auto.update(env)
assert(#db[auto.KEY].missions==1 and not df.global.pause_state and not db[auto.KEY].missions[1].first_seen)
controllers[1].assigned_squads={3};armies[1]={id=8,controller_id=5}
package.loaded['world-bridge.steering-adapter'].begin=function()began=began+1 end
auto.update(env);assert(#db[auto.KEY].missions==0 and began==2)
-- A controller that later acquires a foreign squad is never steered.
armies[1]=nil;db[auto.KEY]={version=1,missions={{controller_id=5,site_id=7}}}
controllers[1].assigned_squads={99};auto.update(env)
assert(#db[auto.KEY].missions==0 and began==2)
-- If an army appears before any squad assignment, freeze rather than lose it.
controllers[1].assigned_squads={};armies[1]={id=8,controller_id=5}
db[auto.KEY]={version=1,missions={{controller_id=5,site_id=7}}}
df.global.pause_state=false;auto.update(env)
assert(df.global.pause_state and db[auto.KEY].missions[1].failure:match('without assigned squads'))
assert(auto.retry(env,5) and not db[auto.KEY].missions[1].failure)
assert(not auto.retry(env,5) and not auto.retry(env,123))
print('automatic mission integration tests passed')
