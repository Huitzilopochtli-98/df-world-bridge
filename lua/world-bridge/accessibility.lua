-- Extend native world-map accessibility over completed bridge edges.
-- Inputs are an immutable snapshot of one native search; this module does not
-- read or write DF state. The adapter must handle search generations and must
-- restore temporary changes when the world-map view closes.
local M={}
local function idx(x,y,w) return y*w+x+1 end
local function push(h,node)
    local i=#h+1;h[i]=node
    while i>1 do local p=math.floor(i/2);if h[p].cost<=node.cost then break end;h[i]=h[p];i=p end
    h[i]=node
end
local function pop(h)
    local first=h[1];local last=h[#h];h[#h]=nil
    if #h>0 then
        local i=1
        while i*2<=#h do
            local child=i*2
            if child+1<=#h and h[child+1].cost<h[child].cost then child=child+1 end
            if h[child].cost>=last.cost then break end
            h[i]=h[child];i=child
        end
        h[i]=last
    end
    return first
end
function M.extend(width,height,seeds,classify,bridge_tile,bridge_edge)
    assert(type(width)=='number' and width>0 and width==math.floor(width)
        and type(height)=='number' and height>0 and height==math.floor(height)
        and type(seeds)=='table' and type(classify)=='function'
        and type(bridge_tile)=='function' and type(bridge_edge)=='function', 'invalid accessibility inputs')
    local costs,native,heap,kinds={},{},{},{}
    local function kind(x,y)
        local k=idx(x,y,width);if kinds[k]==nil then kinds[k]=classify(x,y) or 'blocked' end
        return kinds[k]
    end
    for _,s in ipairs(seeds) do
        assert(type(s.x)=='number' and s.x==math.floor(s.x) and s.x>=0 and s.x<width
            and type(s.y)=='number' and s.y==math.floor(s.y) and s.y>=0 and s.y<height
            and type(s.cost)=='number' and s.cost>=0 and s.cost==math.floor(s.cost), 'invalid seed')
        local k=idx(s.x,s.y,width);native[k]=true
        if costs[k]==nil or s.cost<costs[k] then costs[k]=s.cost;push(heap,{x=s.x,y=s.y,cost=s.cost}) end
    end
    local dirs={{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}
    while #heap>0 do
        local p=pop(heap);local k=idx(p.x,p.y,width)
        if costs[k]==p.cost then
            for _,d in ipairs(dirs) do
                local x,y=p.x+d[1],p.y+d[2]
                if x>=0 and x<width and y>=0 and y<height then
                    local nk=idx(x,y,width);local dest=kind(x,y);local from=kind(p.x,p.y)
                    local wet=from=='water' or dest=='water'
                    local pass=dest=='land' or native[nk] or (dest=='water' and bridge_tile(x,y))
                    local edge=not wet or (math.abs(d[1])+math.abs(d[2])==1 and bridge_edge(p.x,p.y,x,y))
                    local next_cost=p.cost+1
                    if pass and edge and (costs[nk]==nil or next_cost<costs[nk]) then
                        costs[nk]=next_cost;push(heap,{x=x,y=y,cost=next_cost})
                    end
                end
            end
        end
    end
    return costs,native
end
return M
