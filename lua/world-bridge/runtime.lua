-- Project scheduler and opt-in experimental automatic raid integration.
local adapter=require('world-bridge.df-adapter')
local store=require('world-bridge.store')
local service=require('world-bridge.service')
local steering=require('world-bridge.steering-adapter')
local automatic=require('world-bridge.automatic-experiment')
local trade=require('world-bridge.df-trade-access')
local M={}
local active=false
local automatic_enabled=false
local trade_enabled=false
local guard_view
local timer
local next_tick=0
local next_trade_tick=0
local failures={}
local function close_guard()
    local v=guard_view;guard_view=nil
    if v and v:isActive() then v:dismiss() end
end
local function update_automatic(env)
    local screen=dfhack.gui.getDFViewscreen(true)
    if screen and screen._type==df.viewscreen_worldst then
        if guard_view and not guard_view:isActive() then guard_view=nil end
        if not guard_view then
            -- Install the guard before changing accessibility. Do not wrap a
            -- different DFHack screen whose input behavior is unknown.
            if dfhack.gui.getCurViewscreen(true)~=screen then
                automatic.stop(env)
                return
            end
            dfhack.run_script('gui/world-bridge-guard')
            guard_view=dfhack.script_environment('gui/world-bridge-guard').view
            assert(guard_view and guard_view:isActive(),'could not activate world map guard')
        end
        -- The guard must be the top input recipient when the overlay is used.
        if dfhack.gui.getCurViewscreen(true)~=guard_view._native then
            guard_view:suspend()
            return
        end
    else
        close_guard()
    end
    automatic.update(env)
end
local function tick()
    timer=nil
    if not active or not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then return end
    local ok,err=pcall(function()
        local env=adapter.environment();local now=env.now()
        steering.update(env)
        if automatic_enabled then update_automatic(env) end
        local links_dirty=false
        if now>=next_tick then
            next_tick=now+1200
            local data=store.load(env.persistent)
            for _,entry in ipairs(data.projects) do
                if entry.owner_site_id==env.site_id and
                   (entry.project.state=='building' or entry.project.state=='ready') then
                    local advanced,p,why=pcall(service.advance,env,entry.project.id)
                    if not advanced then why=p;p=nil end
                    if not p then
                        if failures[entry.project.id]~=why then
                            dfhack.printerr(('World Bridge project %d: %s'):format(entry.project.id,why))
                            failures[entry.project.id]=why
                        end
                    else
                        failures[entry.project.id]=nil
                        if p.state=='complete' then
                            dfhack.gui.showAnnouncement(('World Bridge project %d is complete.'):format(p.id),COLOR_GREEN)
                            require('world-bridge.local-sync').run(env,p.id)
                            links_dirty=true
                        end
                    end
                end
            end
        end
        if trade_enabled and (links_dirty or now>=next_trade_tick) then
            trade.refresh(env,true);next_trade_tick=now+1200
        end
    end)
    if not ok then
        -- A running controller may be targeting a temporary waypoint. Stop
        -- time and try to restore it instead of silently abandoning guidance.
        pcall(close_guard)
        pcall(automatic.stop)
        pcall(trade.stop)
        pcall(function() steering.cancel_all(adapter.environment()) end)
        df.global.pause_state=true
        dfhack.printerr('World Bridge scheduler paused: '..tostring(err));active=false;return
    end
    timer=dfhack.timeout(5,'frames',tick)
end
function M.start()
    if active then return end
    active=true;next_tick=0;next_trade_tick=0;failures={};tick()
end
function M.stop()
    active=false
    if timer then dfhack.timeout_active(timer,nil);timer=nil end
    close_guard()
    automatic.stop()
    trade.stop()
end
function M.configure_automatic(enabled)
    automatic_enabled=not not enabled
    if not automatic_enabled then close_guard();automatic.stop() end
end
function M.is_automatic_enabled() return automatic_enabled end
function M.configure_trade(enabled)
    trade_enabled=not not enabled;next_trade_tick=0
    if not trade_enabled then trade.stop() end
end
function M.is_trade_enabled() return trade_enabled end
function M.is_active() return active end
return M
