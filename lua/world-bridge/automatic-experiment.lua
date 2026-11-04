-- Experimental automatic integration, enabled explicitly in the runtime.
-- The guarded caller invokes update() on input and scheduler frames.
local access=require('world-bridge.accessibility-adapter')
local discover=require('world-bridge.mission-discovery')
local steering=require('world-bridge.steering-adapter')
local M={KEY='world-bridge/pending-missions-v1'}
local observed
local function pending(persistent)
    local d=persistent.getWorldData(M.KEY,{version=1,missions={}})
    assert(type(d)=='table' and d.version==1 and type(d.missions)=='table','invalid pending mission state')
    return d
end
local function scan(env)
    if not observed then return end
    local found=discover.observe(observed,df.global.world.army_controllers.all,
        function(site_id)
            local site=df.world_site.find(site_id)
            return site and access.is_extended(site.pos.x,site.pos.y)
        end,
        function(id)local s=df.squad.find(id);return s and s.entity_id==df.global.plotinfo.group_id end,
        function(c)return c.goal==df.army_controller_goal_type.SITE_INVASION end)
    if #found>0 then
        local d=pending(env.persistent)
        for _,f in ipairs(found) do
            local exists=false
            for _,p in ipairs(d.missions) do if p.controller_id==f.controller_id then exists=true end end
            if not exists then d.missions[#d.missions+1]=f end
        end
        env.persistent.saveWorldData(M.KEY,d)
    end
end
local function process(env)
    local d=pending(env.persistent)
    for i=#d.missions,1,-1 do
        local p=d.missions[i];local c=df.army_controller.find(p.controller_id)
        if not c or c.site_id~=p.site_id or c.goal~=df.army_controller_goal_type.SITE_INVASION then
            table.remove(d.missions,i);env.persistent.saveWorldData(M.KEY,d)
        elseif p.failure then
            df.global.pause_state=true
        else
            local owned=true
            for _,id in ipairs(c.assigned_squads) do
                local squad=df.squad.find(id)
                if not squad or squad.entity_id~=df.global.plotinfo.group_id then owned=false end
            end
            local armies={}
            for _,a in ipairs(df.global.world.armies.all) do
                if a.controller_id==c.id or (a.controller and a.controller.parent_id==c.id) then armies[#armies+1]=a end
            end
            if not owned then
                -- Unassigned controllers are observed before ownership is
                -- knowable. Never steer a different entity's later mission.
                table.remove(d.missions,i);env.persistent.saveWorldData(M.KEY,d)
            elseif #c.assigned_squads==0 then
                -- The native mission can remain after leaving the assignment
                -- screen with no squads. Keep watching without a timeout: an
                -- unassigned controller has no army to steer.
                if #armies>0 then
                    p.failure='an army exists without assigned squads'
                    env.persistent.saveWorldData(M.KEY,d)
                    df.global.pause_state=true
                    dfhack.printerr('World Bridge mission routing paused: '..p.failure)
                end
            else
                if #armies>0 then
                local ok,result=pcall(steering.begin,env,c.id,armies[1].id)
                if ok then
                    table.remove(d.missions,i);env.persistent.saveWorldData(M.KEY,d)
                else
                    local reason=tostring(result)
                    local waiting=reason:find('waiting for all assigned squad members',1,true) or
                        reason:find('exactly one assembled army',1,true)
                    local departed=false
                    if waiting then
                        local origin=df.world_site.find(env.site_id)
                        if not origin then
                            departed=true;reason='cannot verify the army origin while squads assemble'
                        else
                            for _,army in ipairs(armies) do
                                if math.floor(army.pos.x/48)~=origin.pos.x or math.floor(army.pos.y/48)~=origin.pos.y then
                                    departed=true;reason='an army left the fortress before all assigned squads assembled';break
                                end
                            end
                        end
                    end
                    if not waiting or departed then
                        p.failure=reason;env.persistent.saveWorldData(M.KEY,d)
                        df.global.pause_state=true
                        dfhack.printerr('World Bridge mission routing paused: '..reason)
                    end
                end
                end
            end
        end
    end
end
function M.update(env)
    local screen=dfhack.gui.getDFViewscreen(true)
    if screen and screen._type==df.viewscreen_worldst then
        if not observed then observed=discover.begin(df.global.world.army_controllers.all) end
        -- Capture assignments made under the previous overlay before update
        -- can replace it after a native path-map generation change.
        scan(env)
        local ok=access.update(env)
        if ok then scan(env) end
    else
        -- Last scan catches missions assigned just before closing the map.
        if observed then scan(env);observed=nil end
        access.restore()
    end
    process(env)
end
function M.stop(env)
    -- Guard dismissal must not discard an assignment made since the last
    -- scheduler frame. Always remove the temporary accessibility overlay.
    local ok,err=true,nil
    if observed and env then ok,err=pcall(scan,env) end
    observed=nil;access.restore()
    if not ok then error(err) end
end
function M.status(env) return pending(env.persistent) end
function M.retry(env,controller_id)
    local d=pending(env.persistent)
    for _,p in ipairs(d.missions) do
        if p.controller_id==controller_id and p.failure then
            p.failure=nil;env.persistent.saveWorldData(M.KEY,d);return true
        end
    end
    return false
end
return M
