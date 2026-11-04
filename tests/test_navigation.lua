local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local nav=dofile(root..'/lua/world-bridge/navigation.lua')
local rows={'LLWLL','LLWLL','LLWLL'}
local function terrain(x,y) return rows[y+1]:sub(x+1,x+1)=='W' and 'water' or 'land' end
local no_bridge=function() return false end
local bridge=function(x,y) return x==2 and y==2 end
local function bridge_edge(ax,ay,bx,by)
    return ay==2 and by==2 and ((ax==1 and bx==2) or (ax==2 and bx==1)
        or (ax==2 and bx==3) or (ax==3 and bx==2))
end
assert(not nav.find(5,3,{x=0,y=0},{x=4,y=0},terrain,no_bridge,no_bridge))
local p=assert(nav.find(5,3,{x=0,y=0},{x=4,y=0},terrain,bridge,bridge_edge))
local water_count=0
for i,t in ipairs(p) do
    if terrain(t.x,t.y)=='water' then assert(bridge(t.x,t.y));water_count=water_count+1 end
    if i>1 then assert(math.abs(t.x-p[i-1].x)<=1 and math.abs(t.y-p[i-1].y)<=1) end
end
assert(water_count==1 and #p==7)
assert(not nav.find(5,3,{x=0,y=0},{x=4,y=0},terrain,bridge,no_bridge))
local same=assert(nav.find(5,3,{x=1,y=1},{x=1,y=1},terrain,bridge,bridge_edge))
assert(#same==1)
assert(not nav.find(5,3,{x=2,y=0},{x=4,y=0},terrain,bridge,bridge_edge))
local count={}
local function counted(x,y)
    local k=x..','..y;count[k]=(count[k] or 0)+1
    return terrain(x,y)
end
assert(nav.find(5,3,{x=0,y=0},{x=4,y=0},counted,bridge,bridge_edge))
for _,n in pairs(count) do assert(n==1) end
print('bridge-constrained navigation tests passed')
