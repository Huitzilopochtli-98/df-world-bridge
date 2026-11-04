-- Read-only local deck preflight. The caller supplies a fixed deck elevation
-- and conservative probe. No terrain or construction record is changed here.
local geometry=require('world-bridge.local-geometry')
local M={}
local function integer(n)return type(n)=='number' and n==math.floor(n) end
function M.plan(path,map,deck_z,probe,spacing,options)
    assert(integer(deck_z) and deck_z>0 and integer(map.z_count) and deck_z+1<map.z_count,'invalid deck height')
    assert(type(probe)=='function','missing tile probe')
    spacing=spacing or 8;options=options or {}
    assert(integer(spacing) and spacing>0 and 48%spacing==0,'invalid support spacing')
    local offsets=options.support_offsets or {0}
    assert(type(offsets)=='table' and #offsets>0 and #offsets<=17,'invalid support search')
    for _,n in ipairs(offsets) do assert(integer(n) and math.abs(n)<=8,'invalid support offset') end
    local fp=geometry.footprint(path,map,3)
    local out={deck={},pillars={},anchors={},displaced_water=0,replaced_floors=0,preserved_sources=0}
    if #fp.centerline==0 then return out end
    local function inspect(x,y,z,role)
        if x<0 or y<0 or x>=map.width or y>=map.height then return nil,'support leaves local map' end
        local p=probe(x,y,z,role)
        if type(p)~='table' or p.occupied==nil or p.shape==nil or p.liquid==nil then
            return nil,('tile %d,%d,%d could not be inspected safely'):format(x,y,z)
        end
        if p.occupied then return nil,('tile %d,%d,%d has %s'):format(x,y,z,p.reason or 'an obstruction') end
        if p.liquid~='none' and p.liquid~='water' then return nil,('tile %d,%d,%d contains hazardous liquid'):format(x,y,z) end
        return p
    end
    local function deck_tile(x,y)
        for z=deck_z,deck_z+1 do
            local p,err=inspect(x,y,z,'deck');if not p then return nil,err end
            if p.shape~='open' or p.liquid~='none' then return nil,('deck or headroom obstructed at %d,%d,%d'):format(x,y,z) end
        end
        return {x=x,y=y,z=deck_z}
    end
    local deck_seen={}
    local function add_deck(t)local k=t.x..','..t.y;if not deck_seen[k] then deck_seen[k]=true;out.deck[#out.deck+1]=t end end
    for _,t in ipairs(fp.tiles) do local cell,err=deck_tile(t.x,t.y);if not cell then return nil,err end;add_deck(cell) end
    local supports,seen={},{}
    local function support(t)local k=t.x..','..t.y;if not seen[k] then seen[k]=true;supports[#supports+1]=t end end
    support(fp.centerline[1])
    for _,t in ipairs(fp.centerline) do if t.distance%spacing==0 then support(t) end end
    support(fp.centerline[#fp.centerline])
    local function try_column(t,offset)
        local x=t.x+(t.axis=='y' and offset or 0)
        local y=t.y+(t.axis=='x' and offset or 0)
        local connectors={}
        for step=0,math.abs(offset) do
            local d=offset<0 and -step or step
            local c,err=deck_tile(t.x+(t.axis=='y' and d or 0),t.y+(t.axis=='x' and d or 0))
            if not c then return nil,err end;connectors[#connectors+1]=c
        end
        local column={}
        for z=deck_z-1,0,-1 do
            local p,err=inspect(x,y,z,'support');if not p then return nil,err end
            if p.shape=='natural_floor' or p.shape=='natural_wall' then
                if p.shape=='natural_floor' then column[#column+1]={x=x,y=y,z=z,water=p.liquid=='water',source=p.source,replaces_floor=true} end
                return {column=column,anchor={x=x,y=y,z=z,shape=p.shape},connectors=connectors}
            end
            if p.shape~='open' then return nil,('support obstructed at %d,%d,%d'):format(x,y,z) end
            column[#column+1]={x=x,y=y,z=z,water=p.liquid=='water',source=p.source}
        end
        return nil,('no natural support below %d,%d'):format(x,y)
    end
    local pillar_seen,anchor_seen={},{}
    for _,t in ipairs(supports) do
        local chosen,err
        for _,offset in ipairs(offsets) do chosen,err=try_column(t,offset);if chosen then break end end
        if not chosen then return nil,err end
        local a=chosen.anchor;local ak=a.x..','..a.y
        if not anchor_seen[ak] then anchor_seen[ak]=true;out.anchors[#out.anchors+1]=a end
        for _,cell in ipairs(chosen.connectors) do add_deck(cell) end
        for _,p in ipairs(chosen.column) do
            local k=p.x..','..p.y..','..p.z
            if not pillar_seen[k] then
                pillar_seen[k]=true;out.pillars[#out.pillars+1]=p
                if p.water then out.displaced_water=out.displaced_water+1 end
                if p.source then out.preserved_sources=out.preserved_sources+1 end
                if p.replaces_floor then out.replaced_floors=out.replaced_floors+1 end
            end
        end
    end
    return out
end
return M
