-- Opt-in native trade connectivity. This changes only the scoped NEARBY bit;
-- DF still chooses seasons, progress requirements, diplomats and caravans.
local connections=require('world-bridge.connections')
local ownership=require('world-bridge.trade-access')
local index=require('world-bridge.bridge-index')
local store=require('world-bridge.store')
local construction=require('world-bridge.construction')
local M={}
local context
local function address(ref)local _,p=df.sizeof(ref);return p end
local function peaceful(a,b)
    for _,r in ipairs(a.relations.diplomacy.state) do
        if r.group_id==b.id and r.relation~=df.diplomacy_state_type.Peace and
           r.relation~=df.diplomacy_state_type.NONE then return false end
    end
    return true
end
function M.eligible(e,homes)
    if not e or e.type~=df.historical_entity_type.Civilization or e.flags.dead or e.flags.secret or e.flags.isolated then return false end
    local f=e.entity_raw.flags
    -- Non-trading raider/thief cultures require separate traffic support.
    if f.BABYSNATCHER or f.ITEM_THIEF or f.SKULKING or f.LAYER_LINKED then return false end
    local season=false;for i=0,3 do season=season or e.entity_raw.active_season[i] end
    if not season then return false end
    for _,home in ipairs(homes) do
        if e.id==home.id or not peaceful(e,home) or not peaceful(home,e) then return false end
    end
    return true
end
function M.collect(env)
    local w=env.world;local home=assert(df.world_site.find(env.site_id),'fortress site is missing')
    local homes={assert(df.historical_entity.find(df.global.plotinfo.civ_id)),assert(df.historical_entity.find(df.global.plotinfo.group_id))}
    local graph=index.build(store.load(env.persistent),function(p)return construction.verify(w,p) end)
    local snapshots={}
    local resolve=connections.owner_resolver(function(id)
        if snapshots[id]~=nil then return snapshots[id] or nil end
        local e=df.historical_entity.find(id)
        if not e then snapshots[id]=false;return nil end
        local v={civilization=e.type==df.historical_entity_type.Civilization,parents={}}
        for _,link in ipairs(e.entity_links) do if link.type==df.entity_entity_link_type.PARENT then v.parents[#v.parents+1]=link.target end end
        snapshots[id]=v;return v
    end)
    local sites,anchors={},{}
    for _,s in ipairs(w.sites) do
        if not s.flag.RUINED then
            local civ=resolve(s.cur_owner_id)
            if civ and s.pos.x>=0 and s.pos.y>=0 and s.pos.x<w.world_width and s.pos.y<w.world_height then
                sites[#sites+1]={id=s.id,civ_id=civ,x=s.pos.x,y=s.pos.y,market=s.flag.HAS_MARKET}
            end
            if s.type==df.world_site_type.PlayerFortress then
                local x,y=math.floor(s.global_min_x/16),math.floor(s.global_min_y/16)
                if x>=0 and y>=0 and x<w.world_width and y<w.world_height then
                    local t=w.region_map[x]:_displace(y)
                    if t.flags.has_site then for _,p in ipairs(t.sites) do if p==s then anchors[#anchors+1]={x=x,y=y};break end end end
                end
            end
        end
    end
    local candidates,native=connections.find(w.world_width,w.world_height,{x=home.pos.x,y=home.pos.y},env.classify,graph,sites,anchors)
    local desired,eligible={},{}
    for _,c in ipairs(candidates) do
        if M.eligible(df.historical_entity.find(c.civ_id),homes) then desired[c.civ_id]=true;eligible[#eligible+1]=c end
    end
    return {desired=desired,candidates=eligible,native=native,projects=graph.count}
end
local function environment(env)
    return {persistent=env.persistent,site_id=env.site_id,
        get=function(id)local e=df.historical_entity.find(id);return e and e.flags.neighbor end,
        set=function(id,value)local e=assert(df.historical_entity.find(id),'civilization disappeared');e.flags.neighbor=value end,
        pause=function()df.global.pause_state=true end}
end
function M.refresh(env,enabled)
    local data=enabled and M.collect(env) or {desired={},candidates={}}
    local result=ownership.update(environment(env),data.desired)
    result.candidates=data.candidates;result.projects=data.projects
    context={env=env,world=address(env.world),site_id=env.site_id}
    return result
end
function M.stop()
    local old=context;context=nil
    if not old or not dfhack.isWorldLoaded() then return end
    local w=df.global.world.world_data
    if not w or address(w)~=old.world or df.global.plotinfo.site_id~=old.site_id then return end
    return ownership.update(environment(old.env),{})
end
return M
