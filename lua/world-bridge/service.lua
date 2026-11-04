-- Orchestrates projects. The environment adapter supplies DF state and time;
-- no UI hooks or background scheduling are installed by this module.
local route=require('world-bridge.route')
local project=require('world-bridge.project')
local store=require('world-bridge.store')
local delivery=require('world-bridge.delivery')
local M={BLOCKS_PER_WATER_TILE=100,TICKS_PER_WATER_TILE=16800,MAX_WATER_TILES=64}

function M.plan(env,a,b)
    local path,err=route.find(env.world.world_width,env.world.world_height,a,b,env.classify,M.MAX_WATER_TILES)
    if not path then return nil,err end
    local data=store.load(env.persistent)
    local used={}
    for _,entry in ipairs(data.projects) do
        for _,tile in ipairs(entry.project.path) do used[tile.x..','..tile.y]=true end
    end
    for _,tile in ipairs(path) do
        if used[tile.x..','..tile.y] then return nil,'route overlaps another project' end
    end
    local p=project.create(data.next_id,path,M.BLOCKS_PER_WATER_TILE,M.TICKS_PER_WATER_TILE)
    if env.validate_plan then
        local ok,why=env.validate_plan(p)
        if not ok then return nil,why end
    end
    return p
end

function M.create(env,a,b)
    local p,err=M.plan(env,a,b);if not p then return nil,err end
    local data=store.load(env.persistent)
    assert(p.id==data.next_id,'project registry changed')
    data.next_id=data.next_id+1
    data.projects[#data.projects+1]={owner_site_id=env.site_id,project=p}
    store.save(env.persistent,data)
    return p
end

function M.deliver(env,id,limit)
    return delivery.deliver(env.delivery,id,limit,env.now())
end

-- Process one owned project. A failed construction is left ready so it can
-- be diagnosed/retried; completed projects are never applied a second time.
function M.advance(env,id)
    local data=store.load(env.persistent);local p
    for _,entry in ipairs(data.projects) do
        if entry.project.id==id then
            assert(entry.owner_site_id==env.site_id,'project belongs to another fortress')
            p=entry.project;break
        end
    end
    assert(p,'project not found')
    if p.state=='building' then
        project.advance(p,env.now())
        store.save(env.persistent,data)
    end
    if p.state=='ready' then
        local ok,result=pcall(env.construction.apply,env.world,p,function(ids)
            project.mark_complete(p,ids)
            local saved,err=pcall(store.save,env.persistent,data)
            if not saved then p.state='ready';p.construction=nil;error(err) end
        end)
        if not ok then return nil,tostring(result) end
    end
    return p
end
return M
