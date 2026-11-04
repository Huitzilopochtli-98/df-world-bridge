local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local route = dofile(root..'/lua/world-bridge/route.lua')
local function grid(rows)
    return function(x,y)
        local c=rows[y+1]:sub(x+1,x+1)
        return ({L='land',W='water',X='blocked'})[c]
    end
end
local g=grid{'LWWL','XXXX'}
local p=assert(route.find(4,2,{x=0,y=0},{x=3,y=0},g,2))
assert(#p==4 and p[1].x==0 and p[4].x==3)
assert(not route.find(4,2,{x=0,y=0},{x=3,y=0},g,1))
local winding=grid{'LWX','XWW','XXL'}
p=assert(route.find(3,3,{x=0,y=0},{x=2,y=2},winding,3))
assert(#p==5 and p[2].x==1 and p[3].y==1)
assert(not route.find(3,3,{x=0,y=0},{x=2,y=2},winding,2))
assert(not route.find(3,3,{x=0,y=0},{x=1,y=0},winding,5))
assert(not route.find(3,3,{x=0,y=0},{x=0,y=0},winding,5))
assert(not route.find(3,3,{x=0,y=-1},{x=2,y=2},winding,5))
-- Land in the interior must not silently connect separate crossings.
local island=grid{'LWLWL'}
assert(not route.find(5,1,{x=0,y=0},{x=4,y=0},island,4))
-- Even adjacent shores require a water tile, and cannot form a bridge.
assert(not route.find(2,1,{x=0,y=0},{x=1,y=0},grid{'LL'},2))
print('route planning tests passed')
