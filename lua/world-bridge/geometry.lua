-- Construct a continuous mid-map path through a cardinal world-tile route.
local M={}
local function edge(tile,neighbor)
    local dx,dy=neighbor.x-tile.x,neighbor.y-tile.y
    assert(math.abs(dx)+math.abs(dy)==1, 'world route must be cardinal')
    if dx==-1 then return 0,8 end
    if dx==1 then return 15,8 end
    if dy==-1 then return 8,0 end
    return 8,15
end

function M.paths(path)
    assert(type(path)=='table' and #path>=2, 'route too short')
    local result={}
    for i,tile in ipairs(path) do
        local ax,ay=8,8
        if i>1 then ax,ay=edge(tile,path[i-1]) end
        local bx,by=8,8
        if i<#path then bx,by=edge(tile,path[i+1]) end
        local points={{x=ax,y=ay}}
        local function move(x,y)
            while ax~=x do ax=ax+(x>ax and 1 or -1);points[#points+1]={x=ax,y=ay} end
            while ay~=y do ay=ay+(y>ay and 1 or -1);points[#points+1]={x=ax,y=ay} end
        end
        move(8,8);move(bx,by)
        result[i]={x=tile.x,y=tile.y,points=points}
    end
    return result
end

return M
