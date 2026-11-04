-- Computes world routes. Land permits diagonal moves, while any edge touching
-- water must be part of a completed bridge's explicit cardinal route.
local M={}
local function point_ok(p,w,h)
    return type(p)=='table' and type(p.x)=='number' and p.x==math.floor(p.x)
        and type(p.y)=='number' and p.y==math.floor(p.y)
        and p.x>=0 and p.x<w and p.y>=0 and p.y<h
end
local function index(x,y,w) return y*w+x+1 end
function M.find(width,height,start,goal,classify,is_bridge_tile,is_bridge_edge)
    assert(type(width)=='number' and width>0 and width==math.floor(width)
        and type(height)=='number' and height>0 and height==math.floor(height)
        and type(classify)=='function' and type(is_bridge_tile)=='function'
        and type(is_bridge_edge)=='function'
        and point_ok(start,width,height) and point_ok(goal,width,height), 'invalid navigation arguments')
    -- DF structure access is expensive. Classify each world tile at most once
    -- per search, including impassable cells encountered repeatedly.
    local kinds={}
    local function kind_at(x,y)
        local k=index(x,y,width)
        local v=kinds[k]
        if v==nil then v=classify(x,y) or 'blocked';kinds[k]=v end
        return v
    end
    local function passable(x,y)
        local kind=kind_at(x,y)
        return kind=='land' or (kind=='water' and is_bridge_tile(x,y))
    end
    if not passable(start.x,start.y) or not passable(goal.x,goal.y) then return nil,'endpoint is impassable' end
    local queue,first={{x=start.x,y=start.y}},1
    local begin=index(start.x,start.y,width); local dest=index(goal.x,goal.y,width)
    local seen={[begin]=true};local parent={};local dirs={{1,0},{0,1},{-1,0},{0,-1},
        {1,1},{-1,1},{-1,-1},{1,-1}}
    while first<=#queue and not seen[dest] do
        local p=queue[first];first=first+1
        for _,d in ipairs(dirs) do
            local x,y=p.x+d[1],p.y+d[2]
            if x>=0 and x<width and y>=0 and y<height then
                local k=index(x,y,width)
                local water=kind_at(p.x,p.y)=='water' or kind_at(x,y)=='water'
                local allowed=not water or (math.abs(d[1])+math.abs(d[2])==1 and
                    is_bridge_edge(p.x,p.y,x,y))
                if not seen[k] and passable(x,y) and allowed then
                    seen[k]=true;parent[k]=index(p.x,p.y,width)
                    queue[#queue+1]={x=x,y=y}
                end
            end
        end
    end
    if not seen[dest] then return nil,'no route via completed bridges' end
    local reversed,k={},dest
    while k do
        local n=k-1;reversed[#reversed+1]={x=n%width,y=math.floor(n/width)}
        if k==begin then break end
        k=parent[k]
    end
    local path={}
    for i=#reversed,1,-1 do path[#path+1]=reversed[i] end
    return path
end
return M
