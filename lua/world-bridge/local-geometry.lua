-- Map a world-route's mid-map path into local-map tiles.
-- Pure geometry only: this module does not alter terrain or place buildings.
local world_geometry=require('world-bridge.geometry')
local M={}
local function integer(v) return type(v)=='number' and v==math.floor(v) end
function M.footprint(path,map,width)
    assert(type(map)=='table' and integer(map.region_x) and integer(map.region_y)
        and integer(map.width) and integer(map.height) and map.width>0 and map.height>0,
        'invalid local map bounds')
    width=width or 3
    assert(integer(width) and width>0 and width%2==1 and width<=15,'width must be an odd integer from 1 to 15')
    local mid=world_geometry.paths(path)
    local points={}
    for _,tile in ipairs(mid) do for _,p in ipairs(tile.points) do
        points[#points+1]={x=(tile.x*16+p.x-map.region_x)*48+24,
                           y=(tile.y*16+p.y-map.region_y)*48+24}
    end end
    local cells,center,seen={}, {}, {}
    local function put(x,y)
        if x<0 or y<0 or x>=map.width or y>=map.height then return end
        local key=x..','..y
        if not seen[key] then seen[key]=true;cells[#cells+1]={x=x,y=y} end
    end
    local center_seen={}
    local function sample(x,y,horizontal,distance)
        local k=x..','..y
        if x>=0 and y>=0 and x<map.width and y<map.height and not center_seen[k] then
            center_seen[k]=true;center[#center+1]={x=x,y=y,distance=distance,axis=horizontal and 'x' or 'y'}
        end
        for d=-math.floor(width/2),math.floor(width/2) do
            if horizontal then put(x,y+d) else put(x+d,y) end
        end
    end
    local distance=0;local previous_horizontal
    for i=2,#points do
        local a,b=points[i-1],points[i]
        local dx,dy=b.x-a.x,b.y-a.y
        assert((dx==0)~=(dy==0),'non-cardinal or duplicate route step')
        local steps=math.abs(dx)+math.abs(dy)
        local horizontal=dy==0
        if previous_horizontal~=nil and previous_horizontal~=horizontal then
            -- Fill the outside of a turn as well as its two straight arms.
            -- Otherwise a three-wide L has a missing corner tile and loses
            -- the full three-by-three clearance required for a wagon turn.
            local radius=math.floor(width/2)
            for ox=-radius,radius do for oy=-radius,radius do put(a.x+ox,a.y+oy) end end
        end
        local sx=dx==0 and 0 or (dx>0 and 1 or -1)
        local sy=dy==0 and 0 or (dy>0 and 1 or -1)
        for k=0,steps do sample(a.x+sx*k,a.y+sy*k,dy==0,distance+k) end
        distance=distance+steps
        previous_horizontal=horizontal
    end
    return {centerline=center,tiles=cells}
end
return M
