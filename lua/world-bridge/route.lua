-- Route planning for world-map bridge projects. No DF globals are used here.
-- Each interior tile must be water; endpoints must be suitable shores.
local M = {}

local function valid_int(n)
    return type(n) == 'number' and n == math.floor(n) and n >= 0
end

local function key(x, y, width)
    return y * width + x + 1
end

-- classify(x,y) returns 'land', 'water', or 'blocked'. Land and blocked
-- are never traversed as interior tiles. The caller determines the actual
-- terrain semantics and may perform further reachability checks.
function M.find(width, height, start, finish, classify, max_water)
    if not valid_int(width) or width == 0 or not valid_int(height) or height == 0
        or type(start) ~= 'table' or type(finish) ~= 'table'
        or type(classify) ~= 'function' or not valid_int(max_water)
        or not valid_int(start.x) or not valid_int(start.y)
        or not valid_int(finish.x) or not valid_int(finish.y)
        or start.x >= width or finish.x >= width
        or start.y >= height or finish.y >= height then
        return nil, 'invalid route arguments'
    end
    if start.x == finish.x and start.y == finish.y then
        return nil, 'choose two different shores'
    end
    if classify(start.x, start.y) ~= 'land' or classify(finish.x, finish.y) ~= 'land' then
        return nil, 'both endpoints must be suitable land'
    end
    if max_water == 0 then return nil, 'bridge length limit is zero' end

    local q, first = {{x=start.x,y=start.y,n=0}}, 1
    local seen, parent = {}, {}
    local start_key, end_key = key(start.x,start.y,width), key(finish.x,finish.y,width)
    seen[start_key] = true
    local dirs = {{1,0},{0,1},{-1,0},{0,-1}}
    while first <= #q do
        local p = q[first]; first = first + 1
        for _,d in ipairs(dirs) do
            local x,y = p.x+d[1], p.y+d[2]
            if x>=0 and x<width and y>=0 and y<height then
                local k=key(x,y,width)
                if not seen[k] then
                    if k==end_key and p.n>0 then
                        parent[k]=key(p.x,p.y,width)
                        local result={{x=x,y=y}}
                        while k~=start_key do
                            k=parent[k]
                            local n=k-1
                            result[#result+1]={x=n%width,y=math.floor(n/width)}
                        end
                        local ordered={}
                        for i=#result,1,-1 do ordered[#ordered+1]=result[i] end
                        return ordered
                    elseif p.n < max_water and classify(x,y)=='water' then
                        seen[k]=true; parent[k]=key(p.x,p.y,width)
                        q[#q+1]={x=x,y=y,n=p.n+1}
                    end
                end
            end
        end
    end
    return nil, 'no water crossing within the length limit'
end

return M
