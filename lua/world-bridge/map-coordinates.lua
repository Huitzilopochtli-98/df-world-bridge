-- Coordinate conversion for the verified native fortress world map.
-- Map tiles are 16 pixels; the text grid has independent dimensions.
local M={TILE_PIXELS=16}
local function valid(port)
    return port and port.dim_x>0 and port.dim_y>0
end
local function origin(port,center)
    return center.x-math.floor(port.dim_x/2),center.y-math.floor(port.dim_y/2)
end
function M.clamp_center(port,world,x,y)
    if not valid(port) then return x,y end
    local function clamp(value,size,tiles)
        if size<=tiles then return math.floor(size/2) end
        return math.max(math.floor(tiles/2),math.min(size-math.ceil(tiles/2),value))
    end
    return clamp(x,world.width,port.dim_x),clamp(y,world.height,port.dim_y)
end
function M.pick(port,center,world,px,py)
    if not valid(port) or px<port.top_left_corner_x or py<port.top_left_corner_y or
        px>=port.top_left_corner_x+port.dim_x*16 or py>=port.top_left_corner_y+port.dim_y*16 then return end
    local left,top=origin(port,center)
    local x=left+math.floor((px-port.top_left_corner_x)/16)
    local y=top+math.floor((py-port.top_left_corner_y)/16)
    if x<0 or y<0 or x>=world.width or y>=world.height then return end
    return x,y
end
function M.pixel(port,center,x,y)
    if not valid(port) then return end
    local left,top=origin(port,center)
    local dx,dy=x-left,y-top
    if dx<0 or dy<0 or dx>=port.dim_x or dy>=port.dim_y then return end
    return port.top_left_corner_x+(dx+.5)*16,port.top_left_corner_y+(dy+.5)*16
end
return M
