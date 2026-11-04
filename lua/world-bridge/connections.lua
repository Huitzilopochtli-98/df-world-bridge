-- Current territorial ownership and bridge-only world connections.
-- All inputs are snapshots; this module never changes game state.
local access=require('world-bridge.accessibility')
local M={}
local function integer(n)return type(n)=='number' and n>=0 and n==math.floor(n) and n<1e15 end
function M.owner_resolver(lookup)
    local cache,visiting={},{}
    local function resolve(id)
        if not integer(id) or visiting[id] then return nil end
        if cache[id]~=nil then return cache[id] or nil end
        local e=lookup(id)
        if not e then cache[id]=false;return nil end
        if e.civilization then cache[id]=id;return id end
        visiting[id]=true
        local found
        for _,parent in ipairs(e.parents or {}) do
            local owner=resolve(parent)
            if not owner or (found and found~=owner) then found=nil;break end
            found=owner
        end
        visiting[id]=nil;cache[id]=found or false
        return found
    end
    return resolve
end
function M.find(width,height,home,classify,graph,sites,anchors)
    local function key(x,y)return y*width+x+1 end
    local function point(p)
        return type(p)=='table' and integer(p.x) and integer(p.y) and p.x<width and p.y<height
    end
    assert(point(home),'invalid fortress position')
    local native_anchors={[key(home.x,home.y)]=true}
    for _,p in ipairs(anchors or {}) do assert(point(p),'invalid native anchor');native_anchors[key(p.x,p.y)]=true end
    local kinds={}
    local function kind(x,y)
        local k=key(x,y)
        if native_anchors[k] then return 'land' end
        if kinds[k]==nil then kinds[k]=classify(x,y) or 'blocked' end
        return kinds[k]
    end
    local seeds={{x=home.x,y=home.y,cost=0}}
    local base=access.extend(width,height,seeds,kind,function()return false end,function()return false end)
    local expanded=access.extend(width,height,seeds,kind,graph.tile,graph.edge)
    local native_civs,candidates={},{}
    for _,s in ipairs(sites) do
        assert(point(s) and integer(s.civ_id) and integer(s.id) and type(s.market)=='boolean','invalid territorial site')
        local k=key(s.x,s.y)
        if base[k] then native_civs[s.civ_id]=true
        elseif expanded[k] and s.market and not candidates[s.civ_id] then
            candidates[s.civ_id]={civ_id=s.civ_id,site_id=s.id,x=s.x,y=s.y}
        end
    end
    local result={}
    for id,c in pairs(candidates) do if not native_civs[id] then result[#result+1]=c end end
    table.sort(result,function(a,b)return a.civ_id<b.civ_id end)
    return result,native_civs
end
return M
