-- A level deck must clear every water surface in its world route.
local M={}
function M.choose(path,surface)
    assert(type(path)=='table' and #path>=3 and type(surface)=='function','invalid elevation request')
    local highest
    for i=2,#path-1 do
        local p=path[i];local z=surface(p.x,p.y)
        assert(type(z)=='number' and z==math.floor(z) and z>=0 and z<1e6,'unknown water surface elevation')
        highest=highest and math.max(highest,z) or z
    end
    return assert(highest,'route has no water tiles')+1
end
return M
