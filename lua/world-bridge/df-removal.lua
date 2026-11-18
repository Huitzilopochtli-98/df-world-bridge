-- Native safety checks for removing completed bridges.
local M={}

function M.check_travel(env,project)
    local steering=require('world-bridge.steering-adapter')
    assert(not steering.has_trips(env),'a guided squad is still away; wait for it to return')
    local pending=require('world-bridge.automatic-experiment').status(env)
    for _,mission in ipairs(pending.missions) do
        local controller=df.army_controller.find(mission.controller_id)
        assert(not controller or controller.flag.done_for_dwarf_mode or
            controller.site_id~=mission.site_id or controller.goal~=df.army_controller_goal_type.SITE_INVASION,
            'a bridge mission is pending; finish or remove it in the world map')
    end
    local runtime=require('world-bridge.runtime')
    assert(not runtime.is_automatic_enabled(),'turn off raid routing before removing a completed bridge')
    local links=require('world-bridge.trade-access').load(env)
    assert(not runtime.is_trade_enabled() and #links.owned==0,
        'turn off caravan access before removing a completed bridge')
    assert(#df.global.plotinfo.caravans==0,'wait for visiting or scheduled caravans to leave')
    local route={}
    for i=2,#project.path-1 do
        local tile=project.path[i]
        route[tile.x..','..tile.y]=true
    end
    for _,army in ipairs(df.global.world.armies.all) do
        local x,y=math.floor(army.pos.x/48),math.floor(army.pos.y/48)
        assert(not route[x..','..y],'an army is on the bridge route')
    end
end

function M.prepare_local(env,entry)
    return require('world-bridge.local-construction').prepare_removal(env,entry)
end

function M.require_pause()
    assert(df.global.pause_state,'pause the game before removing a completed bridge')
end

function M.pause()
    df.global.pause_state=true
end

return M
