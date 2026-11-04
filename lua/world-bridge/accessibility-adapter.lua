-- Experimental, reversible world-map accessibility overlay.
local access=require('world-bridge.accessibility')
local index=require('world-bridge.bridge-index')
local store=require('world-bridge.store')
local construction=require('world-bridge.construction')
local M={}
local active
local function address(ref)
    local _,ptr=df.sizeof(ref);return ptr
end
function M.restore()
    local old=active;active=nil
    if not old or not dfhack.isMapLoaded() then return 0 end
    local w=df.global.world.world_data
    if not w or address(w)~=old.world or w.path_start~=old.marker then return 0 end
    local count=0
    for _,p in ipairs(old.changes) do
        local entry=w.region_map[p.x]:_displace(p.y)
        if entry.path_map==p.value then entry.path_map=p.old;count=count+1 end
    end
    return count
end
function M.update(env)
    local screen=dfhack.gui.getDFViewscreen(true)
    if not screen or screen._type~=df.viewscreen_worldst then M.restore();return false end
    local w=env.world;local marker=w.path_start
    local world_addr,screen_addr=address(w),address(screen)
    if active and active.world==world_addr and active.screen==screen_addr and active.marker==marker then return true end
    M.restore()
    local site=df.world_site.find(env.site_id)
    if not site or marker<=0 or site.pos.x<0 or site.pos.y<0 or
       site.pos.x>=w.world_width or site.pos.y>=w.world_height or
       w.region_map[site.pos.x]:_displace(site.pos.y).path_map~=marker then
        return false,'native accessibility search is not ready'
    end
    local graph=index.build(store.load(env.persistent),function(p)return construction.verify(w,p) end)
    if graph.count==0 then return false end
    local seeds={}
    for x=0,w.world_width-1 do for y=0,w.world_height-1 do
        local v=w.region_map[x]:_displace(y).path_map
        if v>=marker then seeds[#seeds+1]={x=x,y=y,cost=v-marker} end
    end end
    local costs,native=access.extend(w.world_width,w.world_height,seeds,env.classify,graph.tile,graph.edge)
    local changes,extended={},{}
    for k,cost in pairs(costs) do
        if not native[k] then
            local n=k-1;local x=n%w.world_width;local y=math.floor(n/w.world_width)
            local entry=w.region_map[x]:_displace(y);local value=marker+cost
            if value>2147483647 then return false,'accessibility marker overflow' end
            changes[#changes+1]={x=x,y=y,old=entry.path_map,value=value}
            extended[k]=true
        end
    end
    active={world=world_addr,screen=screen_addr,marker=marker,changes=changes,
        extended=extended,width=w.world_width}
    local ok,err=pcall(function()
        for _,p in ipairs(changes) do w.region_map[p.x]:_displace(p.y).path_map=p.value end
    end)
    if not ok then M.restore();return false,tostring(err) end
    return true,#changes
end
function M.is_extended(x,y)
    return active~=nil and not not active.extended[y*active.width+x+1]
end
return M
