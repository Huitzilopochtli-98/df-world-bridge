local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
package.path=root..'/lua/?.lua;'..package.path
local function copy(v)
    if type(v)~='table' then return v end
    local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t
end
local db={}
local persistent={getWorldData=function(k,d)return copy(db[k] or d) end,
    saveWorldData=function(k,v) db[k]=copy(v) end}
local controller={id=7,site_id=9,goal=2,pos_x=200,pos_y=72,
    flag={done_for_dwarf_mode=false},data={goal_site_invasion={flag={RETURNING_HOME=false}}},
    assigned_squads={11}}
local army={id=8,controller_id=7,pos={x=72,y=72},members={{nemesis_id=50}}}
df={army_controller={find=function(id)if id==7 then return controller end end},
    army={find=function(id)if id==8 then return army end end},
    squad={find=function(id)if id==11 then return {entity_id=42,positions={{occupant=60}}} end end},
    nemesis_record={find=function(id)if id==50 then return {figure={id=60}} end end},
    global={plotinfo={group_id=42},world={armies={all={army}}}},army_controller_goal_type={SITE_INVASION=2}}
local warnings={}
dfhack={printerr=function(x)warnings[#warnings+1]=x end}
package.loaded['world-bridge.store']={load=function()return {projects={}} end}
package.loaded['world-bridge.bridge-index']={build=function()return {count=1,
    tile=function(x)return x==2 end,edge=function()return true end} end}
package.loaded['world-bridge.construction']={verify=function()return true end}
package.loaded['world-bridge.navigation']={find=function(_,_,start,goal)
    if start.x==1 then return {{x=1,y=1},{x=2,y=1},{x=3,y=1},{x=4,y=1}} end
    return {{x=4,y=1},{x=3,y=1},{x=2,y=1},{x=1,y=1}}
end}
local a=require('world-bridge.steering-adapter')
local env={persistent=persistent,world={world_width=10,world_height=10},classify=function()return 'land' end}
local s=a.begin(env,7,8)
assert(s.leg=='outbound' and controller.pos_x==120 and #db[a.KEY].states==1)
army.pos.x=120;a.update(env);assert(controller.pos_x==168)
army.pos.x=168;a.update(env)
assert(controller.pos_x==200 and #db[a.KEY].states==0 and #db[a.KEY].watches==1)
controller.data.goal_site_invasion.flag.RETURNING_HOME=true
controller.pos_x=72;controller.pos_y=72;army.pos.x=216
a.update(env)
assert(#db[a.KEY].watches==0 and db[a.KEY].states[1].leg=='return' and controller.pos_x==168)
army.pos.x=168;a.update(env);assert(controller.pos_x==120)
army.pos.x=120;a.update(env);assert(controller.pos_x==72 and #db[a.KEY].states==0)
s=a.begin(env,7,8);controller.pos_x=999;a.update(env)
assert(controller.pos_x==999 and #db[a.KEY].states==0)
db[a.KEY]={version=1,states={},watches={{controller_id=7,army_id=8,site_id=9,outbound_x=200,outbound_y=72}}}
controller.pos_x=72;controller.pos_y=72;controller.data.goal_site_invasion.flag.RETURNING_HOME=true
package.loaded['world-bridge.navigation'].find=function() return nil,'blocked route' end
a.update(env)
assert(df.global.pause_state and #db[a.KEY].watches==1 and db[a.KEY].watches[1].failure:match('blocked route'))
assert(#warnings==1)
a.update(env);assert(#warnings==1)
-- Multiple squads may share a controller, but must all be in the same army.
db[a.KEY]={version=1,states={},watches={}}
controller.data.goal_site_invasion.flag.RETURNING_HOME=false
controller.pos_x=200;controller.pos_y=72;army.pos.x=72;army.pos.y=72
controller.assigned_squads={11,12}
df.squad.find=function(id)
    if id==11 then return {entity_id=42,positions={{occupant=60}}} end
    if id==12 then return {entity_id=42,positions={{occupant=61}}} end
end
df.nemesis_record.find=function(id) if id==50 then return {figure={id=60}} elseif id==51 then return {figure={id=61}} end end
package.loaded['world-bridge.navigation'].find=function() return {{x=1,y=1},{x=2,y=1},{x=3,y=1},{x=4,y=1}} end
assert(not pcall(a.begin,env,7,8)) -- second squad has not arrived
army.members[2]={nemesis_id=51}
df.global.world.armies.all[2]={id=10,controller_id=7,members={}}
assert(not pcall(a.begin,env,7,8)) -- a second army shares the controller
df.global.world.armies.all[2]=nil
assert(a.begin(env,7,8).state=='steering')
controller.assigned_squads={11}
df.global.pause_state=false
a.update(env)
assert(df.global.pause_state and db[a.KEY].states[1].failure:match('squads changed'))
df.global.pause_state=false;a.update(env);assert(df.global.pause_state)
a.cancel_all(env);assert(controller.pos_x==200 and #db[a.KEY].states==0)
print('mission steering adapter tests passed')
