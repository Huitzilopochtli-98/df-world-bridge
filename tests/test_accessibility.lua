local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local a=dofile(root..'/lua/world-bridge/accessibility.lua')
local rows={'LLWLL','LLWLL','LLWLL'}
local function terrain(x,y) return rows[y+1]:sub(x+1,x+1)=='W' and 'water' or 'land' end
local function tile(x,y) return x==2 and y==2 end
local function edge(ax,ay,bx,by) return ay==2 and by==2 and ((ax==2 and (bx==1 or bx==3)) or (bx==2 and (ax==1 or ax==3))) end
local costs,native=a.extend(5,3,{{x=0,y=0,cost=0},{x=1,y=0,cost=4}},terrain,tile,edge)
assert(native[1] and native[2] and not native[5])
assert(costs[5]~=nil and costs[2]==1) -- cheaper path improves the second seed
assert(costs[3]==nil and costs[8]==nil and costs[13]~=nil)
local blocked=a.extend(5,3,{{x=0,y=0,cost=0}},terrain,function()return false end,function()return false end)
assert(blocked[5]==nil)
assert(not pcall(a.extend,5,3,{{x=-1,y=0,cost=0}},terrain,tile,edge))
print('accessibility extension tests passed')
