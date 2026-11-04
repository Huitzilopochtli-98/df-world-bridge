-- Find one dry stair/ground approach to a planned deck. This is read-only and
-- refuses existing constructions, blocked tiles, water, and planned piers.
local geometry=require('world-bridge.local-geometry')
local M={}
local function key(x,y,z)return x..','..y..','..z end
function M.find(path,map,z,probe,planned,home_group)
    if not home_group or home_group==0 then return nil,'no reachable shore group' end
    local fp=geometry.footprint(path,map,3)
    local occupied={};for _,c in ipairs(planned.pillars) do occupied[key(c.x,c.y,c.z)]='pillar' end
    for _,c in ipairs(planned.deck) do occupied[key(c.x,c.y,c.z)]='deck' end
    local function get(x,y,tz)
        if x<0 or y<0 or x>=map.width or y>=map.height or tz<0 or tz>=map.z_count then return nil end
        local p=probe(x,y,tz,'approach')
        if not p or p.occupied or p.liquid~='none' then return nil end
        return p
    end
    for _,t in ipairs(fp.centerline) do for _,offset in ipairs({2,-2,3,-3,4,-4,5,-5,6,-6,7,-7,8,-8}) do
        local x=t.x+(t.axis=='y' and offset or 0);local y=t.y+(t.axis=='x' and offset or 0)
        local base
        for bz=z,math.max(0,z-8),-1 do
            local p=get(x,y,bz)
            if not p then break end
            if p.shape=='natural_floor' then if p.walk_group==home_group then base=bz end;break end
            if p.shape~='open' then break end
        end
        if base then
            local stairs,connectors={},{};local valid=true
            for tz=base,z do
                local p=get(x,y,tz);local existing=occupied[key(x,y,tz)]
                if not p or existing or (tz>base and p.shape~='open') then valid=false;break end
                if base<z then stairs[#stairs+1]={x=x,y=y,z=tz,kind=tz==base and 'stair_up' or (tz==z and 'stair_down' or 'stair_both')} end
            end
            local head=get(x,y,z+1);if not head or head.shape~='open' then valid=false end
            if valid then for step=1,math.abs(offset)-1 do
                local d=offset<0 and -step or step
                local cx=t.x+(t.axis=='y' and d or 0);local cy=t.y+(t.axis=='x' and d or 0)
                local p=get(cx,cy,z);local h=get(cx,cy,z+1);local existing=occupied[key(cx,cy,z)]
                if not p or p.shape~='open' or not h or h.shape~='open' or (existing and existing~='deck') then valid=false;break end
                if not existing then connectors[#connectors+1]={x=cx,y=cy,z=z} end
            end end
            if valid then return {stairs=stairs,deck=connectors,base={x=x,y=y,z=base}} end
        end
    end end
    return nil,'no unobstructed dry shore approach found'
end
return M
