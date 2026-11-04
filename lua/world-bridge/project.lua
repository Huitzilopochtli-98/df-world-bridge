-- Pure project accounting. The DF adapter must persist state and only call
-- fund() after it has actually removed the same number of eligible blocks.
local M={}

local function integer(n)
    return type(n)=='number' and n==math.floor(n) and n>=0 and n<1e15
end

-- Validate a reloaded state before acting on it. This rejects inconsistent
-- ledgers rather than charging materials or placing malformed constructions.
function M.validate(p)
    if type(p)~='table' or p.version~=1 or not integer(p.id) or
       type(p.path)~='table' or #p.path<3 or
       not integer(p.required_blocks) or p.required_blocks==0 or
       not integer(p.supplied_blocks) or p.supplied_blocks>p.required_blocks or
       not integer(p.duration_ticks) or p.duration_ticks==0 then
        return false,'invalid project data'
    end
    for k in pairs(p.path) do
        if not integer(k) or k<1 or k>#p.path then return false,'invalid route list' end
    end
    local seen,count={},0
    for i,tile in ipairs(p.path) do
        count=count+1
        if type(tile)~='table' or not integer(tile.x) or not integer(tile.y) then
            return false,'invalid route coordinate'
        end
        local k=tile.x..','..tile.y
        if seen[k] then return false,'route revisits a tile' end
        seen[k]=true
        if i>1 then
            local prev=p.path[i-1]
            if math.abs(prev.x-tile.x)+math.abs(prev.y-tile.y)~=1 then
                return false,'noncontiguous route'
            end
        end
    end
    if count~=#p.path then return false,'incomplete route list' end
    if p.state=='funding' then
        if p.supplied_blocks>=p.required_blocks or p.started_tick~=nil then return false,'invalid funding state' end
    elseif p.state=='building' or p.state=='ready' or p.state=='complete' then
        if p.supplied_blocks~=p.required_blocks or not integer(p.started_tick) then return false,'invalid funded state' end
    else
        return false,'unknown project state'
    end
    if p.state=='complete' then
        local c=p.construction
        if type(c)~='table' or not integer(c.road_id) or type(c.bridge_ids)~='table'
           or #c.bridge_ids~=#p.path-2 then return false,'invalid construction references' end
        for k in pairs(c.bridge_ids) do
            if not integer(k) or k<1 or k>#c.bridge_ids then return false,'invalid bridge list' end
        end
        local ids={[c.road_id]=true}
        local count=0
        for _,id in ipairs(c.bridge_ids) do
            count=count+1
            if not integer(id) or ids[id] then return false,'invalid bridge ID' end
            ids[id]=true
        end
        if count~=#c.bridge_ids then return false,'incomplete bridge list' end
    elseif p.construction~=nil then
        return false,'unfinished project has construction references'
    end
    return true
end

function M.create(id, path, blocks_per_tile, ticks_per_tile)
    assert(integer(id) and type(path)=='table' and #path>=3, 'invalid project')
    assert(integer(blocks_per_tile) and blocks_per_tile>0 and
        integer(ticks_per_tile) and ticks_per_tile>0, 'invalid project cost')
    local copy,seen={},{}
    for i,p in ipairs(path) do
        assert(type(p)=='table' and integer(p.x) and integer(p.y), 'invalid route coordinate')
        local k=p.x..','..p.y
        assert(not seen[k], 'route must not revisit a tile')
        seen[k]=true
        if i>1 then
            local prev=path[i-1]
            assert(math.abs(prev.x-p.x)+math.abs(prev.y-p.y)==1, 'route must be contiguous')
        end
        copy[i]={x=p.x,y=p.y}
    end
    local count=#copy-2
    assert(count*blocks_per_tile<1e15 and count*ticks_per_tile<1e15, 'project cost too large')
    return {version=1,id=id,path=copy,required_blocks=count*blocks_per_tile,
        supplied_blocks=0,duration_ticks=count*ticks_per_tile,state='funding'}
end

-- Adapter reports actual material units taken, not hypothetical availability.
-- Returns the number accepted. The adapter must not take more than missing().
function M.missing(p)
    assert(M.validate(p))
    return p.required_blocks-p.supplied_blocks
end

function M.fund(p, taken, now)
    assert(M.validate(p))
    assert(p.state=='funding', 'project is not accepting materials')
    assert(integer(taken) and integer(now) and taken<=M.missing(p), 'invalid delivery')
    p.supplied_blocks=p.supplied_blocks+taken
    if p.supplied_blocks==p.required_blocks then p.state='building';p.started_tick=now end
    return taken
end

function M.advance(p, now)
    assert(M.validate(p))
    assert(integer(now), 'invalid time')
    if p.state=='building' then
        assert(integer(p.started_tick) and now>=p.started_tick, 'time moved backwards')
        if now-p.started_tick>=p.duration_ticks then p.state='ready' end
    end
    return p.state
end

-- Call only after the bridge was applied successfully in the current world.
-- The adapter must ensure world changes and project state are saved together.
function M.mark_complete(p,construction)
    assert(M.validate(p))
    assert(p.state=='ready', 'project is not ready')
    p.state='complete';p.construction=construction
    local ok,err=M.validate(p)
    if not ok then p.state='ready';p.construction=nil;error(err) end
end

return M
