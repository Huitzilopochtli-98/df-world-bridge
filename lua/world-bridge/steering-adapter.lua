-- Experimental mission steering adapter. Not yet auto-enabled.
local steering=require('world-bridge.steering')
local navigation=require('world-bridge.navigation')
local index=require('world-bridge.bridge-index')
local store=require('world-bridge.store')
local construction=require('world-bridge.construction')
local M={KEY='world-bridge/steering-v1'}
local function load(persistent)
    local d=persistent.getWorldData(M.KEY,{version=1,states={},watches={}})
    assert(type(d)=='table' and d.version==1 and type(d.states)=='table','invalid steering data')
    if d.watches==nil then d.watches={} end
    assert(type(d.watches)=='table','invalid steering watches')
    return d
end
local function save(persistent,d) persistent.saveWorldData(M.KEY,d) end
function M.has_trips(env)
    local data=load(env.persistent)
    return #data.states>0 or #data.watches>0
end
local function belongs(a,c)
    return a and (a.controller_id==c.id or (a.controller and a.controller.parent_id==c.id))
end
local function observation(s,c,a)
    local ended=c and (c.goal~=df.army_controller_goal_type.SITE_INVASION or c.flag.done_for_dwarf_mode)
    return {controller_present=c~=nil,army_present=a~=nil,site_id=c and c.site_id,
        goal_x=c and c.pos_x,goal_y=c and c.pos_y,army_x=a and a.pos.x,army_y=a and a.pos.y,
        mission_ended=not not ended}
end

-- A controller can own multiple squads. Start only when exactly one related
-- army contains every occupied squad position, so later arrivals cannot be
-- left behind while the shared target moves to a waypoint.
local function assembled(c,a)
    if #c.assigned_squads==0 then return false,'mission has no assigned squads' end
    local count=0
    for _,other in ipairs(df.global.world.armies.all) do if belongs(other,c) then count=count+1 end end
    if count~=1 then return false,'mission does not have exactly one assembled army' end
    local present={}
    for _,member in ipairs(a.members) do
        local n=df.nemesis_record.find(member.nemesis_id)
        if n and n.figure then present[n.figure.id]=true end
    end
    local occupied=0
    for _,id in ipairs(c.assigned_squads) do
        local squad=df.squad.find(id)
        if not squad or squad.entity_id~=df.global.plotinfo.group_id then return false,'squad is not from this fortress' end
        for _,pos in ipairs(squad.positions) do
            if pos.occupant~=-1 then
                occupied=occupied+1
                if not present[pos.occupant] then return false,'waiting for all assigned squad members' end
            end
        end
    end
    if occupied==0 then return false,'assigned squads have no members' end
    return true
end

function M.begin(env,controller_id,army_id)
    local c=df.army_controller.find(controller_id);local a=df.army.find(army_id)
    assert(c and a and belongs(a,c),'army is not controlled by this mission')
    assert(c.goal==df.army_controller_goal_type.SITE_INVASION,'only raid missions are currently supported')
    local ready,why=assembled(c,a);assert(ready,why)
    local data=load(env.persistent)
    for _,s in ipairs(data.states) do assert(s.controller_id~=c.id,'mission is already being guided') end
    local g=index.build(store.load(env.persistent),function(p)return construction.verify(env.world,p) end)
    assert(g.count>0,'no verified bridges')
    local start={x=math.floor(a.pos.x/48),y=math.floor(a.pos.y/48)}
    local goal={x=math.floor(c.pos_x/48),y=math.floor(c.pos_y/48)}
    local function kind(x,y)
        local k=env.classify(x,y)
        if k=='blocked' and ((x==start.x and y==start.y) or (x==goal.x and y==goal.y)) then return 'land' end
        return k
    end
    local path,err=navigation.find(env.world.world_width,env.world.world_height,start,goal,kind,g.tile,g.edge)
    assert(path,err)
    local wet=false
    for _,p in ipairs(path) do if g.tile(p.x,p.y) then wet=true end end
    assert(wet,'route does not use a bridge')
    local state,command=steering.begin(c.id,a.id,c.site_id,c.pos_x,c.pos_y,path)
    local goal=c.data.goal_site_invasion
    state.leg=(goal and goal.flag.RETURNING_HOME) and 'return' or 'outbound'
    state.squad_ids={}
    for _,id in ipairs(c.assigned_squads) do state.squad_ids[#state.squad_ids+1]=id end
    table.sort(state.squad_ids)
    data.states[#data.states+1]=state
    save(env.persistent,data)
    c.pos_x=command.x;c.pos_y=command.y
    return state
end

function M.update(env)
    local data=load(env.persistent);local changed=false
    for i=#data.states,1,-1 do
        local s=data.states[i]
        assert(type(s)=='table' and s.version==1 and s.state=='steering','invalid saved steering state')
        local c=df.army_controller.find(s.controller_id);local a=df.army.find(s.army_id)
        if s.failure then
            df.global.pause_state=true
            goto continue
        end
        do
            local invasion=c and c.goal==df.army_controller_goal_type.SITE_INVASION and c.data.goal_site_invasion
            local same_leg=invasion and ((s.leg=='return')==not not invasion.flag.RETURNING_HOME)
            if c and s.squad_ids and same_leg and c.site_id==s.site_id and
               c.pos_x==s.expected_x and c.pos_y==s.expected_y then
                local current={}
                for _,id in ipairs(c.assigned_squads) do current[#current+1]=id end
                table.sort(current)
                local same=#current==#s.squad_ids
                if same then for j,id in ipairs(current) do if id~=s.squad_ids[j] then same=false;break end end end
                if not same then
                    s.failure='assigned squads changed while bridge guidance was active'
                    save(env.persistent,data);df.global.pause_state=true
                    dfhack.printerr('World Bridge guidance paused: '..s.failure)
                    goto continue
                end
            end
        end
        do
            local old_index=s.index
            local cmd,reason=steering.step(s,observation(s,c,a))
            if s.state~='steering' then
                table.remove(data.states,i);changed=true
                local goal=c and c.goal==df.army_controller_goal_type.SITE_INVASION and c.data.goal_site_invasion
                local returning=goal and goal.flag.RETURNING_HOME
                if (s.leg or 'outbound')=='outbound' and c and
                   (s.state=='complete' or returning) then
                    data.watches[#data.watches+1]={controller_id=s.controller_id,army_id=s.army_id,site_id=s.site_id,
                        outbound_x=s.original_x,outbound_y=s.original_y}
                end
            elseif s.index~=old_index then changed=true end
            -- Save the updated intent before changing the live controller. No DF
            -- ticks or save callbacks occur between these statements.
            if changed then save(env.persistent,data);changed=false end
            if cmd and c then c.pos_x=cmd.x;c.pos_y=cmd.y end
        end
        ::continue::
    end
    for i=#data.watches,1,-1 do
        local watch=data.watches[i]
        local c=df.army_controller.find(watch.controller_id);local a=df.army.find(watch.army_id)
        if not c or c.site_id~=watch.site_id or c.goal~=df.army_controller_goal_type.SITE_INVASION or c.flag.done_for_dwarf_mode then
            table.remove(data.watches,i);save(env.persistent,data)
        elseif watch.failure then
            -- Keep the game paused until guidance is explicitly canceled or
            -- repaired; one accidental unpause must not bypass the failure.
            df.global.pause_state=true
        elseif not watch.failure and c.data.goal_site_invasion and c.data.goal_site_invasion.flag.RETURNING_HOME and
               (c.pos_x~=watch.outbound_x or c.pos_y~=watch.outbound_y) and a and belongs(a,c) then
            table.remove(data.watches,i);save(env.persistent,data)
            local ok,err=pcall(M.begin,env,c.id,a.id)
            -- begin() writes a fresh registry; reload before processing any
            -- remaining watch so we never overwrite its state.
            data=load(env.persistent)
            if not ok then
                -- Do not let a failed reroute silently send the squad across
                -- unrestricted ocean. Keep the failure for diagnosis.
                watch.failure=tostring(err);data.watches[#data.watches+1]=watch
                save(env.persistent,data)
                df.global.pause_state=true
                dfhack.printerr('World Bridge return routing paused: '..watch.failure)
            end
        end
    end
end

function M.cancel_all(env)
    local data=load(env.persistent)
    local commands={}
    for _,s in ipairs(data.states) do
        local c=df.army_controller.find(s.controller_id);local a=df.army.find(s.army_id)
        local cmd=steering.cancel(s,observation(s,c,a))
        if cmd and c then commands[#commands+1]={controller=c,command=cmd} end
    end
    data.states={};data.watches={};save(env.persistent,data)
    for _,v in ipairs(commands) do v.controller.pos_x=v.command.x;v.controller.pos_y=v.command.y end
end
return M
