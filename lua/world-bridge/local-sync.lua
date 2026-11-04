-- Apply or verify completed bridges that intersect a loaded fortress map.
-- A conflict pauses the game and is reported; changed tiles are never repaired
-- automatically. The completed project already paid the world-scale cost.
local store=require('world-bridge.store')
local local_build=require('world-bridge.local-construction')
local M={KEY='world-bridge/local-options-v1'}
function M.enabled(persistent)
    local options=persistent.getWorldData(M.KEY,{enabled=true})
    assert(type(options)=='table' and type(options.enabled)=='boolean','invalid local deck options')
    return options.enabled
end
function M.set_enabled(persistent,enabled)persistent.saveWorldData(M.KEY,{enabled=not not enabled})end
function M.run(env,project_id)
    if not M.enabled(env.persistent) then return {built=0,verified=0,errors={}} end
    local result={built=0,verified=0,errors={}}
    local was_paused=df.global.pause_state;df.global.pause_state=true
    local ok,err=pcall(function()
        for _,entry in ipairs(store.load(env.persistent).projects) do
            local p=entry.project
            if p.state=='complete' and (project_id==nil or project_id==p.id) then
                local built,value=pcall(local_build.build,env,p)
                if not built then
                    result.errors[#result.errors+1]={project_id=p.id,reason=tostring(value)}
                elseif value.existing then result.verified=result.verified+1
                elseif not value.empty then result.built=result.built+1 end
            end
        end
    end)
    if not ok then result.errors[#result.errors+1]={reason=tostring(err)} end
    if #result.errors==0 then df.global.pause_state=was_paused end
    for _,e in ipairs(result.errors) do dfhack.printerr(('World Bridge local placement%s paused: %s'):format(e.project_id and (' '..e.project_id) or '',e.reason)) end
    if result.built>0 then dfhack.gui.showAnnouncement(('World Bridge: %d local deck section(s) placed.'):format(result.built),COLOR_GREEN) end
    return result
end
return M
