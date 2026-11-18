--@module = true
--@enable = true
-- Experimental command interface. Not a finished or supported release.
local adapter=require('world-bridge.df-adapter')
local service=require('world-bridge.service')
local store=require('world-bridge.store')
local runtime=require('world-bridge.runtime')
local steering=require('world-bridge.steering-adapter')
local runtime_key='world-bridge/runtime-v1'
function isEnabled() return runtime.is_active() end
dfhack.onStateChange['world-bridge'] = function(code)
    if code==SC_MAP_UNLOADED then runtime.stop();return end
    if code==SC_MAP_LOADED and dfhack.world.isFortressMode() then
        local loaded,data=pcall(store.load,dfhack.persistent)
        if loaded then
            for _,entry in ipairs(data.projects) do if entry.project.state=='complete' then
                local ok,value=pcall(function()
                    local sync=require('world-bridge.local-sync')
                    if sync.enabled(dfhack.persistent) then sync.run(adapter.environment()) end
                end)
                if not ok then df.global.pause_state=true;dfhack.printerr('World Bridge local placement paused: '..tostring(value)) end
                break
            end end
        else df.global.pause_state=true;dfhack.printerr(data) end
        local config=dfhack.persistent.getSiteData(runtime_key,{enabled=false})
        runtime.configure_automatic(config.automatic==true)
        local trade=require('world-bridge.df-trade-access')
        local ownership=require('world-bridge.trade-access')
        if config.trade_access or dfhack.persistent.getWorldData(ownership.KEY) then
            local reconciled,err=pcall(function()
                trade.refresh(adapter.environment(),config.enabled==true and config.trade_access==true)
            end)
            if not reconciled then df.global.pause_state=true;dfhack.printerr('World Bridge trade access paused: '..tostring(err));return end
        end
        runtime.configure_trade(config.trade_access==true)
        if config.enabled then runtime.start() end
    end
end
if dfhack_flags.module then return end
local args={...}
if dfhack_flags.enable then args={dfhack_flags.enable_state and 'enable' or 'disable'} end
local function usage()
    print('world-bridge (opens the project planner)')
    print('world-bridge plan <x1> <y1> <x2> <y2>')
    print('world-bridge create <x1> <y1> <x2> <y2>')
    print('world-bridge list')
    print('world-bridge preview-local <project-id> <local-z>')
    print('world-bridge build-local <project-id> [local-z]')
    print('world-bridge local-decks on|off')
    print('world-bridge deliver <project-id> <number-of-blocks>')
    print('world-bridge advance <project-id>')
    print('world-bridge cancel <project-id> [--confirm]')
    print('world-bridge remove <project-id> [--confirm]')
    print('world-bridge guide <controller-id> <army-id>')
    print('world-bridge cancel-guidance')
    print('world-bridge guidance-status')
    print('world-bridge retry-guidance <controller-id>')
    print('world-bridge experiment-auto on|off')
    print('world-bridge trade-access on|off')
    print('world-bridge trade-status')
    print('world-bridge enable | disable')
    print('Experimental: travel integration is not yet complete.')
end
if #args==0 or (#args==1 and args[1]=='gui') then dfhack.run_script('gui/world-bridge');return end
if args[1]=='help' then usage();return end
local ok,env=pcall(adapter.environment)
if not ok then qerror(env) end
local function set_enabled(enabled)
    if not enabled and runtime.is_active() then steering.cancel_all(env) end
    local config=dfhack.persistent.getSiteData(runtime_key,{enabled=false})
    config.enabled=enabled
    dfhack.persistent.saveSiteData(runtime_key,config)
    runtime.configure_automatic(config.automatic==true)
    runtime.configure_trade(config.trade_access==true)
    if enabled then runtime.start() else runtime.stop() end
end
local function integer_arg(index)
    local n=tonumber(args[index])
    if not n or n~=math.floor(n) or n<0 then qerror('Arguments must be nonnegative integers.') end
    return n
end
local function print_project(p)
    print(('Project %d: %s; %d/%d blocks; %d water tiles.'):format(
        p.id,p.state,p.supplied_blocks,p.required_blocks,#p.path-2))
    print(('Route: %d,%d to %d,%d; construction time %d days.'):format(
        p.path[1].x,p.path[1].y,p.path[#p.path].x,p.path[#p.path].y,p.duration_ticks/1200))
end
if args[1]=='plan' or args[1]=='create' then
    if #args~=5 then qerror('Expected four world-tile coordinates.') end
    local a={x=integer_arg(2),y=integer_arg(3)}
    local b={x=integer_arg(4),y=integer_arg(5)}
    local p,err
    if args[1]=='plan' then p,err=service.plan(env,a,b) else p,err=service.create(env,a,b) end
    if not p then qerror(err) end
    if args[1]=='create' then set_enabled(true) end
    print_project(p)
    for _,tile in ipairs(p.path) do print(('%d,%d (%s)'):format(tile.x,tile.y,env.classify(tile.x,tile.y))) end
    if args[1]=='plan' then print('Preview only; no project was created.') end
elseif args[1]=='list' and #args==1 then
    local data=store.load(env.persistent)
    if #data.projects==0 then print('No bridge projects in this world.') end
    for _,entry in ipairs(data.projects) do
        print_project(entry.project)
        if entry.owner_site_id~=env.site_id then print(('Owned by site %d.'):format(entry.owner_site_id)) end
    end
elseif (args[1]=='preview-local' and #args==3) or (args[1]=='build-local' and (#args==2 or #args==3)) then
    local id,z=integer_arg(2),args[3] and integer_arg(3) or nil
    local selected
    for _,entry in ipairs(store.load(env.persistent).projects) do
        if entry.project.id==id then selected=entry.project;break end
    end
    if not selected or selected.state~='complete' then qerror('Completed project not found.') end
    local local_build=require('world-bridge.local-construction')
    local ok,result=pcall(args[1]=='build-local' and local_build.build or local_build.preview,env,selected,z)
    if not ok then qerror(result) end
    if result.existing then print('The local deck is already present and verified.');return end
    if result.empty then print('This bridge does not cross the loaded local map.');return end
    local p=result.plan
    print(('Local deck: %d floor tiles, %d pillar tiles, %d supports.'):format(#p.deck,#p.pillars,#p.anchors))
    print(('Dry shore approaches: %d; stair tiles: %d.'):format(p.approaches or 0,#(p.stairs or {})))
    print(('Natural floor bases: %d; displaced water tiles: %d; preserved sources: %d.'):format(p.replaced_floors,p.displaced_water,p.preserved_sources))
    print(args[1]=='build-local' and 'Local construction committed; the game remains paused.' or 'Preview only; no terrain was changed.')
elseif args[1]=='deliver' and #args==3 then
    local id,count=integer_arg(2),integer_arg(3)
    local success,n,left,state=pcall(service.deliver,env,id,count)
    if not success then qerror(n) end
    print(('Delivered %d blocks; %d remain. Project: %s.'):format(n,left,state))
elseif args[1]=='local-decks' and #args==2 and (args[2]=='on' or args[2]=='off') then
    local sync=require('world-bridge.local-sync');local enabled=args[2]=='on'
    sync.set_enabled(env.persistent,enabled)
    if enabled then sync.run(env) end
    print('Automatic local decks '..(enabled and 'enabled.' or 'disabled.'))
elseif args[1]=='advance' and #args==2 then
    local id=integer_arg(2)
    local success,p,err=pcall(service.advance,env,id)
    if not success then qerror(p) end
    if not p then qerror(err) end
    print_project(p)
elseif (args[1]=='cancel' or args[1]=='remove') and (#args==2 or (#args==3 and args[3]=='--confirm')) then
    local removal=require('world-bridge.removal')
    local id=integer_arg(2)
    local success,preview=pcall(removal.preview,env,id)
    if not success then qerror(preview) end
    local p=preview.project
    local completed=p.state=='complete'
    if completed and args[1]~='remove' then qerror('Use remove for a completed bridge.') end
    if not completed and args[1]~='cancel' then qerror('Use cancel for an unfinished project.') end
    if not args[3] then
        print(removal.summary(preview))
        print(('Run world-bridge %s %d --confirm to proceed.'):format(args[1],id))
        return
    end
    local removed,err=pcall(removal.run,env,id,p.state,p.supplied_blocks)
    if not removed then qerror(err) end
    print(completed and 'Bridge removed.' or 'Project canceled.')
elseif args[1]=='guide' and #args==3 then
    local controller_id,army_id=integer_arg(2),integer_arg(3)
    local success,result=pcall(steering.begin,env,controller_id,army_id)
    if not success then qerror(result) end
    set_enabled(true)
    print(('Guiding army %d through completed bridge routes.'):format(army_id))
elseif args[1]=='cancel-guidance' and #args==1 then
    local success,err=pcall(steering.cancel_all,env)
    if not success then qerror(err) end
    print('Bridge guidance canceled; unchanged mission targets were restored.')
elseif args[1]=='guidance-status' and #args==1 then
    local automatic=require('world-bridge.automatic-experiment')
    local data=automatic.status(env)
    if #data.missions==0 then print('No missions are waiting for bridge routing.') end
    for _,p in ipairs(data.missions) do
        print(('Mission %d at site %d: %s'):format(p.controller_id,p.site_id,
            p.failure and ('paused: '..p.failure) or 'waiting for squad assembly'))
    end
elseif args[1]=='retry-guidance' and #args==2 then
    local id=integer_arg(2)
    if not require('world-bridge.automatic-experiment').retry(env,id) then
        qerror('No paused bridge-routing mission with that controller ID.')
    end
    print('Routing will be checked again; the game remains paused until you resume it.')
elseif args[1]=='experiment-auto' and #args==2 and (args[2]=='on' or args[2]=='off') then
    local config=dfhack.persistent.getSiteData(runtime_key,{enabled=false})
    config.automatic=args[2]=='on'
    if config.automatic then config.enabled=true end
    dfhack.persistent.saveSiteData(runtime_key,config)
    runtime.configure_automatic(config.automatic)
    if config.enabled then runtime.start() end
    print('Experimental automatic raid routing '..(config.automatic and 'enabled.' or 'disabled.'))
    print('Copied saves only; unsupported missions and other travelers remain unverified.')
elseif args[1]=='trade-access' and #args==2 and (args[2]=='on' or args[2]=='off') then
    local trade=require('world-bridge.df-trade-access');local enabled=args[2]=='on'
    local config=dfhack.persistent.getSiteData(runtime_key,{enabled=false})
    local previous_effective=config.enabled==true and config.trade_access==true
    local changed,result=pcall(trade.refresh,env,enabled)
    if not changed then df.global.pause_state=true;qerror(result) end
    config.trade_access=enabled;if enabled then config.enabled=true end
    local saved,err=pcall(dfhack.persistent.saveSiteData,runtime_key,config)
    if not saved then
        local restored,why=pcall(trade.refresh,env,previous_effective)
        df.global.pause_state=true
        qerror('Could not save trade settings: '..tostring(err)..(restored and '' or ('; restoration failed: '..tostring(why))))
    end
    runtime.configure_trade(enabled)
    if config.enabled then runtime.start() end
    if enabled and not runtime.is_active() then qerror('The scheduler paused while enabling trade access; review the reported error.') end
    print(('Native trade links %s; %d civilization(s) extended.'):format(enabled and 'enabled' or 'disabled',result.owned))
    print('DF keeps its own trade, seasonal, and diplomatic rules. Existing scheduled visits remain.')
elseif args[1]=='trade-status' and #args==1 then
    local ownership=require('world-bridge.trade-access').load(env)
    print('Native trade links '..(runtime.is_trade_enabled() and runtime.is_active() and 'enabled.' or 'disabled.'))
    if ownership.site_id==env.site_id then for _,id in ipairs(ownership.owned) do
        local e=df.historical_entity.find(id)
        print(('Civilization %d: %s'):format(id,e and dfhack.translation.translateName(e.name) or 'missing'))
    end end
elseif (args[1]=='enable' or args[1]=='disable') and #args==1 then
    set_enabled(args[1]=='enable')
    print('World Bridge project scheduler '..(runtime.is_active() and 'enabled.' or 'disabled.'))
else
    qerror('Invalid arguments. Run world-bridge help.')
end
