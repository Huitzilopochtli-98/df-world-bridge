local root=os.getenv('WORLD_BRIDGE_TEST_ROOT') or 'work/world-bridge-mod'
local guard=dofile(root..'/lua/world-bridge/mission-guard.lua')
local screen={view_mode=8,focus_site={pos={x=5,y=6}},new_mission={0,0,1,0}}
local function extended(x,y)return x==5 and y==6 end
assert(guard.filter(screen,extended,1,0,7,8)==2)
assert(screen.new_mission[1]==0 and screen.new_mission[2]==7 and screen.new_mission[3]==1 and screen.new_mission[4]==7)
screen.focus_site.pos.x=9;screen.new_mission[2]=0
assert(guard.filter(screen,extended,1,0,7,8)==0 and screen.new_mission[2]==0)
screen.focus_site.pos.x=5;screen.new_mission={0,0,1,0}
assert(guard.filter(screen,extended,nil,0,7,8)==3)
assert(screen.new_mission[1]==7 and screen.new_mission[2]==7 and screen.new_mission[4]==7)
print('mission guard tests passed')
